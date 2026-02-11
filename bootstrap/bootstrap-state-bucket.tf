################################################################################
# S3 Bucket for Bootstrap State Backup
################################################################################

resource "aws_s3_bucket" "bootstrap_state" {
  bucket = "${local.name_prefix}-bootstrap-tfstate-${local.account_id}"

  lifecycle {
    prevent_destroy = true
  }

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-bootstrap-tfstate"
    Purpose = "Backup storage for bootstrap terraform.tfstate"
  })
}

resource "aws_s3_bucket_versioning" "bootstrap_state" {
  bucket = aws_s3_bucket.bootstrap_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "bootstrap_state" {
  bucket = aws_s3_bucket.bootstrap_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "bootstrap_state" {
  bucket = aws_s3_bucket.bootstrap_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "bootstrap_state" {
  bucket = aws_s3_bucket.bootstrap_state.id

  rule {
    id     = "DeleteOldVersions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}
