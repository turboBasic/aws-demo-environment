# Static Site Module

Complete S3 and CloudFront infrastructure for serving static and dynamic content with path-based routing.

## Features

- S3 bucket for static content with versioning and encryption
- CloudFront Origin Access Control (OAC) for secure S3 access
- Path-based routing: `/static/*` → S3, `/` → ALB
- HTTPS-only with SNI certificate support
- Configurable cache policies per origin
- Geographic restrictions (optional)
- Origin verification via custom X-Origin-Verify header
- Optimized for low cost (PriceClass_100 by default)

## Architecture

```plaintext
Internet / DNS
     │
     ▼
Cloudflare (DNS/DDoS)
     │
     ▼
CloudFront CDN
(Path-based routing)
     │
     ├─► /static/* ──► S3 Bucket (OAC)
     │               ├─ Versioning enabled
     │               ├─ Server-side encryption
     │               └─ Lifecycle: delete old versions
     │
     └─► /*  (default) ──► ALB (with header validation)
                           └─ X-Origin-Verify header check
                           └─ EC2 instance (dynamic content)
```

## Usage

```hcl
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

module "static_site" {
  source = "./modules/static-site"

  domain_name                          = var.domain_name
  alb_dns_name                         = module.application_load_balancer.alb_dns_name
  cloudfront_certificate_arn           = aws_acm_certificate_validation.cloudfront.certificate_arn
  account_id                           = data.aws_caller_identity.current.account_id
  name_prefix                          = local.name_prefix

  cache_policy_disabled_id             = data.aws_cloudfront_cache_policy.caching_disabled.id
  origin_request_policy_all_viewer_id  = data.aws_cloudfront_origin_request_policy.all_viewer.id
  cache_policy_optimized_id            = data.aws_cloudfront_cache_policy.caching_optimized.id
  origin_request_policy_cors_s3_id     = data.aws_cloudfront_origin_request_policy.cors_s3.id

  tags = local.common_tags
}
```

## Inputs

| Name | Description | Type | Required |
| ---- | ----------- | ---- | -------- |
| domain_name | Domain name for CloudFront alias | string | yes |
| alb_dns_name | ALB DNS name for dynamic origin | string | yes |
| cloudfront_certificate_arn | ACM certificate ARN (us-east-1) | string | yes |
| account_id | AWS account ID for S3 bucket naming | string | yes |
| name_prefix | Prefix for resource names | string | yes |
| price_class | CloudFront price class | string | no (default: PriceClass_100) |
| cache_policy_disabled_id | Cache policy ID for ALB origin | string | yes |
| origin_request_policy_all_viewer_id | Origin request policy ID for ALB | string | yes |
| cache_policy_optimized_id | Cache policy ID for S3 origin | string | yes |
| origin_request_policy_cors_s3_id | Origin request policy ID for S3 | string | yes |
| tags | Common tags for all resources | map(string) | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| s3_bucket_id | S3 bucket name |
| s3_bucket_arn | S3 bucket ARN |
| cloudfront_distribution_id | CloudFront distribution ID |
| cloudfront_domain_name | CloudFront distribution domain name |
| cloudfront_distribution_arn | CloudFront distribution ARN |
| origin_verify_header | Custom header value for ALB verification |

## Resources Created

- 1 S3 Bucket with versioning, encryption, public access block
- 1 S3 Bucket Lifecycle Configuration
- 1 CloudFront Origin Access Control
- 1 CloudFront Distribution with 2 origins and 2 cache behaviors
- 1 S3 Bucket Policy for CloudFront OAC
- 1 Random password for origin verification

## Routing Logic

### Path `/static/*` → S3

- **Cache Policy:** Managed-CachingOptimized
- **Origin Request Policy:** Managed-CORS-S3Origin
- **TTL:** Longer (hours to days)
- **Methods:** GET, HEAD only
- **Use Case:** Static assets (images, CSS, JS, fonts)

### Path `/` (default) → ALB

- **Cache Policy:** Managed-CachingDisabled
- **Origin Request Policy:** Managed-AllViewer
- **TTL:** Minimal (revalidate immediately)
- **Methods:** All (GET, HEAD, OPTIONS, PUT, POST, PATCH, DELETE)
- **Validation:** X-Origin-Verify header required
- **Use Case:** Dynamic content, API endpoints

## Security Considerations

1. **S3 Private Access**: S3 bucket is not publicly accessible, only via CloudFront
2. **OAC Security**: CloudFront uses SigV4-signed requests to S3
3. **ALB Header Validation**: DirectAccess to ALB blocked without valid header
4. **HTTPS Enforcement**: All traffic redirected to HTTPS
5. **SSL/TLS**: TLSv1.2 minimum protocol version
6. **SNI Only**: Certificate served via SNI (no dedicated IP)

## Cost Optimization

**PriceClass_100** (default):

- US, Canada, Europe
- ~$0.085/GB outbound
- Lowest cost tier suitable for global audience targeting Americas/Europe

**Price Class Options:**

- `PriceClass_100` - Lowest cost (default)
- `PriceClass_200` - Medium cost, adds Asia/Pacific
- `PriceClass_All` - Highest cost, all edge locations

## Static Content Upload

Upload static files to S3 at path `/static`:

```bash
aws s3 sync ./assets/static/ \
  s3://ade-dev-static-381492075850/static/ \
  --delete \
  --profile cargonautica

# Invalidate CloudFront distribution cache
aws cloudfront create-invalidation --distribution-id "$(terraform output -raw cloudfront_distribution_id)" --paths "/*"
```

## Cache Invalidation

When updating static files:

```bash
# Invalidate CloudFront cache
aws cloudfront create-invalidation \
  --distribution-id E1E23QKYQBHFUB \
  --paths "/*" \
  --profile cargonautica
```

## Monitoring

Monitor CloudFront metrics via CloudWatch:

- Requests and bytes served
- Cache hit ratio
- Origin response time
- 4xx/5xx error rates

## Notes

- S3 bucket name includes account ID to ensure global uniqueness
- CloudFront certificate must be in us-east-1 region
- Origin verification header is strong random (32 chars, no special)
- S3 versioning allows rollback of static content changes
- Lifecycle rule purges old versions after 30 days
