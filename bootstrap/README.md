# Bootstrap Terraform Infrastructure

Complete guide for bootstrapping the AWS demo environment infrastructure and managing the bootstrap state.

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.14 installed

## Step 1: Configure Bootstrap Variables

Copy the example variables file and customize:

```bash
cd bootstrap
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values:

```hcl
environment  = "dev"
project_name = "ade"
aws_region   = "eu-central-1"
ttl_minutes  = 1440  # Time-to-live for demo environment (1440 minutes = 24 hours)
```

## Step 2: Initialize and Apply Bootstrap

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the bootstrap configuration
terraform apply
```

This creates:

- S3 bucket for demo environment state (used by root module)
- S3 bucket for bootstrap state backup
- DynamoDB table for state locking
- Lambda function (destroyer) with EventBridge schedule
- IAM roles and policies

## Step 3: Back Up Bootstrap State to S3

After successful bootstrap apply, backup the local state file to the S3 bucket that was just created:

```bash
# Get the backup command from terraform output
terraform output -raw bootstrap_state_backup_commands

# Or run the upload command directly
terraform output -json bootstrap_state_backup_commands | jq -r '.upload'

# Execute the command (example)
aws s3 cp terraform.tfstate s3://ade-dev-bootstrap-tfstate-<account-id>/terraform.tfstate

# Verify upload
aws s3 ls s3://ade-dev-bootstrap-tfstate-<account-id>/
```

**Important:** The bootstrap state file remains in `bootstrap/terraform.tfstate` locally. The S3 copy is a backup only. Bootstrap uses local backend, not S3 backend.

## Step 4: Capture Backend Configuration

Get the backend configuration for the root module:

```bash
terraform output -json backend_config
```

Example output:

```json
{
  "bucket": "ade-dev-tfstate-123456789012",
  "dynamodb_table": "ade-dev-tflock",
  "encrypt": true,
  "key": "ade/terraform.tfstate",
  "region": "eu-central-1"
}
```

## Step 5: Configure Root Module Backend

Navigate to the root directory and edit `backend.tf`:

```bash
cd ..  # Return to project root
```

Edit [backend.tf](../backend.tf) with values from bootstrap output:

```hcl
terraform {
  backend "s3" {
    bucket         = "ade-dev-tfstate-123456789012"   # From output of previous step
    key            = "ade/terraform.tfstate"          # From output of previous step
    region         = "eu-central-1"                   # From output of previous step
    dynamodb_table = "ade-dev-tflock"                 # From output of previous step
    encrypt        = true
  }
}
```

## Step 6: Deploy Demo Environment

```bash
# Initialize with the S3 backend
terraform init

# Review the plan
terraform plan

# Deploy the demo environment
terraform apply
```

This will create resources described in the Root Module.

## Step 7: Verify Deployment

```bash
# Get the ALB DNS name
terraform output alb_dns_name

# Test the endpoint (wait 2-3 minutes for health checks)
curl http://$(terraform output -raw alb_dns_name)
```

Expected response: Demo HTML page from EC2 instance.

## State Management Summary

### Bootstrap State (Local Backend)

- **Location:** `bootstrap/terraform.tfstate` (local file)
- **Backup:** S3 bucket `ade-dev-bootstrap-tfstate-<account-id>`
- **Managed:** Manually (rarely changes)
- **Purpose:** Persistent infrastructure (state backend, Lambda, etc.)

### Demo Environment State (S3 Backend)

- **Location:** S3 bucket created by bootstrap
- **Locking:** DynamoDB table created by bootstrap
- **Managed:** Automatically by Terraform
- **Purpose:** Ephemeral demo resources (VPC, ALB, EC2)
- **Lifecycle:** Auto-destroyed by Lambda after 24h

## Retrieving Bootstrap State from S3

If you need to restore bootstrap state from backup:

```bash
cd bootstrap

# Get the download command from outputs (if you still have state)
terraform output -json bootstrap_state_backup_commands | jq -r '.download'

# Or use the bucket name directly
BUCKET_NAME=$(terraform output -raw bootstrap_state_bucket_name)
aws s3 cp s3://$BUCKET_NAME/terraform.tfstate terraform.tfstate

# Or if you know the bucket name
aws s3 cp s3://ade-dev-bootstrap-tfstate-<account-id>/terraform.tfstate terraform.tfstate

# Verify state
terraform show
```

## Destroying Resources

### Destroy demo environment only

```bash
# From project root
terraform destroy
```

This destroys VPC, ALB, EC2, but leaves bootstrap infrastructure intact.

### Destroy bootstrap (cleanup everything)

**Warning:** This destroys the state backend and Lambda destroyer. Only do this when completely done with the project.

```bash
# First, destroy main environment if it exists
cd aws-demo-environment
terraform destroy

# Then destroy bootstrap (includes the bootstrap state bucket)
cd bootstrap
terraform destroy
```

## Troubleshooting

### Lambda not destroying demo environment

Check Lambda logs:

```bash
aws logs tail /aws/lambda/aws-demo-destroyer --follow
```

### State locking issues

If state is locked from a failed operation:

```bash
# List locks
aws dynamodb scan --table-name ade-dev-tflock

# Force unlock (use Lock ID from error message)
terraform force-unlock <lock-id>
```

### Bootstrap state out of sync

If you lose local bootstrap state but resources exist:

```bash
# Option 1: Restore from S3 backup
cd bootstrap
BUCKET_NAME="ade-dev-bootstrap-tfstate-<account-id>"  # Replace with your account ID
aws s3 cp s3://$BUCKET_NAME/terraform.tfstate terraform.tfstate

# Option 2: Import resources manually
terraform import aws_s3_bucket.terraform_state ade-dev-tfstate-<account-id>
terraform import aws_s3_bucket.bootstrap_state ade-dev-bootstrap-tfstate-<account-id>
terraform import aws_dynamodb_table.terraform_locks ade-dev-tflock
terraform import aws_lambda_function.destroyer aws-demo-demo-destroyer
# ... repeat for other resources as needed
```

## Security Notes

- Bootstrap state file contains sensitive data (resource IDs, configs)
- Never commit `terraform.tfstate` to git (already in `.gitignore`)
- S3 state bucket has encryption and versioning enabled
- Bootstrap state backup bucket blocks all public access

## References

- [Bootstrap implementation plan](/.claude/plans/04-02-implement-bootstrap-module.md)
- [Lambda destroyer implementation](/.claude/plans/04-03-implement-lambda-destroyer.md)
- [Root module implementation](/.claude/plans/04-01-implement-root-module.md)
- [Project documentation](/CLAUDE.md)
