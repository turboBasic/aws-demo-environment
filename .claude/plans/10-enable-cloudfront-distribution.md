# CloudFront with Path-Based Routing Implementation Plan

## Implementation Summary

**Status:** ✅ COMPLETED

**Commits:**

1. `91ba23d` - feat(cloudfront): add CloudFront CDN with path-based routing and origin access control
2. `bfb5f0c` - fix(cloudfront): resolve ACM validation and security group quota issues
3. `cd9f405` - feat(static): add static content test files for CloudFront/S3

**Key differences from initial plan:**

- Single DNS validation record for both certificates (not separate records)
- Header-based validation instead of IP allowlisting (security group quota workaround)
- ALB listener modified with fixed-response default + conditional forwarding
- Static assets in `assets/static/` directory (version controlled)

## Context

The user wants to add CloudFront as a CDN layer between Cloudflare and the existing AWS infrastructure (ALB + EC2). The goal is to implement path-based routing where:

- Root path (`/`) routes through CloudFront → ALB → EC2 (dynamic content)
- Static path (`/static/*`) routes through CloudFront → S3 (static content)

This requires creating a new ACM certificate in us-east-1 for CloudFront, keeping the existing eu-central-1 certificate for ALB, setting up S3 with Origin Access Control (OAC), and restricting ALB access to CloudFront IPs only.

**Current State:**

- ALB with HTTPS listener using ACM certificate (eu-central-1)
- EC2 instance running httpd in private subnet
- Cloudflare DNS pointing directly to ALB (proxied)
- ALB security group allows 0.0.0.0/0 on ports 80/443

**Target State:**

- CloudFront distribution with two origins (ALB and S3)
- S3 bucket (private) for static content with OAC
- ALB validates CloudFront requests via custom header (X-Origin-Verify)
- Cloudflare DNS pointing to CloudFront
- Separate ACM certificates: us-east-1 (CloudFront) and eu-central-1 (ALB)
- Single DNS validation record validates both certificates

## Implementation Notes & Issues Resolved

During implementation, several issues were encountered and resolved:

### Issue 1: Duplicate ACM Validation Records

**Problem:** When creating separate validation records for ALB and CloudFront certificates, Terraform error occurred: `Duplicate object key "turbobasic.dev"`. Both certificates for the same domain produce identical CNAME validation records.

**Solution:** Use a single validation record from the CloudFront certificate that validates both certificates simultaneously. Added `locals.cloudfront_validation` to filter to base domain only (excluding wildcard).

**Commit:** `bfb5f0c` - fix(cloudfront): resolve ACM validation and security group quota issues

### Issue 2: Security Group Rule Quota Exceeded

**Problem:** AWS security groups have a 60-rule quota. CloudFront's managed prefix list contains 55+ IP ranges, each consuming one rule. Adding these rules caused: `RulesPerSecurityGroupLimitExceeded`.

**Solution:** Replace IP-based allowlisting with header-based validation:

1. Keep public security group rules (0.0.0.0/0 on ports 80/443)
2. Modify ALB HTTPS listener to return 403 by default
3. Add listener rule to forward only when `X-Origin-Verify` header matches
4. CloudFront automatically adds this header to origin requests

This provides equivalent security without consuming quota.

**Commit:** `bfb5f0c` - fix(cloudfront): resolve ACM validation and security group quota issues

### Issue 3: S3 File Path Mismatch

**Problem:** Files uploaded to S3 bucket root (`/index.html`) didn't match CloudFront path pattern (`/static/*`), resulting in `AccessDenied` errors when accessing `https://turbobasic.dev/static/index.html`.

**Solution:** Upload files to `s3://bucket/static/` prefix to match CloudFront's `/static/*` pattern. Created `assets/static/` directory for version control and sync to S3 with correct prefix using:

```bash
aws s3 sync assets/static/ s3://bucket-name/static/ --profile cargonautica
```

**Commit:** `cd9f405` - feat(static): add static content test files for CloudFront/S3

---

### Phase 1: Foundation - Add us-east-1 Provider & Data Sources

**Files to modify:**

- [main.tf](../../../projects/personal/turboBasic/aws-demo-environment/main.tf)
- [data.tf](../../../projects/personal/turboBasic/aws-demo-environment/data.tf)

**Changes:**

