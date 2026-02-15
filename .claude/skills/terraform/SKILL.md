---
name: terraform
description: Find terraform executable to run terraform commands
user-invocable: false
model: Haiku
allowed-tools: Bash(*/find-terraform.sh)
---

# Terraform Executable Locator

## Purpose

This skill helps locate the correct `terraform` executable on the system, handling various installation methods (system PATH, mise, tfenv, asdf, Homebrew, etc.).

## When to Use

**ALWAYS** use this skill before running ANY `terraform` command. This includes:
- `terraform init`
- `terraform plan` 
- `terraform apply`
- `terraform destroy`
- `terraform fmt`
- `terraform validate`
- Any other terraform subcommands

## How to Use

1. **Find the executable once per session:**
   Execute the [find-terraform.sh](scripts/find-terraform.sh) script to get the terraform path.

2. **Cache the result:**
   Store the returned path and reuse it for all subsequent terraform commands in the current conversation.

3. **Use in commands:**
   Replace `terraform` with the full path returned by the script in all commands.

## Example Usage

```bash
# Step 1: Find terraform (do this once)
TERRAFORM_BIN=$(.claude/skills/terraform/scripts/find-terraform.sh)

# Step 2: Use in commands
$TERRAFORM_BIN init
$TERRAFORM_BIN plan
$TERRAFORM_BIN apply
```

## Script Behavior

The script checks for terraform in the following order:
1. System PATH (`which terraform`)
2. Mise installation (`~/.local/share/mise/installs/terraform/*/bin/terraform`)
3. tfenv installation (`~/.tfenv/bin/terraform`)
4. asdf installation (`~/.asdf/installs/terraform/*/bin/terraform`)
5. Homebrew installation (macOS)

Returns the first valid terraform executable found, or an error message if none found.

## Error Handling

If the script returns an error message (not a valid path), inform the user that terraform is not installed and suggest installation methods:
- `brew install terraform` (macOS)
- `mise install terraform` (if mise is available)
- Download from https://www.terraform.io/downloads
