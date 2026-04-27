<!-- pyml disable md025 -->
# AI Instructions

> **Single source of truth for AI coding instructions.**
>
> - **Claude Code** reads this via `CLAUDE.md` (`@docs/ai-instructions.md`).
> - **GitHub Copilot** reads `.github/copilot-instructions.md`, which links to this file.
> - **Edit only this file.** CI verifies Copilot instructions reference it.

---

# AWS Demo Environment

Ephemeral AWS demo environment fronted by CloudFront and an ALB (ECS Fargate backend, optional EC2 web instance), alongside persistent S3-backed Obsidian vaults and MFA-enforced generic storage. TTL-tagged demo resources are cleaned up automatically after 24h by a scheduled Lambda destroyer.

## Architecture

Two-stage deployment:

1. **`bootstrap/`** (persistent, apply once) — S3 state backend, S3 state-backup bucket, DynamoDB lock table, Lambda destroyer, EventBridge hourly schedule, IAM roles.
2. **Root module `/`** (ephemeral demo) — VPC and networking, ALB, ECS Fargate service, optional NAT Gateway, optional EC2 web instance, CloudFront + S3 static site, ACM certificates, Cloudflare DNS, Obsidian vaults, MFA-enforced generic storage.

The Lambda destroyer checks the root-module state-file age hourly; when the TTL expires, it deletes TTL-tagged resources (ALB, ECS services, target groups, EC2 instances, NAT gateways, Elastic IPs) via AWS SDK calls. It does **not** invoke `terraform destroy`.

See [README.md](../README.md#architecture) for a visual diagram, and [.claude/plans/04-00-aws-demo-environment-architecture.md](.claude/plans/04-00-aws-demo-environment-architecture.md) section "Key Design Decisions" for design rationale.

## Tech Stack

| Tool             | Version / Notes                                                      |
| ---------------- | -------------------------------------------------------------------- |
| Primary language | Terraform (HCL)                                                      |
| Task runner      | `make` (see [Makefile](../Makefile))                                 |
| Python toolchain | [`uv`](https://docs.astral.sh/uv/) — dev deps in `pyproject.toml`    |
| Tool versioning  | [`mise`](https://mise.jdx.dev) — pins `terraform`, `uv`, etc.        |
| CI               | GitHub Actions                                                       |

## Workflow

Run `make help` for available dev targets. For first-time bootstrap setup, see [bootstrap/README.md](../bootstrap/README.md).

For Terraform operations, always use the `terraform` skill (see [.claude/skills/terraform/SKILL.md](.claude/skills/terraform/SKILL.md)) and the `aws` skill for authentication (see [.claude/skills/aws/SKILL.md](.claude/skills/aws/SKILL.md)).

For the current project structure, use `Glob` or read [README.md](../README.md).

## Code Style & Conventions

### Commit messages

Use Conventional Commits format: `type(scope): subject` — imperative mood, no trailing period.
Example: `fix(ci): handle missing env variable`

### Terraform

- **Variable naming**: snake_case, descriptive names with `description` and `type` always set
- **File organization**: group related resources into dedicated modules under `modules/`; within a module use focused files (`main.tf`, `variables.tf`, `outputs.tf`, `README.md`)
- **Formatting**: always run `mise exec -- terraform fmt` before finishing any change to `.tf` files
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

- **bootstrap/ is out of scope by default**: treat `bootstrap/` as a one-time setup directory; do not read, introspect, or suggest changes to files under `bootstrap/` unless the request explicitly concerns the bootstrapping process
- **Minimal changes**: prefer targeted edits over large refactors unless explicitly asked
- **Follow existing patterns**: read the surrounding code before suggesting changes
- **Pre-commit validation**: after modifying any source file, run `mise exec -- uv run pre-commit run --files <changed files>` (or `make lint` for a full sweep) and fix every reported issue before finishing — do not skip or bypass hooks
- **Dev deps**: when adding/removing a Python dev dependency, prefer `mise exec -- uv add --group <group> <pkg>` / `uv remove <pkg>`. If editing `pyproject.toml` by hand, run `make lock` followed by `make install` and commit `pyproject.toml` and `uv.lock` together
- **No secrets**: never generate tokens, passwords, or credentials — use GitHub Actions secrets
- **Skills source of truth**: keep shared skills only in `.claude/skills/`; GitHub Copilot must use these shared skills and must not duplicate skill definitions under `.github/skills/`
- **Commit messages**: follow the Conventional Commits format defined in [Code Style & Conventions](#commit-messages) above
- **No documentation duplication**: reference a single source of truth instead of replicating content; when a skill, README, or config file already documents something, link to it rather than copying it here
