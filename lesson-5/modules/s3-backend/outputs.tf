# Вихідні змінні модуля s3-backend

output "s3_bucket_url" {
  description = "Regional URL of the S3 bucket for Terraform state"
  value       = "https://${aws_s3_bucket.terraform_state.bucket_regional_domain_name}"
}

output "dynamodb_table_name" {
  description = "DynamoDB table name for Terraform state locking"
  value       = aws_dynamodb_table.terraform_locks.name
}

