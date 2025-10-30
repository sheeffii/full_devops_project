output "terraform_state_bucket" {
  value = aws_s3_bucket.tf_state.bucket
}

output "terraform_lock_table" {
  value = aws_dynamodb_table.tf_lock_table.name
}