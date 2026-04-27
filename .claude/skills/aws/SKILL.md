---
name: aws
description: Configure AWS authentication for CLI and Terraform operations
user-invocable: false
model: Haiku
allowed-tools: Bash(*/setup-aws-auth.sh), Bash(*/check-aws-auth.sh)
---

# AWS Authentication Helper

## Purpose

This skill helps configure AWS authentication for the `Cargonautica` AWS profile, supporting both AWS CLI commands and Terraform operations.

## When to Use

Use this skill **before** running:

- Any AWS CLI commands (`aws s3`, `aws ec2`, etc.)
- Terraform commands that interact with AWS (`terraform plan`, `terraform apply`, etc.)
- When authentication errors occur (expired SSO session)

## How to Use

### 1. Check Current Authentication Status

```bash
.claude/skills/aws/scripts/check-aws-auth.sh
```

This verifies if the current AWS authentication is valid.

### 2. Set Up Authentication

```bash
# Export AWS profile (preferred method)
export AWS_PROFILE=Cargonautica

# Verify it works
aws sts get-caller-identity
```

### 3. Handle Expired SSO Sessions

If SSO session is expired, prompt the user to run:

```bash
aws sso login --profile Cargonautica
```

Then retry the authentication check.

### 4. Alternative: Export Temporary Credentials

If explicit credentials are needed (rare cases), use:

```bash
source .claude/scripts/aws-sso-credentials.sh
```

## Error Handling

### SSO Session Expired

**Error**: `Error when retrieving token from sso: Token has expired`

**Resolution**: Inform user to re-authenticate:

```bash
aws sso login --profile Cargonautica
```

### Profile Not Found

**Error**: `Profile Cargonautica could not be found`

**Resolution**: Verify AWS CLI configuration file (`~/.aws/config`) contains the profile definition.

### Invalid Credentials

**Error**: `Unable to locate credentials`

**Resolution**:
1. Ensure `AWS_PROFILE=Cargonautica` is exported
2. Check SSO session is valid with `aws sts get-caller-identity`
3. Re-run SSO login if needed