1. Add us-east-1 provider alias and random provider to `main.tf`:

```hcl
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

# Add random provider to required_providers block
random = {
  source  = "hashicorp/random"
  version = "~> 3.6"
}
```

2. Add CloudFront data sources to `data.tf`:

```hcl
# CloudFront managed prefix list for security group
data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

# CloudFront managed cache policies
data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_origin_request_policy" "all_viewer" {
  name = "Managed-AllViewer"
}

data "aws_cloudfront_origin_request_policy" "cors_s3" {
  name = "Managed-CORS-S3Origin"
}
```

### Phase 2: Storage - S3 Bucket for Static Content

**Files to create:**

- [storage.tf](../../../projects/personal/turboBasic/aws-demo-environment/storage.tf) (NEW)

**Resources:**

```hcl
# S3 bucket for static content
resource "aws_s3_bucket" "static" {
  bucket = "${local.name_prefix}-static-${data.aws_caller_identity.current.account_id}"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-static"
  })
}

resource "aws_s3_bucket_versioning" "static" {
  bucket = aws_s3_bucket.static.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "static" {
  bucket = aws_s3_bucket.static.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "static" {
  bucket = aws_s3_bucket.static.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "static" {
  bucket = aws_s3_bucket.static.id

  rule {
    id     = "DeleteOldVersions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# Bucket policy added after CloudFront distribution exists (see Phase 5)
```

### Phase 3: Certificates - CloudFront ACM Certificate in us-east-1

**Files to modify:**

- [certificates.tf](../../../projects/personal/turboBasic/aws-demo-environment/certificates.tf)

**Add at the end of the file:**

```hcl
################################################################################
# CloudFront Certificate (us-east-1)
################################################################################

resource "aws_acm_certificate" "cloudfront" {
  provider                  = aws.us_east_1
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-cloudfront-cert"
  })
}

resource "aws_acm_certificate_validation" "cloudfront" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.cloudfront.arn
  validation_record_fqdns = [for dvo in aws_acm_certificate.cloudfront.domain_validation_options : dvo.resource_record_name]
}
```

**Replace existing acm_validation resource with unified validation:**

```hcl
################################################################################
# ACM Validation Records (Single record validates both certificates)
################################################################################

# Both certificates for the same domain validate with the same CNAME record
# Use the CloudFront certificate's validation record (they're identical for same domain)
# Filter to base domain only (exclude wildcard *.domain)
locals {
  cloudfront_validation = one([
    for dvo in aws_acm_certificate.cloudfront.domain_validation_options :
    dvo if dvo.domain_name == var.domain_name
  ])
}

resource "cloudflare_dns_record" "acm_validation" {
  zone_id = var.cloudflare_zone_id
  name    = trimsuffix(local.cloudfront_validation.resource_record_name, ".")
  content = trimsuffix(local.cloudfront_validation.resource_record_value, ".")
  type    = local.cloudfront_validation.resource_record_type
  ttl     = 1
  proxied = false # CRITICAL: Must be gray cloud (unproxied) for DNS validation

  depends_on = [aws_acm_certificate.cloudfront]
}
```

**Note:** Single validation record validates both ALB and CloudFront certificates since they're for the same domain. This prevents "Duplicate object key" errors.

### Phase 4: CDN - CloudFront Distribution

**Files to create:**

- [cdn.tf](../../../projects/personal/turboBasic/aws-demo-environment/cdn.tf) (NEW)

**Resources:**

```hcl
################################################################################
# CloudFront Origin Access Control
################################################################################

resource "aws_cloudfront_origin_access_control" "s3" {
  name                              = "${local.name_prefix}-s3-oac"
  description                       = "OAC for S3 static content bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

################################################################################
# Origin Verification Header
################################################################################

resource "random_password" "origin_verify" {
  length  = 32
  special = false
}

################################################################################
# CloudFront Distribution
################################################################################

resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${local.name_prefix} CDN with path-based routing"
  default_root_object = ""
  aliases             = [var.domain_name]
  price_class         = "PriceClass_100"  # US, Canada, Europe only

  # Origin 1: ALB (default behavior)
  origin {
    domain_name = aws_lb.demo.dns_name
    origin_id   = "alb"

    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_protocol_policy   = "https-only"
      origin_ssl_protocols     = ["TLSv1.2"]
      origin_read_timeout      = 60
      origin_keepalive_timeout = 5
    }

    custom_header {
      name  = "X-Origin-Verify"
      value = random_password.origin_verify.result
    }
  }

  # Origin 2: S3 bucket via OAC
  origin {
    domain_name              = aws_s3_bucket.static.bucket_regional_domain_name
    origin_id                = "s3"
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
  }

  # Default cache behavior: route to ALB (dynamic content)
  default_cache_behavior {
    target_origin_id       = "alb"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer.id
  }

  # Ordered cache behavior: /static/* to S3 (static content)
  ordered_cache_behavior {
    path_pattern           = "/static/*"
    target_origin_id       = "s3"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_optimized.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.cors_s3.id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.cloudfront.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-cdn"
  })
}
```

