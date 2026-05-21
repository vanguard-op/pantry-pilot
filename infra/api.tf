# ===================================
# Security Groups
# ===================================
resource "aws_security_group" "lambda" {
  name        = "pantry-pilot-lambda-sg"
  description = "Lambda egress for PantryPilot backend"
  vpc_id      = data.aws_vpc.default.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}

# ===================================
# Docker Build: Backend
# ===================================
data "aws_ecr_authorization_token" "token" {}

provider "docker" {
  registry_auth {
    username = data.aws_ecr_authorization_token.token.user_name
    password = data.aws_ecr_authorization_token.token.password
    address  = data.aws_ecr_authorization_token.token.proxy_endpoint
  }
}

module "docker_build" {
  source  = "terraform-aws-modules/lambda/aws//modules/docker-build"
  version = "7.2.0"

  create_ecr_repo = true
  ecr_repo        = "pantry_pilot_backend_repository"
  ecr_repo_lifecycle_policy = jsonencode({
    "rules" : [
      {
        "rulePriority" : 1,
        "description" : "Keep only the last 2 images",
        "selection" : {
          "tagStatus" : "any",
          "countType" : "imageCountMoreThan",
          "countNumber" : 2
        },
        "action" : {
          "type" : "expire"
        }
      }
    ]
  })
  source_path      = local.source_path
  docker_file_path = local.docker_file
  platform         = "linux/amd64"
  use_image_tag    = false

  triggers = {
    code_hash = local.code_hash
  }
}

# ===================================
# Lambda: API Handler
# ===================================
module "api_handler" {
  source = "terraform-aws-modules/lambda/aws"

  function_name = "pantry_pilot_api_handler"
  description   = "Lambda function for handling API requests in the Pantry Pilot application."
  timeout       = 300
  memory_size   = 2048

  create_package = false
  package_type   = "Image"
  image_uri      = module.docker_build.image_uri

  # vpc_subnet_ids         = data.aws_subnets.default.ids
  # vpc_security_group_ids = [aws_security_group.lambda.id]

  environment_variables = {
    APP_ENV                         = var.environment
    ALLOWED_ORIGINS                 = "*"
    DATABASE_NAME                   = var.db_name
    DATABASE_USER                   = var.db_master_username
    DATABASE_HOST                   = module.rds_aurora.cluster_endpoint
    DATABASE_PORT                   = tostring(module.rds_aurora.cluster_port)
    DATABASE_SECRET_ARN             = module.rds_aurora.cluster_master_user_secret[0].secret_arn
    COGNITO_REGION                  = aws_cognito_user_pool.this.region
    COGNITO_USER_POOL_ID            = aws_cognito_user_pool.this.id
    COGNITO_CLIENT_ID               = aws_cognito_user_pool_client.this.id
    COGNITO_HOSTED_UI_DOMAIN_PREFIX = aws_cognito_user_pool_domain.this.domain
    # OpenCode AI — non-sensitive config passed directly; sensitive key
    # is stored in Secrets Manager and resolved via OPENCODE_SECRET_ARN.
    OPENCODE_BASE_URL            = var.opencode_base_url
    OPENCODE_MODEL               = var.opencode_model
    OPENCODE_REASONING_EFFORT    = var.opencode_reasoning_effort
    OPENCODE_SECRET_ARN          = aws_secretsmanager_secret.general_config.arn
  }

  create_role = true
  role_name   = "pantry_pilot_api_handler_role"

  attach_cloudwatch_logs_policy     = true
  cloudwatch_logs_retention_in_days = 1

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}

# ===================================
# API Gateway (HTTP/REST): Pantry Pilot API
# ===================================
module "api_gateway" {
  source = "terraform-aws-modules/apigateway-v2/aws"

  name               = "pantry_pilot_rest_api"
  description        = "REST API Gateway for Pantry Pilot application"
  protocol_type      = "HTTP"
  create_domain_name = false

  cors_configuration = {
    allow_headers = ["content-type", "x-amz-date", "authorization",
    "x-api-key", "x-amz-security-token", "x-amz-user-agent"]
    allow_methods = ["*"]
    allow_origins = ["*"]
  }

