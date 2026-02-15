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

## AWS Authentication

**IMPORTANT**: Always use the `aws` skill to configure authentication before running AWS CLI commands or Terraform operations.

When executing AWS CLI commands or Terraform, use the `cargonautica` AWS profile:

```bash
export AWS_PROFILE=cargonautica
aws sts get-caller-identity
```

See [@.claude/skills/aws/SKILL.md](.claude/skills/aws/SKILL.md) for complete authentication documentation including setup helpers, error handling, and alternative methods.

## Terraform Executable Location

**IMPORTANT**: Before running any Terraform commands, always use the terraform skill to locate the correct terraform executable on the system.

Quick start:

```bash
TERRAFORM_BIN=$(.claude/skills/terraform/scripts/find-terraform.sh)
$TERRAFORM_BIN init
$TERRAFORM_BIN plan
$TERRAFORM_BIN apply
```

See [@.claude/skills/terraform/SKILL.md](.claude/skills/terraform/SKILL.md) for complete documentation including supported installation methods and error handling.

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
- For Terraform code use conventions provided in 04-00-aws-demo-environment-architecture.md file, section "Conventions"