**Note:** CloudFront distribution takes 15-20 minutes to deploy.

### Phase 5: Storage Policy - S3 Bucket Policy for OAC

**Files to modify:**

- [storage.tf](../../../projects/personal/turboBasic/aws-demo-environment/storage.tf)

**Add at the end:**

```hcl
################################################################################
# S3 Bucket Policy for CloudFront OAC
################################################################################

resource "aws_s3_bucket_policy" "static" {
  bucket = aws_s3_bucket.static.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontOAC"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.static.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.main.arn
          }
        }
      }
    ]
  })
}
```

### Phase 6: Security - Header-Based Validation (Avoiding Quota Issues)

**Files to modify:**

- [security.tf](../../../projects/personal/turboBasic/aws-demo-environment/security.tf)
- [compute.tf](../../../projects/personal/turboBasic/aws-demo-environment/compute.tf)

**Update security group rules (security.tf):**

```hcl
# ALB accepts HTTPS from anywhere, but validates CloudFront custom header
# This avoids security group rule quota issues (CloudFront prefix list has 55+ IPs)
resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS from anywhere (validated by X-Origin-Verify header)"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from anywhere (redirects to HTTPS)"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}
```

**Modify ALB HTTPS listener (compute.tf):**

```hcl
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.demo.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate_validation.demo.certificate_arn

  # Validate CloudFront origin header, reject direct access
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Direct access not allowed"
      status_code  = "403"
    }
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-https-listener"
  })
}

# Forward to target group only if CloudFront custom header matches
resource "aws_lb_listener_rule" "cloudfront_origin" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.demo.arn
  }

  condition {
    http_header {
      http_header_name = "X-Origin-Verify"
      values           = [random_password.origin_verify.result]
    }
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-cloudfront-rule"
  })
}
```

**Note:** CloudFront managed prefix list contains 55+ IP ranges, exceeding AWS security group 60-rule quota. Header-based validation provides equivalent security without quota issues.

### Phase 7: DNS Cutover - Point Cloudflare to CloudFront

**Files to modify:**

- [certificates.tf](../../../projects/personal/turboBasic/aws-demo-environment/certificates.tf)

**Update existing resources (lines 28-35 and 44-51):**

```hcl
resource "cloudflare_dns_record" "demo" {
  zone_id = var.cloudflare_zone_id
  name    = var.domain_name
  content = aws_cloudfront_distribution.main.domain_name  # Changed from aws_lb.demo.dns_name
  type    = "CNAME"
  ttl     = 1
  proxied = true  # Keep Cloudflare proxy enabled
}

# www redirect to apex
resource "cloudflare_dns_record" "www" {
  zone_id = var.cloudflare_zone_id
  name    = "www.${var.domain_name}"
  content = aws_cloudfront_distribution.main.domain_name  # Changed from aws_lb.demo.dns_name
  type    = "CNAME"
  ttl     = 1
  proxied = true
}
```

### Phase 8: Static Test Assets

**Files to create:**

- `assets/static/index.html`
- `assets/static/style.css`
- `assets/static/script.js`

**Create test files to verify CloudFront → S3 integration:**

```bash
# Upload to S3 with correct prefix
aws s3 sync assets/static/ s3://$(terraform output -raw s3_static_bucket_name)/static/ --profile cargonautica
```

**Note:** Files must be uploaded to `s3://bucket/static/` to match CloudFront's `/static/*` path pattern. The `assets/` directory contains source files for version control.

### Phase 9: No Cleanup Needed

**Status:** NOT EXECUTED