  # Access logs
  stage_access_log_settings = {
    create_log_group            = true
    log_group_retention_in_days = 1
  }

  # Routes & Integration(s)
  routes = {
    "$default" = {
      integration = {
        uri = module.api_handler.lambda_function_arn
      }
    }
  }

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}
# Grant API Gateway permission to invoke Lambda
resource "aws_lambda_permission" "apigw_invoke" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = module.api_handler.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${module.api_gateway.api_execution_arn}/*"
}

module "db_migrator" {
  source = "terraform-aws-modules/lambda/aws"

  function_name = "pantry_pilot_db_migrator"
  description   = "Runs Alembic migrations for Pantry Pilot backend deployment lifecycle."
  timeout       = 300

  create_package       = false
  package_type         = "Image"
  image_uri            = module.docker_build.image_uri
  image_config_command = ["app.migration_handler.handler"]

  # vpc_subnet_ids         = data.aws_subnets.default.ids
  # vpc_security_group_ids = [aws_security_group.lambda.id]

  environment_variables = {
    APP_ENV             = var.environment
    DATABASE_NAME       = var.db_name
    DATABASE_USER       = var.db_master_username
    DATABASE_HOST       = module.rds_aurora.cluster_endpoint
    DATABASE_PORT       = tostring(module.rds_aurora.cluster_port)
    DATABASE_SECRET_ARN = module.rds_aurora.cluster_master_user_secret[0].secret_arn
    OPENCODE_SECRET_ARN = aws_secretsmanager_secret.general_config.arn
  }

  create_role = true
  role_name   = "pantry_pilot_db_migrator_role"

  attach_cloudwatch_logs_policy     = true
  cloudwatch_logs_retention_in_days = 1

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "null_resource" "run_db_migrations" {
  triggers = {
    code_hash     = local.code_hash
    db_endpoint   = module.rds_aurora.cluster_endpoint
    db_secret_arn = module.rds_aurora.cluster_master_user_secret[0].secret_arn
  }

  provisioner "local-exec" {
    command = "aws lambda invoke --function-name ${module.db_migrator.lambda_function_name} --cli-connect-timeout 60 --cli-read-timeout 900 --payload '{}' --cli-binary-format raw-in-base64-out migrate-response.json"
  }

  depends_on = [
    module.api_handler,
    module.db_migrator,
    module.rds_aurora,
  ]
}

# General-purpose secrets store for sensitive config (OpenCode API key, etc.)
# The secret value is a JSON object.  Values must be set manually or via
# CI/CD after `terraform apply` (e.g. ``{"opencode_api_key":"sk-..."}``).
resource "aws_secretsmanager_secret" "general_config" {
  name        = "pantry-pilot-general-config-${var.environment}"
  description = "General-purpose sensitive configuration for PantryPilot"
}

resource "aws_secretsmanager_secret_version" "general_config" {
  secret_id     = aws_secretsmanager_secret.general_config.id
  secret_string = jsonencode({
    opencode_api_key = ""
  })
}

resource "aws_iam_role_policy" "api_handler_secrets_policy" {
  name = "pantry_pilot_api_handler_secrets_policy"
  role = module.api_handler.lambda_role_name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ],
        Resource = [
          module.rds_aurora.cluster_master_user_secret[0].secret_arn,
          aws_secretsmanager_secret.general_config.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "db_migrator_secrets_policy" {
  name = "pantry_pilot_db_migrator_secrets_policy"
  role = module.db_migrator.lambda_role_name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ],
        Resource = [
          module.rds_aurora.cluster_master_user_secret[0].secret_arn,
          aws_secretsmanager_secret.general_config.arn
        ]
      }
    ]
  })
}

# Allow Lambda to create/manage ENIs when placed inside a VPC
resource "aws_iam_role_policy_attachment" "api_handler_vpc_access" {
  role       = module.api_handler.lambda_role_name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "db_migrator_vpc_access" {
  role       = module.db_migrator.lambda_role_name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}
