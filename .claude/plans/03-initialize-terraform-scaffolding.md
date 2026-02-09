# Plan: Initialize Terraform Project Scaffolding

## Context

Set up the scaffolding for standard Terraform project for an AWS demo environment with provider config, variable declarations, and placeholder files.

## Steps

- [x] Create `main.tf` — Terraform block with `required_version >= 1.14`, `hashicorp/aws >= 6.30`, AWS provider using `var.aws_region`
- [x] Create `variables.tf` — `aws_region` (default `eu-central-1`), `environment` (default `demo`), `project_name` (default `aws-demo`)
- [x] Create `outputs.tf` — Empty placeholder with comment
- [x] Create `backend.tf` — Commented-out S3 backend config
- [x] Create `terraform.tfvars.example` — Example values for all variables

## Status: Completed
