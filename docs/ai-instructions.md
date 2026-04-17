# AI Instructions

> **Single source of truth for AI coding instructions.**
>
> - **Claude Code** reads this via `CLAUDE.md` (`@docs/ai-instructions.md`).
> - **GitHub Copilot** reads `.github/copilot-instructions.md`, which links to this file.
> - **Edit only this file.** CI verifies Copilot instructions reference it.

---

# AWS Demo Environment

Ephemeral 1-day AWS demo environment (VPC, ALB, NAT, EC2) with automated cleanup via a Lambda container that runs `terraform destroy` after 24h.

## Architecture

Two-stage architecture:

1. **`bootstrap/`** (persistent, apply once) — S3 state backend, DynamoDB locks, Secrets Manager, ECR repo, Lambda destroyer, EventBridge hourly schedule
2. **Root module `/`** (ephemeral demo) — VPC, subnets, NAT Gateway, ALB, EC2 instance
3. Bootstrap creates persistent infra (state, Lambda), root creates ephemeral demo. Lambda destroys only root state.

The Lambda destroyer checks the state file age hourly and runs `terraform destroy` when TTL expires.

Other key design principles are provided in @.claude/plans/04-00-aws-demo-environment-architecture.md file, section "Key Design Decisions".

## Tech Stack

| Tool             | Version / Notes |
| ---------------- | --------------- |
| Primary language | Terraform (HCL) |
| CI               | GitHub Actions  |

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

```text
aws-demo-environment/
├── main.tf                          # Root module: providers, module calls
├── variables.tf                     # Root variables
├── outputs.tf                       # Root outputs
├── backend.tf                       # S3 backend configuration
├── locals.tf                        # name_prefix, common_tags, CIDR constants
├── data.tf                          # AZs, AMI, caller_identity, region
├── moved.tf                         # Terraform moved blocks for resource renames
├── terraform.tfvars.example         # Example variable values
├── terraform.tfvars                 # Local variable values (gitignored)
├── README.md                        # Project documentation
├── CLAUDE.md                        # Claude Code instructions
├── assets/
│   └── static/                      # Static web assets served by EC2
│       ├── index.html
│       ├── script.js
│       └── style.css
├── modules/
│   ├── application-load-balancer/   # ALB, target group, listener
│   ├── dns-cloudflare/              # Cloudflare DNS record management
│   ├── ecs-fargate/                 # ECS Fargate cluster and service
│   ├── generic-storage/             # S3 bucket + IAM user with MFA-enforced role
│   ├── networking/                  # VPC, subnets, IGW, route tables
│   ├── networking-nat-gw/           # NAT Gateway and private routing
│   ├── obsidian-vaults/             # S3-backed Obsidian vault storage
│   ├── ssl-certificates/            # ACM certificate provisioning
│   ├── static-site/                 # CloudFront + S3 static site hosting
│   └── web-instance/                # EC2 instance with user_data template
│       └── user_data.sh.tftpl       # httpd install + demo HTML template
├── scripts/
│   └── setup-s3-user-mfa.sh        # Helper to configure MFA for S3 IAM user
├── docs/
│   └── ai-instructions.md           # AI coding instructions (source of truth)
└── bootstrap/
    ├── main.tf                      # Provider config (local backend)
    ├── variables.tf                 # region, github_repo, token, ttl
    ├── outputs.tf                   # bucket, table, backend_config
    ├── locals.tf                    # name_prefix, tags
    ├── state.tf                     # S3 bucket + DynamoDB table
    ├── lambda.tf                    # Lambda function, IAM role, EventBridge rule
    ├── bootstrap-state-bucket.tf    # S3 bucket for bootstrap state backup
    ├── terraform.tfvars.example     # Example variable values
    ├── README.md                    # Bootstrap deployment instructions
    └── lambda-destroyer/
        └── handler.py              # TTL check + terraform destroy via subprocess
```

## Code Style & Conventions

### Commit messages

Use Conventional Commits format: `type(scope): subject` — imperative mood, no trailing period.
Example: `fix(ci): handle missing env variable`

### Terraform

- **Variable naming**: snake_case, descriptive names with `description` and `type` always set
- **File organization**: group related resources into dedicated modules under `modules/`; within a module use focused files (`main.tf`, `variables.tf`, `outputs.tf`, `README.md`)
- **Formatting**: always run `terraform fmt` before finishing any change to `.tf` files
- **Tagging**: tag all resources via `common_tags` from `locals.tf` (root) or `bootstrap/locals.tf`
- **Security groups**: use standalone `aws_vpc_security_group_ingress_rule` / `aws_vpc_security_group_egress_rule` resources (provider 6.x best practice — avoids rule conflicts)

### Formatting (Source of Truth)

- Follow `.editorconfig` in the repository root for formatting rules.
- This includes charset, line endings, indentation, trailing whitespace, final newline,
  and file-type-specific overrides.
- If a formatting rule here ever conflicts with `.editorconfig`, `.editorconfig` wins.
- When generating or formatting code, consult the linter configuration files:
  - **Python** — `pyproject.toml` (`[tool.ruff]` and `[tool.ruff.lint]` sections)
  - **JavaScript / TypeScript / JSON** — `.biome.json`
  - **YAML** — `.yamllint`
  - **Markdown** — `.pymarkdown`

### Adding a new file type

When introducing a file type that is not yet covered, update **both** config files:

1. **`.editorconfig`** — add a glob section with the appropriate overrides.
2. **`.gitattributes`** — add an entry with `text eol=lf` (or `eol=crlf` for Windows-only
   files, or `binary` for binary assets). Add `diff=<language>` when git has a built-in
   driver for that language.

Do this as part of the same change that adds the first file of that type.

## AI Behaviour Guidelines

- **Minimal changes**: prefer targeted edits over large refactors unless explicitly asked
- **Follow existing patterns**: read the surrounding code before suggesting changes
- **Formatting and linting**: after modifying any source file, always run the formatter and linter for the affected file type and fix any issues your change introduced before finishing
- **No secrets**: never generate tokens, passwords, or credentials — use GitHub Actions secrets
- **Skills source of truth**: keep shared skills only in `.claude/skills/`; GitHub Copilot must use these shared skills and must not duplicate skill definitions under `.github/skills/`
- **Commit messages**: use Conventional Commits format `type(scope): subject` (e.g. `fix(ci): handle missing env variable`), with an imperative subject and no trailing period
