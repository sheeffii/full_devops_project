terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 6.18.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "= 3.7.2"
    }
    null = {
      source  = "hashicorp/null"
      version = "= 3.2.4"
    }
  }
}


provider "aws" {
  region = var.aws_region
}
