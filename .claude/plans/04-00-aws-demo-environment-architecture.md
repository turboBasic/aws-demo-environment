# Plan: AWS Demo Environment with Automated 24h Cleanup

## Context

Build a complete, production-quality Terraform configuration that deploys an ephemeral 1-day AWS demo environment (VPC, ALB, EC2) with automated cleanup via a Lambda container that runs `terraform destroy` after 24h. Two-stage architecture: persistent `bootstrap/` resources (state backend, Lambda, EventBridge) and ephemeral root module resources (networking, compute).

## Architecture

```text
┌────────────────────────────────────────────────────────┐
│  bootstrap/ (persistent, apply once)                   │
│  ┌──────────┐ ┌──────────┐ ┌────────────┐ ┌─────────┐  │
│  │ S3 State │ │ DynamoDB │ │  Secrets   │ │  ECR    │  │
│  │  Bucket  │ │  Locks   │ │  Manager   │ │  Repo   │  │
│  └──────────┘ └──────────┘ └────────────┘ └─────────┘  │
│  ┌──────────────────────┐  ┌────────────────────────┐  │
│  │  Lambda Destroyer    │  │  EventBridge (hourly)  │  │
│  │  (container image)   │◄─│  schedule rule         │  │
│  └──────────────────────┘  └────────────────────────┘  │
└────────────────────────────────────────────────────────┘
         │ terraform destroy -auto-approve
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
│
└── bootstrap/
    ├── main.tf              # Provider config (local backend)
    ├── variables.tf         # region, github_repo, token, ttl
    ├── outputs.tf           # bucket, table, ECR URL, backend_config
    ├── locals.tf            # name_prefix, tags, data sources
    ├── state.tf             # S3 bucket + DynamoDB table
    ├── secrets.tf           # Secrets Manager (GitHub token)
    ├── ecr.tf               # ECR repo + lifecycle policy
    ├── lambda.tf            # Lambda, IAM, EventBridge, Docker build
    ├── terraform.tfvars.example
    └── lambda-destroyer/
        ├── Dockerfile       # python:3.12 + terraform + git
        ├── handler.py       # TTL check + terraform destroy logic
        └── requirements.txt # boto3
```

## Implementation Plans

Detailed implementation steps are in the individual plan files:

- [04-01-implement-root-module.md](04-01-implement-root-module.md) — VPC, networking, security groups, ALB, EC2
- [04-02-implement-bootstrap-module.md](04-02-implement-bootstrap-module.md) — State backend, Secrets, ECR, Lambda, EventBridge
- [04-03-implement-lambda-destroyer.md](04-03-implement-lambda-destroyer.md) — Lambda container image (Dockerfile, handler, requirements)

After implementation steps, commit files.

## Key Design Decisions

1. **Two-stage architecture** — Bootstrap creates persistent infra (state, Lambda), root creates ephemeral demo. Lambda destroys only root state.
2. **ALB needs 2 AZs** — AWS requires ALB subnets in >=2 AZs. Two public subnets but only 1 private subnet (cost savings: single NAT GW).
3. **TTL via S3 LastModified** — Lambda checks state file age. Each `terraform apply` resets the timer. Simple, no extra infra.
4. **Lambda container** — Terraform CLI + Git in container image. 15-min timeout, 512MB memory. Destroy typically takes 3-7 min.
5. **Standalone SG rules** — Using `aws_vpc_security_group_ingress_rule` (provider 6.x best practice, avoids rule conflicts).
6. **NAT Gateway over NAT instance** — Simpler, managed. Dominates cost (~$1.15/day) but acceptable for demo.
7. **No VPC access for Lambda** — Lambda runs outside VPC. It clones the repo and runs `terraform destroy` which internally calls AWS APIs via the Lambda's IAM execution role credentials. Lambda does NOT make direct boto3 calls to delete resources.
8. **GitHub repo** — Hardcoded default: `turboBasic/aws-demo-environment`. Lambda clones it, runs `terraform init` with `-backend-config` flags, then `terraform destroy -auto-approve`.

## Conventions

- **Variable naming**: snake_case, descriptive names with `description` and `type` set
- **File organization**: Group related resources into dedicated .tf files (e.g. `network.tf`, `compute.tf`)
- **Formatting**: Always run `terraform fmt` before committing
- **Tagging**: All resources should include `Environment` and `Project` tags using `var.environment` and `var.project_name`
- **Security groups**: Use standalone `aws_vpc_security_group_ingress_rule` / `aws_vpc_security_group_egress_rule` (provider 6.x best practice)