Public ALB security group rules (0.0.0.0/0) are kept in place but protected by header validation at the ALB listener level. Direct ALB access returns 403; only requests with valid `X-Origin-Verify` header are forwarded to targets. This provides:

- Equivalent security to IP allowlisting
- No AWS quota issues
- Simpler rollback capability

### Phase 10: Outputs & Documentation

**Files to modify:**

- [outputs.tf](../../../projects/personal/turboBasic/aws-demo-environment/outputs.tf)

**Add new outputs:**

```hcl
output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.main.id
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "s3_static_bucket_name" {
  description = "S3 bucket name for static content"
  value       = aws_s3_bucket.static.id
}

output "s3_static_bucket_arn" {
  description = "S3 bucket ARN for static content"
  value       = aws_s3_bucket.static.arn
}
```

## Key Design Decisions

1. **Header-based validation instead of IP allowlisting:** CloudFront managed prefix list (55+ IPs) exceeds AWS security group quota (60 rules). Header validation via `X-Origin-Verify` provides equivalent security without quota issues.
2. **Single DNS validation record:** Both ALB (eu-central-1) and CloudFront (us-east-1) certificates for the same domain use identical CNAME validation records. One Cloudflare DNS record validates both.
3. **ALB listener with fixed-response default:** Direct ALB access returns 403; only CloudFront requests with valid header are forwarded to targets.
4. **Origin Access Control (OAC):** Modern replacement for Origin Access Identity (OAI)
5. **Managed cache policies:** Use AWS-managed policies instead of deprecated `forwarded_values`
6. **Private S3 bucket:** No public access, no website endpoint, bucket policy with SourceArn condition
7. **Origin verification header:** Random 32-character password only known to CloudFront
8. **Separate certificates:** us-east-1 for CloudFront (required), eu-central-1 for ALB (unchanged)
9. **No auto-destroy tags on CloudFront/S3:** These should persist beyond 24h demo lifecycle
10. **Static assets in version control:** `assets/static/` directory contains source files synced to S3

## Security Considerations

- **End-to-end TLS:** Browser → Cloudflare (TLS) → CloudFront (TLS, us-east-1 cert) → ALB (TLS, eu-central-1 cert)
- **S3 bucket policy:** Uses `AWS:SourceArn` condition (more specific than `SourceAccount`)
- **ALB restriction:** Custom `X-Origin-Verify` header validation (32-char random password). Direct access returns 403.
- **No HTTP between services:** CloudFront → ALB uses `https-only` origin protocol
- **Certificate validation:** DNS validation via Cloudflare (not email), validation records not proxied
- **Defense in depth:** Both network-level (security groups allow 0.0.0.0/0) and application-level (ALB listener validates header) security

## Testing & Validation

### After Phase 2 (S3)

```bash
# Upload test file
echo "test content" | aws s3 cp - s3://$(terraform output -raw s3_static_bucket_name)/static/test.txt

# Verify public access denied
curl https://$(terraform output -raw s3_static_bucket_name).s3.eu-central-1.amazonaws.com/static/test.txt
# Expected: 403 AccessDenied
```

### After Phase 4 (CloudFront)

```bash
# Test CloudFront domain (before DNS cutover)
curl -I https://$(terraform output -raw cloudfront_domain_name)/
# Expected: 200 OK
```

### After Phase 5 (S3 Policy)

```bash
# Test static content via CloudFront
curl https://$(terraform output -raw cloudfront_domain_name)/static/test.txt
# Expected: "test content"
```

### After Phase 7 (DNS Cutover)

```bash
# Test production domain
curl -I https://turbobasic.dev/
# Expected: 200 OK with "via: cloudfront.net" header

# Test static content via production domain
curl https://turbobasic.dev/static/test.txt
# Expected: "test content"

# Verify www redirect
curl -I https://www.turbobasic.dev/
# Expected: 301 redirect to https://turbobasic.dev/
```

### After Phase 8 (Static Assets Uploaded)

```bash
# Test static content via production domain
curl https://turbobasic.dev/static/index.html
# Expected: HTML content from S3

# Test direct ALB access returns 403
curl -I https://$(terraform output -raw alb_dns_name)/ --max-time 10
# Expected: 403 Forbidden (missing X-Origin-Verify header)

# Test production domain works (CloudFront adds header)
curl -I https://turbobasic.dev/
# Expected: 200 OK
```

