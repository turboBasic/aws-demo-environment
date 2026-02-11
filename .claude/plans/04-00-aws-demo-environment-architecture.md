# Plan: AWS Demo Environment with Automated 24h Cleanup

## Context

Build a complete, production-quality Terraform configuration that deploys an ephemeral 1-day AWS demo environment (VPC, ALB, EC2) with automated cleanup via a Lambda function that removes expensive resources after 24h using native AWS API calls. Two-stage architecture: persistent `bootstrap/` resources (state backend, Lambda, EventBridge) and ephemeral root module resources (networking, compute).

## Architecture

```text
┌─────────────────────────────────────────────────┐
│  bootstrap/ (persistent, apply once)            │
│  ┌──────────┐ ┌──────────┐                       │
│  │ S3 State │ │ DynamoDB │                       │
│  │  Bucket  │ │  Locks   │                       │
│  └──────────┘ └──────────┘                       │
│  ┌──────────────────────┐  ┌─────────────────┐  │
│  │  Lambda Destroyer    │  │  EventBridge    │  │
│  │   (Python + boto3)   │◄─│  schedule rule  │  │
│  └──────────────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────┘
         │ deletes tagged resources via AWS APIs
         ▼
┌─────────────────────────────────────────────────┐
│  root / (ephemeral demo, one terraform apply)   │
│  ┌───────────────────────────────────────────┐  │
│  │  VPC 10.0.0.0/16                          │  │
│  │  ┌─────────────┐ ┌─────────────┐          │  │
│  │  │ Public-A    │ │ Public-B    │ (2 AZs   │  │
│  │  │ 10.0.1.0/24 │ │ 10.0.2.0/24 │ for ALB) │  │
│  │  │  ┌──────┐   │ └─────────────┘          │  │
│  │  │  │ NAT  │   │                          │  │
│  │  │  │ GW   │   │ ┌──────────────┐         │  │
│  │  │  └──────┘   │ │ ALB (public) │         │  │
│  │  └─────────────┘ └─────────┬────┘         │  │
│  │  ┌─────────────────────────┼────┐         │  │
│  │  │ Private-A 10.0.10.0/24  │    │         │  │
│  │  │ ┌───────────────────────▼─┐  │         │  │
│  │  │ │ EC2 t3.micro (httpd)    │  │         │  │
│  │  │ └─────────────────────────┘  │         │  │
│  │  │ S3 Gateway Endpoint          │         │  │
│  │  └──────────────────────────────┘         │  │
│  └───────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
```

## File Structure

```text
aws-demo-environment/
├── main.tf                  # Provider config and terraform block
├── variables.tf             # aws_region, environment, project_name, instance_type, vpc_cidr
├── outputs.tf               # alb_dns_name, ec2_instance_id, vpc_id
├── backend.tf               # S3 backend (fill values from bootstrap outputs)
├── locals.tf                # name_prefix, common_tags, CIDR constants
├── data.tf                  # AZs, AMI (AL2023), caller_identity, region
├── network.tf               # VPC, subnets, IGW, NAT GW, route tables
├── security.tf              # ALB SG, EC2 SG (standalone rules)
├── compute.tf               # EC2, ALB, target group, listener
├── endpoints.tf             # S3 gateway VPC endpoint
├── scripts/user_data.sh     # httpd install + demo HTML
├── terraform.tfvars.example # Example variable values
├── CLAUDE.md                # Project documentation
└── bootstrap/
    ├── bootstrap-state-bucket.tf   # S3 bucket for manual backing up of bootsrap's Terraform state
    ├── main.tf                     # Provider config (local backend)
    ├── variables.tf                # region, github_repo, token, ttl
    ├── outputs.tf                  # bucket, table, ECR URL, backend_config
    ├── locals.tf                   # name_prefix, tags, data sources
    ├── state.tf                    # S3 bucket + DynamoDB table
    ├── secrets.tf                  # Secrets Manager (GitHub token)
    ├── ecr.tf                      # ECR repo + lifecycle policy
    ├── lambda.tf                   # Lambda, IAM, EventBridge
    ├── terraform.tfvars.example.   # Example variable values
    └── lambda-destroyer/           # Code of Lambda
        ├── handler.py              # TTL check + remove expensive resources
        └── requirements.txt        # boto3
```

## Implementation Plans

Detailed implementation steps are in the individual plan files:

- [04-01-implement-root-module.md](04-01-implement-root-module.md) — VPC, networking, security groups, ALB, EC2
- [04-02-implement-bootstrap-module.md](04-02-implement-bootstrap-module.md) — State backend, Secrets, Lambda, EventBridge
- [04-03-implement-lambda-destroyer.md](04-03-implement-lambda-destroyer.md) — Code of Lambda function (handler, requirements)

After implementation steps, commit files.

## Key Design Decisions

1. **Two-stage architecture** — Bootstrap creates persistent infra (state, Lambda), root creates ephemeral demo. Lambda destroys only root state.
2. **ALB needs 2 AZs** — AWS requires ALB subnets in >=2 AZs. Two public subnets but only 1 private subnet (cost savings: single NAT GW).
3. **TTL via S3 LastModified** — Lambda checks state file age. Each `terraform apply` resets the timer. Simple, no extra infra.
4. **Lambda container** — Python with boto3. 15-min timeout, 256MB memory. Destroy typically takes 2-3 min.
5. **Standalone SG rules** — Using `aws_vpc_security_group_ingress_rule` (provider 6.x best practice, avoids rule conflicts).
6. **NAT Gateway over NAT instance** — Simpler, managed. Dominates cost (~$1.15/day) but acceptable for demo.
7. **No VPC access for Lambda** — Lambda runs outside VPC. It calls AWS APIs via the Lambda's IAM execution role credentials.

## Conventions

- **Variable naming**: snake_case, descriptive names with `description` and `type` set
- **File organization**: Group related resources into dedicated .tf files (e.g. `network.tf`, `compute.tf`)
- **Formatting**: Always run `terraform fmt` before committing
- **Tagging**: All resources should be tagged (see `common_tags` in @/locals.tf and in @/bootstrap/locals.tf)
- **Security groups**: Use standalone `aws_vpc_security_group_ingress_rule` / `aws_vpc_security_group_egress_rule` (provider 6.x best practice)
