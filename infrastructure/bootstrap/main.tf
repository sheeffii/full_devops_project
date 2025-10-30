terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 6.18.0"
    }
  }

  backend "local" {}  # Force local for bootstrap
}

provider "aws" {
  region = "eu-central-1"
}

# Static names (no random suffix)
locals {
  project     = "team7"
  environment = "dev"
  bucket_name = "team7-dev-tf-state"  # Static, unique name
  table_name  = "team7-dev-tf-lock"   # Static, unique name
}

# S3 bucket for Terraform state
resource "aws_s3_bucket" "tf_state" {
  bucket = local.bucket_name
  force_destroy = true

  tags = {
    Name        = "Terraform State Bucket"
    Purpose     = "Stores Terraform remote state"
    Owner       = "team7"
    Environment = local.environment
    ManagedBy   = "Terraform"
  }
}

# Enable versioning
resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "public_block" {
  bucket = aws_s3_bucket.tf_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB table for state locking
resource "aws_dynamodb_table" "tf_lock_table" {
  name         = local.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name    = "Terraform State Lock Table"
    Purpose = "Terraform state locking"
    Owner   = "Shefqet"
  }
}