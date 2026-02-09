output "state_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for state locking"
  value       = aws_dynamodb_table.terraform_locks.id
}

output "ecr_repository_url" {
  description = "URL of the ECR repository for the Lambda destroyer image"
  value       = aws_ecr_repository.lambda_destroyer.repository_url
}

output "lambda_function_name" {
  description = "Name of the Lambda destroyer function"
  value       = aws_lambda_function.destroyer.function_name
}

output "secret_arn" {
  description = "ARN of the Secrets Manager secret for the GitHub token"
  value       = aws_secretsmanager_secret.github_token.arn
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
