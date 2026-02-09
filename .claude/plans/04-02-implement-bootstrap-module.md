# Plan: Implement Bootstrap Module (Persistent Infrastructure)

## Context

Create the `bootstrap/` module containing persistent infrastructure: S3 state backend, DynamoDB locks, Secrets Manager, ECR repository, Lambda destroyer function, and EventBridge hourly schedule.

## Steps

- [x] Create `bootstrap/main.tf` — Terraform block (>= 1.14, aws >= 6.30), local backend, AWS provider
- [x] Create `bootstrap/variables.tf` — `aws_region`, `project_name`, `environment`, `github_repo`, `github_token` (sensitive), `ttl_hours` (default 24), `state_key`
- [x] Create `bootstrap/locals.tf` — `name_prefix`, `account_id`, `common_tags`, data sources
- [x] Create `bootstrap/outputs.tf` — `state_bucket_name`, `dynamodb_table_name`, `ecr_repository_url`, `lambda_function_name`, `secret_arn`, `backend_config` map
- [x] Create `bootstrap/state.tf` — S3 bucket (versioning, SSE, public access block, prevent_destroy), DynamoDB table (PAY_PER_REQUEST, LockID)
- [x] Create `bootstrap/secrets.tf` — Secrets Manager secret + version for GitHub token
- [x] Create `bootstrap/ecr.tf` — ECR repository (force_delete, scan_on_push), lifecycle policy (keep last 3)
- [x] Create `bootstrap/lambda.tf` — IAM role + policies (state access, demo resource management), null_resource Docker build/push, Lambda function (container, 15min, 512MB), EventBridge rule (hourly) + target + permission
- [x] Create `bootstrap/terraform.tfvars.example`
- [x] Run `terraform init` in bootstrap/ — Success
- [x] Run `terraform validate` in bootstrap/ — Success

## Status: Completed
