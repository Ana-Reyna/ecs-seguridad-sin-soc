terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project = "ecs-security-sin-soc"
      Demo    = "true"
    }
  }
}

data "aws_caller_identity" "current" {}
