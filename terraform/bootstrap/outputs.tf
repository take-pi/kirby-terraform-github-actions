output "bucket_name" {
  description = "S3 bucket name for Terraform state"
  value       = aws_s3_bucket.tfstate.bucket
}

output "dynamodb_table_name" {
  description = "DynamoDB table name for Terraform state lock"
  value       = aws_dynamodb_table.tflock.name
}
