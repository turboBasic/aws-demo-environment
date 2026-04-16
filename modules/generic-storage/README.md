# Generic Storage Module

Creates an IAM user with MFA-enforced role access to an S3 bucket.

## Overview

This module sets up:

- **IAM User** (`s3-user`) — Source identity for MFA-backed role assumption
- **Access Keys** — For AWS CLI and SDK authentication
- **S3 Policy** — Full S3 permissions (`s3:*`) scoped to the module-created bucket
- **IAM Role** — MFA-enforced assume role with S3 full access
- **Trust Policy** — Restricts role assumption to the IAM user when MFA is present
- **IAM User Policy** — Allows the user to assume the role
- **S3 Hardening Controls** — Default encryption, blocked public access, TLS-only access, and BucketOwnerEnforced ownership

## Architecture

```
┌─────────────────┐
│   s3-user IAM   │
│     Account     │
└────────┬────────┘
         │
         ├─ Access Keys (CLI/SDK)
         │
         └─ Can assume role with MFA
              │
              ▼
┌──────────────────────────────────────┐
│ S3AccessRole-s3-user                 │
├──────────────────────────────────────┤
│ Trust Policy:                        │
│ • Principal: s3-user                 │
│ • Condition: MFA Present             │
├──────────────────────────────────────┤
│ Permissions:                         │
│ • s3:* on <bucket_name>-<account_id> │
└──────────────────────────────────────┘
```

## Security Model

The module enforces MFA for S3 operations:

1. **IAM user has no direct S3 permissions** — `s3-user` is only allowed to call `sts:AssumeRole` for the module-created role.
2. **MFA is mandatory to assume the role** — the role trust policy requires `aws:MultiFactorAuthPresent = true`.
3. **All S3 permissions are on the role** — after successful MFA-backed role assumption, temporary STS credentials are used for S3 access.

This means leaked long-term access keys alone are not enough to access the bucket; the attacker would also need a valid MFA code.

## Usage

```hcl
module "generic_storage" {
  source = "./modules/generic-storage"

  user_name   = "s3-user"
  bucket_name = "00-personal"
}
```

## Post-Deployment MFA Setup

After applying this module, register an MFA device for the s3-user:

```bash
# From the repository root
./scripts/setup-s3-user-mfa.sh --cleanup
```

This script:
- Creates a virtual MFA device
- Registers it with the s3-user account
- Extracts the seed from the QR code
- Saves credentials and MFA details to 1Password
- Provides configuration instructions for AWS CLI

### Prerequisites for MFA Setup

- `jq` — JSON processing
- `zbar` — QR code reading
- `1password-cli` — Optional, for automatic 1Password integration
- AWS CLI with appropriate IAM permissions

### Manual MFA Setup Alternative

If you prefer to set up MFA manually:

1. Create a virtual MFA device in the AWS console for the `s3-user`
2. Use the QR code with 1Password or your authenticator app
3. Retrieve the access key and secret from Terraform outputs
4. Configure your AWS profile with MFA support

## Outputs

- `access_key_id` — Access key ID for the s3-user
- `secret_access_key` — Secret access key (sensitive)
- `role_arn` — ARN of the S3AccessRole for assuming the role with MFA
- `bucket_name` — Created S3 bucket name (`bucket_name-account_id`)
- `bucket_arn` — Created S3 bucket ARN

## Variables

- `user_name` — IAM user name (default: `s3-user`)
- `bucket_name` — Base name of the S3 bucket (default: `00-personal`)

AWS account ID is derived internally via `aws_caller_identity` and is used to build the final bucket name: `bucket_name-account_id`.

## AWS CLI Configuration

After MFA setup, configure AWS CLI in `~/.aws/config`:

```ini
[profile s3-user-mfa]
region = eu-central-1
mfa_serial = arn:aws:iam::ACCOUNT_ID:mfa/s3-user-mfa
role_arn = arn:aws:iam::ACCOUNT_ID:role/S3AccessRole-generic-storage-s3-user
source_profile = s3-user

[profile s3-user]
region = eu-central-1
aws_access_key_id = YOUR_ACCESS_KEY
aws_secret_access_key = YOUR_SECRET_KEY
```

**Why two profiles?** `s3-user` stores the long-term IAM credentials. `s3-user-mfa` contains the role assumption + MFA config and references `s3-user` via `source_profile`. This separation lets AWS CLI automatically handle the STS `AssumeRole` call with MFA each time the session token expires, without re-entering the static credentials. It also allows granting access to multiple roles (for example, read-only vs. full access) from the same base profile.

### Using the Profile

```bash
# S3 access (MFA required)
export AWS_PROFILE=s3-user-mfa
aws sts get-caller-identity    # Will prompt for MFA code
aws s3 ls s3://00-personal-$(aws sts get-caller-identity --query Account --output text)
```

### Automatic MFA with AWS CLI

For seamless MFA with AWS CLI, consider using tools like:
- [aws-vault](https://github.com/99designs/aws-vault) — MFA-aware credential management
- [granted](https://docs.commonfate.io/granted) — Terminal access management with MFA
- [aws-mfa](https://github.com/aws-solutions/aws-mfa) — MFA session management

## Costs

The generic-storage module creates:
- 1 IAM user: **free**
- 1 Access key: **free**
- 1 IAM policy: **free**
- 1 IAM role: **free**
- 1 MFA device (virtual): **free**

**Total cost: ~$0/month** (after MFA setup)

## Related Modules

- [obsidian-vaults](../obsidian-vaults) — S3 storage for Obsidian vaults (similar pattern)
- [generic-storage](.) — This module

## References

- [AWS MFA Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_mfa.html)
- [Virtual MFA Devices](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_mfa_virtual.html)
- [AWS STS AssumeRole](https://docs.aws.amazon.com/STS/latest/APIReference/API_AssumeRole.html)
