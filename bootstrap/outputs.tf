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

output "bootstrap_state_bucket_name" {
  description = "Name of the S3 bucket for backing up bootstrap terraform.tfstate"
  value       = aws_s3_bucket.bootstrap_state.id
}

output "bootstrap_state_backup_commands" {
  description = "Commands to backup and restore bootstrap state"
  value = {
    upload   = "aws s3 cp terraform.tfstate s3://${aws_s3_bucket.bootstrap_state.id}/terraform.tfstate"
    download = "aws s3 cp s3://${aws_s3_bucket.bootstrap_state.id}/terraform.tfstate terraform.tfstate"
    list     = "aws s3 ls s3://${aws_s3_bucket.bootstrap_state.id}/"
  }
}
