---
name: aws
description: Configure AWS authentication for CLI and Terraform operations
user-invocable: false
model: Haiku
allowed-tools: Bash(*/setup-aws-auth.sh), Bash(*/check-aws-auth.sh)
---

# AWS Authentication Helper

## Purpose

This skill helps configure AWS authentication for the `cargonautica` AWS profile, supporting both AWS CLI commands and Terraform operations.

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
export AWS_PROFILE=cargonautica

# Verify it works
aws sts get-caller-identity
```

### 3. Handle Expired SSO Sessions

If SSO session is expired, prompt the user to run:

```bash
aws sso login --profile cargonautica
```

Then retry the authentication check.

### 4. Alternative: Export Temporary Credentials

If explicit credentials are needed (rare cases), use:

```bash
source .claude/scripts/aws-sso-credentials.sh
```

## Authentication Methods

### Method 1: AWS Profile (Recommended)

Most reliable for both AWS CLI and Terraform:

```bash
export AWS_PROFILE=cargonautica

# AWS CLI automatically uses the profile
aws s3 ls

# Terraform automatically uses the profile (via AWS SDK)
terraform plan
```

### Method 2: Temporary Credentials Export

For cases requiring explicit environment variables:

```bash
source .claude/scripts/aws-sso-credentials.sh

# This sets: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN
```

See [@.claude/scripts/aws-sso-credentials.sh](../../scripts/aws-sso-credentials.sh) for implementation.

## Error Handling

### SSO Session Expired

**Error**: `Error when retrieving token from sso: Token has expired`

**Resolution**: Inform user to re-authenticate:
```bash
aws sso login --profile cargonautica
```

### Profile Not Found

**Error**: `Profile cargonautica could not be found`

**Resolution**: Verify AWS CLI configuration file (`~/.aws/config`) contains the profile definition.

### Invalid Credentials

**Error**: `Unable to locate credentials`

**Resolution**:
1. Ensure `AWS_PROFILE=cargonautica` is exported
2. Check SSO session is valid with `aws sts get-caller-identity`
3. Re-run SSO login if needed

## Best Practices

1. **Always export AWS_PROFILE** at the start of terminal sessions
2. **Verify authentication** before running expensive operations
3. **Inform user** if SSO re-authentication is needed (can't be automated)
4. **Use profile over credentials** - more secure and manageable
5. **Don't print credentials** in terminal output

## Integration with Terraform

Terraform automatically uses `AWS_PROFILE` environment variable via the AWS SDK:

```bash
export AWS_PROFILE=cargonautica
terraform plan  # Uses cargonautica profile automatically
```

No additional provider configuration needed in Terraform code when using profiles.
