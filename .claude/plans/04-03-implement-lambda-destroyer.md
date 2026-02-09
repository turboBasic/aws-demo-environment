# Plan: Implement Lambda Destroyer Container

## Context

Create the Lambda container image that checks Terraform state age and runs `terraform destroy` when the TTL expires.

## Steps

- [x] Create `bootstrap/lambda-destroyer/Dockerfile` — `public.ecr.aws/lambda/python:3.12`, install git+unzip+curl via dnf, download Terraform 1.14.0 binary, pip install requirements, copy handler
- [x] Create `bootstrap/lambda-destroyer/handler.py` — `get_github_token()` from Secrets Manager, `get_state_age_hours()` via S3 HeadObject, `state_has_resources()` via S3 GetObject, `run_terraform_destroy()` with `-backend-config` flags, `lambda_handler()` orchestrator
- [x] Create `bootstrap/lambda-destroyer/requirements.txt` — `boto3>=1.35.0`

## Handler Logic

1. Check S3 state file `LastModified` age
2. Skip if no state file, not expired, or no managed resources
3. Retrieve GitHub token from Secrets Manager
4. Clone repo with token auth (`x-access-token`)
5. Run `terraform init -backend-config=...`
6. Run `terraform destroy -auto-approve`

## Status: Completed
