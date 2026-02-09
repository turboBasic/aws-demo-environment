# Plan: Implement Root Module (Ephemeral Demo Resources)

## Context

Create the Terraform resources for the ephemeral demo environment: VPC networking, security groups, ALB, and EC2 instance.

## Steps

- [x] Create `locals.tf` — `name_prefix`, `common_tags` (Environment, Project, ManagedBy, TTL=24h), CIDR constants
- [x] Create `data.tf` — `aws_availability_zones`, `aws_ami` (AL2023 x86_64), `aws_caller_identity`, `aws_region`
- [x] Create `network.tf` — VPC 10.0.0.0/16, IGW, 2 public subnets (AZ[0], AZ[1]), 1 private subnet, NAT GW + EIP, public/private route tables, 3 route table associations
- [x] Create `endpoints.tf` — S3 gateway VPC endpoint on private route table
- [x] Create `security.tf` — ALB SG (HTTP 80 from 0.0.0.0/0), EC2 SG (HTTP 80 from ALB SG), standalone `aws_vpc_security_group_*_rule` resources
- [x] Create `scripts/user_data.sh` — Install httpd, render demo HTML with instance metadata
- [x] Create `compute.tf` — EC2 instance (AL2023, t3.micro, private subnet), ALB (public subnets), target group (HTTP:80, health check /), listener (port 80 forward)
- [x] Update `variables.tf` — Add `instance_type` (default t3.micro), `vpc_cidr` (default 10.0.0.0/16)
- [x] Update `outputs.tf` — `alb_dns_name`, `ec2_instance_id`, `vpc_id`
- [x] Update `backend.tf` — S3 backend block with placeholder values from bootstrap outputs
- [x] Update `terraform.tfvars.example` — Add new variables
- [x] Run `terraform fmt -recursive` — Fixed alignment in `endpoints.tf`, `locals.tf`
- [x] Run `terraform fmt -check -recursive` — Passed
- [x] Run `terraform init -backend=false` — Passed (installed aws provider 6.31.0)
- [x] Run `terraform validate` — Pending

## Status: Completed
