# Bootstrap Terraform Infrastructure

Complete guide for bootstrapping the AWS demo environment infrastructure and managing the bootstrap state.

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.14 installed

## Step 1: Create S3 Bucket for Bootstrap State (Optional but Recommended)

The bootstrap module uses local backend by default. For better state management, create a separate S3 bucket to store the bootstrap state:

```bash
# Set variables
BUCKET_NAME="aws-demo-bootstrap-state-$(aws sts get-caller-identity --query Account --output text)"
AWS_REGION="eu-central-1"  # Change to your preferred region

# Create the bucket
aws s3api create-bucket \
  --bucket "$BUCKET_NAME" \
  --region "$AWS_REGION" \
  --create-bucket-configuration LocationConstraint="$AWS_REGION"

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket "$BUCKET_NAME" \
  --versioning-configuration Status=Enabled

# Enable default encryption (AES256)
aws s3api put-bucket-encryption \
  --bucket "$BUCKET_NAME" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      },
      "BucketKeyEnabled": true
    }]
  }'

# Block all public access
aws s3api put-public-access-block \
  --bucket "$BUCKET_NAME" \
  --public-access-block-configuration \
    BlockPublicAcls=true,\
IgnorePublicAcls=true,\
BlockPublicPolicy=true,\
RestrictPublicBuckets=true

# Optional: Enable lifecycle to retain old versions
aws s3api put-bucket-lifecycle-configuration \
  --bucket "$BUCKET_NAME" \
  --lifecycle-configuration '{
    "Rules": [{
      "ID": "DeleteOldVersions",
      "Status": "Enabled",
      "Filter": {
        "Prefix": ""
      },
      "NoncurrentVersionExpiration": {
        "NoncurrentDays": 90
      }
    }]
  }'

# Verify configuration
echo "✅ Bucket created: $BUCKET_NAME"
aws s3api get-bucket-versioning --bucket "$BUCKET_NAME"
aws s3api get-bucket-encryption --bucket "$BUCKET_NAME"
aws s3api get-public-access-block --bucket "$BUCKET_NAME"
```

### One-liner version

```bash
BUCKET_NAME="aws-demo-bootstrap-state-$(aws sts get-caller-identity --query Account --output text)" && \
aws s3api create-bucket --bucket "$BUCKET_NAME" --region us-east-1 && \
aws s3api put-bucket-versioning --bucket "$BUCKET_NAME" --versioning-configuration Status=Enabled && \
aws s3api put-bucket-encryption --bucket "$BUCKET_NAME" --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"},"BucketKeyEnabled":true}]}' && \
aws s3api put-public-access-block --bucket "$BUCKET_NAME" --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true && \
echo "✅ Bucket created: $BUCKET_NAME"
```

## Step 2: Configure Bootstrap Variables

Copy the example variables file and customize:

```bash
cd bootstrap
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values:

```hcl
aws_region  = "eu-central-1"
ttl_minutes = 1440  # Time-to-live for demo environment (1440 minutes = 24 hours)
```

## Step 3: Initialize and Apply Bootstrap

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the bootstrap configuration
terraform apply
```

This creates:

- S3 bucket for demo environment state
- DynamoDB table for state locking
- Lambda function (destroyer) with EventBridge schedule
- IAM roles and policies

## Step 4: Back Up Bootstrap State to S3

After successful bootstrap apply:

```bash
# Upload state to the backup bucket
aws s3 cp terraform.tfstate s3://$BUCKET_NAME/terraform.tfstate

# Verify upload
aws s3 ls s3://$BUCKET_NAME/

# Optional: Create a timestamped backup locally
cp terraform.tfstate terraform.tfstate.backup-$(date +%Y%m%d-%H%M%S)
```

**Important:** The bootstrap state file remains in `bootstrap/terraform.tfstate` locally. The S3 copy is a backup only. Bootstrap uses local backend, not S3 backend.

## Step 5: Capture Backend Configuration

Get the backend configuration for the root module:

```bash
terraform output -json backend_config
```

Example output:

```json
{
  "bucket": "aws-demo-tfstate-123456789012-us-east-1",
  "dynamodb_table": "aws-demo-tfstate-locks",
  "encrypt": true,
  "key": "demo-environment/terraform.tfstate",
  "region": "eu-central-1"
}
```

## Step 6: Configure Root Module Backend

Navigate to the root directory and edit `backend.tf`:

```bash
cd ..  # Return to project root
```

Edit [backend.tf](../backend.tf) with values from bootstrap output:

```hcl
terraform {
  backend "s3" {
    bucket         = "aws-demo-tfstate-123456789012-eu-central-1"  # From output
    key            = "demo-environment/terraform.tfstate"
    region         = "eu-central-1"  # From output
    dynamodb_table = "aws-demo-tfstate-locks"  # From output
    encrypt        = true
  }
}
```

## Step 7: Deploy Demo Environment

```bash
# Initialize with the S3 backend
terraform init

# Review the plan
terraform plan

# Deploy the demo environment
terraform apply
```

This will create resources described in the Root Module.

## Step 8: Verify Deployment

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
- **Backup:** S3 bucket `aws-demo-bootstrap-state-<account-id>`
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
aws s3 cp s3://$BUCKET_NAME/terraform.tfstate terraform.tfstate

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
# First, destroy demo environment if it exists
cd aws-demo-environment
terraform destroy

# Then destroy bootstrap
cd bootstrap
terraform destroy

# Optionally, delete the bootstrap state backup bucket
aws s3 rb s3://$BUCKET_NAME --force
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
aws dynamodb scan --table-name aws-demo-tfstate-locks

# Force unlock (use Lock ID from error message)
terraform force-unlock <lock-id>
```

### Bootstrap state out of sync

If you lose local bootstrap state but resources exist:

```bash
# Option 1: Restore from S3 backup
aws s3 cp s3://$BUCKET_NAME/terraform.tfstate bootstrap/terraform.tfstate

# Option 2: Import resources manually
terraform import aws_s3_bucket.tfstate aws-demo-tfstate-<account-id>-<region>
# ... repeat for other resources
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
