# Plan: Implement Bootstrap Module (Persistent Infrastructure)

## Context

Create the `bootstrap/` module containing persistent infrastructure: S3 state backend, DynamoDB locks, Lambda destroyer function, and EventBridge hourly schedule.

For architecture context, see [04-00-aws-demo-environment-architecture.md](04-00-aws-demo-environment-architecture.md).
For Lambda handler code, see [04-03-implement-lambda-destroyer.md](04-03-implement-lambda-destroyer.md).
For deployment instructions, see [bootstrap/README.md](../../bootstrap/README.md).

## Steps

- [x] Create `bootstrap/main.tf` — Terraform block (>= 1.14, aws >= 6.30, archive >= 2.0), local backend, AWS provider
- [x] Create `bootstrap/variables.tf` — `aws_region`, `project_name`, `environment`, `ttl_minutes` (default 1440), `state_key`
- [x] Create `bootstrap/locals.tf` — `name_prefix`, `account_id`, `common_tags`, data sources
- [x] Create `bootstrap/outputs.tf` — `state_bucket_name`, `dynamodb_table_name`, `lambda_function_name`, `backend_config` map, `bootstrap_state_bucket_name`, `bootstrap_state_backup_commands`
- [x] Create `bootstrap/state.tf` — S3 bucket (versioning, KMS encryption, public access block, prevent_destroy), DynamoDB table (PAY_PER_REQUEST, LockID)
- [x] Create `bootstrap/lambda.tf` — IAM role + policies (state access, resource tagging, demo resource management), `archive_file` zip of handler, Lambda function (Python 3.12, 15min, 256MB), EventBridge hourly schedule rule + target + permission
- [x] Create `bootstrap-state-bucket.tf` — S3 bucket for manual backing up of bootstrap's Terraform state
- [x] Create `bootstrap/terraform.tfvars.example`
- [x] Run `terraform init` in bootstrap/ — Success
- [x] Run `terraform validate` in bootstrap/ — Success

## Status: Completed
