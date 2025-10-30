/* terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 6.18.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "= 3.7.2"
    }
  }

  backend "local" {}  # Force local for bootstrap
}

provider "aws" {
  region = "eu-central-1"
}

# Generate a short random suffix to avoid naming collisions when creating S3/DynamoDB resources
resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  project     = "team7"
  environment = "dev"
  suffix      = random_id.suffix.hex
  # sanitize project name: lowercase, replace invalid chars with hyphen, limit length
  #sanitized_project = replace(lower(local.project), "/[^a-z0-9-]/", "-")
  #short_project     = substr(local.sanitized_project, 0, 20)
  bucket_name = "tf-state-${local.project}-${local.environment}-${local.suffix}"
  table_name  = "tf-lock-${local.project}-${local.environment}-${local.suffix}"
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

*/