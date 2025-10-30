/*terraform {
  backend "s3" {
    bucket         = "shefqet-terraform-state-20251026"  # matches the fixed bucket created in s3.tf
    key            = "global/s3/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "shefqet-terraform-state-locks-20251026"       # DynamoDB locking table name
    use_lockfile   = true
    encrypt        = true
  }
}



terraform {
  backend "s3" {
    # Dynamic parts provided by Makefile: bucket, dynamodb_table
    # Static parts below:
    key            = "dev/terraform.tfstate"  # Path to state file in S3 (matches Makefile)
    region         = "eu-central-1"           # Matches your REGION var and bootstrap
    encrypt        = true                     # Enable server-side encryption
    # Optional: Add if needed
    # bucket and dynamodb_table will be provided via -backend-config
    #use_lockfile   = true  # Default is true; enables .terraform.lock.hcl for providers
    # dynamodb_table = null  # Let -backend-config override
  }
}

*/
terraform {
  backend "s3" {
    bucket         = "team7-dev-tf-state"  # Static name (matches bootstrap)
    key            = "dev/terraform.tfstate"
    region         = "eu-central-1"
    encrypt        = true
    dynamodb_table = "team7-dev-tf-lock"   # Static name (matches bootstrap)
  }
}