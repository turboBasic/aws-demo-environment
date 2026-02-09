# AWS Demo Environment

Ephemeral 1-day AWS demo environment (VPC, ALB, NAT, EC2) with automated cleanup via a Lambda container that runs `terraform destroy` after 24h.

## Architecture

Two-stage architecture:

1. **`bootstrap/`** (persistent, apply once) — S3 state backend, DynamoDB locks, Secrets Manager, ECR repo, Lambda destroyer, EventBridge hourly schedule
2. **Root module `/`** (ephemeral demo) — VPC, subnets, NAT Gateway, ALB, EC2 instance
3. Bootstrap creates persistent infra (state, Lambda), root creates ephemeral demo. Lambda destroys only root state.

The Lambda destroyer checks the state file age hourly and runs `terraform destroy` when TTL expires.

Other key design principles are provided in @.claude/plans/04-00-aws-demo-environment-architecture.md file, section "Key Design Decisions".

## Workflow

### Deploy bootstrap resources & configure root module backend

See @bootstrap/README.md for detailed instructions

### Deploy resources from the Root module

Execute in the repo root directory

```bash
# 1. Deploy resources
terraform init
terraform apply

# 2. Demo auto-destroys after 24h (or manually: terraform destroy)
```

## Terraform Commands

```bash
terraform init          # Initialize providers and modules
terraform fmt           # Format all .tf files
terraform fmt -check    # Check formatting without modifying
terraform validate      # Validate configuration syntax
terraform plan          # Preview changes
terraform apply         # Apply changes (requires confirmation)
terraform destroy       # Tear down all resources (requires confirmation)
```

## Project Structure

Use file structure provided in @.claude/plans/04-00-aws-demo-environment-architecture.md file, section "File Structure".

## Conventions

- Use Conventional commits standard for commit messages
- For Terraform code use conventions provided in @.claude/plans/04-00-aws-demo-environment-architecture.md file, section "Conventions"
