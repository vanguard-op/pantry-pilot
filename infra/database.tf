data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# ===================================
# Security Group: Database
# ===================================
resource "aws_security_group" "db" {
  name        = "pantry-pilot-db-sg"
  description = "Postgres access for PantryPilot"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "Postgres from Lambda"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id]
  }

  ingress {
    description = "Postgres public access"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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
# Aurora PostgreSQL Cluster (Module)
# ===================================
module "rds_aurora" {
  source  = "terraform-aws-modules/rds-aurora/aws"
  version = "~> 9.0"

  name              = "pantry-pilot-aurora-pg"
  engine            = "aurora-postgresql"
  engine_version    = var.db_engine_version
  database_name     = var.db_name
  master_username   = var.db_master_username
  manage_master_user_password = true

  create_db_subnet_group = true
  db_subnet_group_name   = "pantry-pilot-db-subnet-group"
  publicly_accessible    = var.db_publicly_accessible
  vpc_id                 = data.aws_vpc.default.id
  subnets                = data.aws_subnets.default.ids
  vpc_security_group_ids = [aws_security_group.db.id]
  storage_encrypted      = true
  skip_final_snapshot    = var.db_skip_final_snapshot
  backup_retention_period = var.db_backup_retention_period

  serverlessv2_scaling_configuration = {
    min_capacity             = var.db_serverlessv2_scaling_min_capacity
    max_capacity             = var.db_serverlessv2_scaling_max_capacity
    seconds_until_auto_pause = var.db_serverlessv2_auto_pause_seconds
  }

  instances = {
    one = {
      instance_class       = var.db_instance_class
      publicly_accessible  = var.db_publicly_accessible
    }
  }

  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}
