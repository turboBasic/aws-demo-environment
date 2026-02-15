# SSL Certificates Module

Manages ACM SSL certificates for regional and CloudFront distributions.

## Resources Created

- **ACM Certificates**: Regional (eu-central-1) and CloudFront (us-east-1)
- **Certificate Validation**: DNS validation for both certificates
- **Validation Record Values**: Exported for consumption by dns-cloudflare module

## Module Dependencies

- `domain_name`: For certificate domain configuration

## Outputs

- `regional_certificate_arn`: For ALB HTTPS listeners
- `cloudfront_certificate_arn`: For CloudFront distribution
- `regional_validation_id`: Validation ID for regional certificate
- `cloudfront_validation_id`: Validation ID for CloudFront certificate
- `acm_validation_record_*`: Validation record details (name, value, type) for dns-cloudflare

## Notes

- Both regional and CloudFront certificates validate with the same DNS record
- Validation record details are exported to `dns-cloudflare` module for actual DNS record creation
- Validation filters to base domain only (excludes wildcard *.domain)

