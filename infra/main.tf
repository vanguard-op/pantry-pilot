provider "aws" {}

data "aws_region" "current" {}

terraform {
  backend "s3" {
    bucket       = "vanguard-op-terraform-state"
    key          = "pantry-pilot/terraform.tfstate"
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.43"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}