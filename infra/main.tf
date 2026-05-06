provider "aws" {}

data "aws_region" "current" {}

terraform {
  backend "local" {}
  
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}