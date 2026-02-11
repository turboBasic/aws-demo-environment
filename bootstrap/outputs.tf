output "state_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for state locking"
  value       = aws_dynamodb_table.terraform_locks.id
}

output "lambda_function_name" {
  description = "Name of the Lambda destroyer function"
  value       = aws_lambda_function.destroyer.function_name
}

output "backend_config" {
  description = "Backend configuration values for the root module"
  value = {
    bucket         = aws_s3_bucket.terraform_state.id
    key            = var.state_key
    region         = var.aws_region
    dynamodb_table = aws_dynamodb_table.terraform_locks.id
    encrypt        = true
  }
}
