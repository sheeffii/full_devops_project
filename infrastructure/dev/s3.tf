/*resource "aws_s3_bucket" "bucket" {
  bucket = "dev4-logs-backups-${random_string.bucket_suffix.result}"  # Globally unique bucket name
  
  tags   = merge(var.tags, { 
    Name = "dev4-logs-backups"
    Purpose = "EC2 logs and backups" })
}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# Enable versioning for the S3 bucket
resource "aws_s3_bucket_versioning" "bucket_versioning" {
  bucket = aws_s3_bucket.bucket.id
  
  versioning_configuration {
    status = "Enabled"
  }
  
}
# Enable server-side encryption for the S3 bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "logs_encryption" {
  bucket = aws_s3_bucket.bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

 # Configure public access block for the S3 bucket
resource "aws_s3_bucket_public_access_block" "logs_pab" {
  bucket = aws_s3_bucket.bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

/* # Set bucket ACL explicitly 
resource "aws_s3_bucket_acl" "bucket_acl" {
  bucket = aws_s3_bucket.bucket.id
  acl    = "private"
}
*/

/*
# Separate S3 bucket for Terraform state backend
resource "aws_s3_bucket" "terraform_state_bucket" {
  bucket = "shefqet-terraform-lock-state-2025"  # Fixed bucket name for Terraform backend
  
  tags = merge(var.tags, {
    Name    = "Terraform state bucket"
    Purpose = "Terraform remote state"
  })
}

resource "aws_s3_bucket_versioning" "terraform_state_versioning" {
  bucket = aws_s3_bucket.bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}
*/ 