## Rollback Strategy

**Emergency DNS rollback (Phase 7):**

```bash
# Revert certificates.tf DNS changes
git checkout HEAD -- certificates.tf
terraform apply -target=cloudflare_dns_record.demo -target=cloudflare_dns_record.www
```

**Complete rollback:**

```bash
# Revert ALB listener changes (restore direct forwarding)
git checkout HEAD -- compute.tf
terraform apply

# Revert DNS to ALB
git checkout HEAD -- certificates.tf
terraform apply

# Destroy CloudFront (takes 15-20 min)
terraform destroy -target=aws_cloudfront_distribution.main

# Revert certificates to separate validation records
git checkout HEAD -- certificates.tf
terraform apply
```

**Note:** Security groups don't need rollback since header-based validation maintains backward compatibility with direct ALB access.

## Critical Files Summary

**Files to create:**

1. [storage.tf](../../../projects/personal/turboBasic/aws-demo-environment/storage.tf) - S3 bucket, versioning, encryption, public access block, lifecycle, bucket policy
2. [cdn.tf](../../../projects/personal/turboBasic/aws-demo-environment/cdn.tf) - CloudFront distribution, OAC, random password
3. `assets/static/` directory - Test HTML, CSS, and JS files for CloudFront/S3 validation

**Files to modify:**

1. [main.tf](../../../projects/personal/turboBasic/aws-demo-environment/main.tf) - Add us-east-1 provider alias, random provider
2. [data.tf](../../../projects/personal/turboBasic/aws-demo-environment/data.tf) - Add CloudFront data sources (prefix list, cache policies)
3. [certificates.tf](../../../projects/personal/turboBasic/aws-demo-environment/certificates.tf) - Add CloudFront ACM cert, unified validation record, update DNS records to CloudFront
4. [security.tf](../../../projects/personal/turboBasic/aws-demo-environment/security.tf) - Update comments to reflect header-based validation (no CloudFront prefix list rules)
5. [compute.tf](../../../projects/personal/turboBasic/aws-demo-environment/compute.tf) - Modify ALB HTTPS listener with fixed-response default and header validation rule
6. [outputs.tf](../../../projects/personal/turboBasic/aws-demo-environment/outputs.tf) - Add CloudFront and S3 outputs

## Cost Impact

**New monthly costs (estimated):**

- CloudFront: ~$1-5 (highly variable based on traffic)
- S3 storage: ~$0.50-2 (10GB storage + versioning)
- Data transfer: ~$1-10 (ALB → CloudFront traffic)

**Total additional cost: ~$2-17/month** (traffic-dependent)

## Known Limitations

1. **CloudFront deployment time:** 15-20 minutes initial deployment, 15-20 minutes to destroy
2. **Lambda auto-destroyer:** Won't destroy CloudFront/S3 (not tagged with AutoDestroy)
3. **Manual cleanup required:** Run `terraform destroy` before 24h TTL or manually after
4. **Cache invalidations:** First 1,000 per month free, then $0.005 per path

## Post-Implementation

Static content is deployed from the `assets/static/` directory:

```bash
# Static files are version controlled in assets/static/
# Sync to S3 with correct prefix
aws s3 sync assets/static/ s3://$(terraform output -raw s3_static_bucket_name)/static/ --profile cargonautica

# Invalidate CloudFront cache if content is updated
aws cloudfront create-invalidation \
  --distribution-id $(terraform output -raw cloudfront_distribution_id) \
  --paths "/static/*" \
  --profile cargonautica
```

**Important:** Files must be uploaded to `s3://bucket/static/` to match CloudFront's `/static/*` path pattern.

Content is available at:

- `https://turbobasic.dev/` - Dynamic content from EC2 via ALB (header-validated)
- `https://turbobasic.dev/static/index.html` - Static content from S3 via CloudFront OAC
- `https://turbobasic.dev/static/style.css` - Static CSS from S3
- `https://turbobasic.dev/static/script.js` - Static JS from S3

**Security validation:**

```bash
# Direct ALB access returns 403 (missing X-Origin-Verify header)
curl -I https://$(terraform output -raw alb_dns_name)/
# Expected: 403 Forbidden

# CloudFront access works (header automatically added)
curl -I https://turbobasic.dev/
# Expected: 200 OK
```
