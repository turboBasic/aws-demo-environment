# DNS Cloudflare Module

Manages all Cloudflare DNS records, zone settings, and redirect rules for the application domain.

## Resources Created

- **ACM Certificate Validation DNS Record**: CNAME record for AWS ACM certificate DNS validation
- **Apex Domain CNAME Record**: Routes apex domain to CloudFront distribution with Cloudflare proxy enabled
- **www Subdomain CNAME Record**: Routes www subdomain to CloudFront distribution
- **Cloudflare Zone Settings**: SSL/TLS encryption mode set to Strict
- **Cloudflare Redirect Ruleset**: www → apex 301 redirect (enforced via Cloudflare)

## Module Dependencies

- `cloudflare_zone_id`: Cloudflare Zone ID for the managed domain
- `domain_name`: Primary domain name
- `cloudfront_domain_name`: CloudFront distribution domain name (for DNS CNAME targets)
- `acm_validation_record_*`: ACM certificate validation record details (name, value, type)

## Outputs

- `acm_validation_dns_record_id`: Reference ID for ACM validation record
- `apex_dns_record_id`: Reference ID for apex domain CNAME
- `www_dns_record_id`: Reference ID for www subdomain CNAME
- `zone_setting_ssl_id`: Reference ID for SSL zone setting
- `redirect_ruleset_id`: Reference ID for redirect ruleset

## Cloudflare API Permissions Required

The Cloudflare API token must have these permissions:
- Account: Account Rulesets: Edit
- Zone: Single Redirect: Edit, Zone Settings: Edit, DNS: Edit

## Key Features

- **Gray Cloud Validation**: ACM validation record is unproxied to enable DNS validation
- **Orange Cloud App Records**: Application DNS records are proxied through Cloudflare
- **Automatic Redirect**: www subdomain redirects to apex via Cloudflare ruleset (301)
- **Strict SSL**: Zone uses Strict SSL/TLS mode for end-to-end encryption
