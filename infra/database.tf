data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_db_subnet_group" "pantry" {
  name       = "pantry-pilot-db-subnet-group"
  subnet_ids = data.aws_subnets.default.ids
}

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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

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
}

resource "aws_rds_cluster" "pantry" {
  cluster_identifier = "pantry-pilot-aurora-pg"
  engine             = "aurora-postgresql"
  engine_version     = "16.13"

  database_name   = "pantry_pilot"
  master_username = "pantry_user"
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.pantry.name
  vpc_security_group_ids = [aws_security_group.db.id]
  storage_encrypted      = true
  skip_final_snapshot    = true

  serverlessv2_scaling_configuration {
    min_capacity             = 0
    max_capacity             = 1
    seconds_until_auto_pause = 300
  }
}

resource "aws_rds_cluster_instance" "pantry" {
  identifier         = "pantry-pilot-aurora-pg-1"
  cluster_identifier = aws_rds_cluster.pantry.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.pantry.engine
  engine_version     = aws_rds_cluster.pantry.engine_version
}
