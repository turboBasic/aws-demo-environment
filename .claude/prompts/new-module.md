---
name: new-module
description: Scaffold a new Terraform module under modules/ following repo conventions
---

# New Terraform Module

Scaffold a new Terraform module under `modules/<module-name>/` following the repo's conventions.

## Required argument

The user must supply the module name (e.g. `new-module my-feature`). If omitted, ask for it before proceeding.

## Steps

1. **Read context** — read `locals.tf` and one existing module (e.g. `modules/networking/`) to understand `common_tags`, `name_prefix`, and variable patterns before writing anything.

2. **Create the module directory** with these files:
   - `main.tf` — resources for this module; tag all resources via `var.common_tags`
   - `variables.tf` — all input variables with `description` and `type` always set; include `common_tags` and `name_prefix` as standard inputs
   - `outputs.tf` — any values the root module will consume
   - `README.md` — one-paragraph purpose, inputs table, outputs table

3. **Wire it into the root module** — add a `module "<name>"` block in `main.tf` passing `common_tags` and `name_prefix`.

4. **Format** all new `.tf` files:

   ```bash
   mise exec -- terraform fmt modules/<module-name>/
   ```

5. **Validate** the root module:

   ```bash
   mise exec -- uv run pre-commit run --files modules/<module-name>/main.tf modules/<module-name>/variables.tf modules/<module-name>/outputs.tf
   ```

6. Fix any reported issues before finishing.

## Conventions

- snake_case variable names; `description` and `type` required on every variable
- Security group rules use standalone `aws_vpc_security_group_ingress_rule` / `aws_vpc_security_group_egress_rule` (not inline blocks)
- All resources tagged via `var.common_tags`
- Follow `.editorconfig` for indentation and line endings
