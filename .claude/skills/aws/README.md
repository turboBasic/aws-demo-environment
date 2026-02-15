# AWS Authentication Skill

Helper scripts and documentation for managing AWS authentication with the `cargonautica` profile.

## Files

- **SKILL.md** - Main skill documentation for Claude Code
- **scripts/check-aws-auth.sh** - Verify AWS authentication is valid
- **scripts/setup-aws-auth.sh** - Set up AWS profile and verify authentication

## Quick Start

```bash
# Check authentication status
.claude/skills/aws/scripts/check-aws-auth.sh

# Set up authentication (should be sourced to export AWS_PROFILE)
export AWS_PROFILE=cargonautica
aws sts get-caller-identity
```

## Authentication Flow

1. **Check** if authentication is valid with `check-aws-auth.sh`
2. **Export** the AWS profile: `export AWS_PROFILE=cargonautica`
3. **Verify** with AWS CLI: `aws sts get-caller-identity`
4. **If expired**, user must run: `aws sso login --profile cargonautica`

## Integration

This skill integrates with:

- AWS CLI commands
- Terraform operations (via AWS SDK)
- Existing SSO credentials script ([.claude/scripts/aws-sso-credentials.sh](../../scripts/aws-sso-credentials.sh))

See the main [CLAUDE.md](../../../CLAUDE.md) file for complete AWS authentication documentation.
