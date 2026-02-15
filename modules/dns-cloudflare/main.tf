################################################################################
# Cloudflare Provider Configuration
################################################################################

terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5"
    }
  }
}

################################################################################
# ACM Certificate Validation DNS Record
################################################################################

# DNS record for ACM certificate validation (CNAME record for domain validation)
resource "cloudflare_dns_record" "acm_validation" {
  zone_id = var.cloudflare_zone_id
  name    = var.acm_validation_record_name
  content = var.acm_validation_record_value
  type    = var.acm_validation_record_type
  ttl     = 1
  proxied = false # CRITICAL: Must be gray cloud (unproxied) for DNS validation
}

################################################################################
# CloudFront Distribution DNS Records (Apex and www)
################################################################################

resource "cloudflare_dns_record" "demo" {
  zone_id = var.cloudflare_zone_id
  name    = var.domain_name
  content = var.cloudfront_domain_name
  type    = "CNAME"
  ttl     = 1
  proxied = true # orange cloud, Cloudflare proxy

  depends_on = [cloudflare_zone_setting.ssl]
}

resource "cloudflare_dns_record" "www" {
  zone_id = var.cloudflare_zone_id
  name    = "www.${var.domain_name}"
  content = var.cloudfront_domain_name
  type    = "CNAME"
  ttl     = 1
  proxied = true # must be proxied for redirect rules to work

  depends_on = [cloudflare_zone_setting.ssl]
}

################################################################################
# Cloudflare Zone Settings
################################################################################

resource "cloudflare_zone_setting" "ssl" {
  zone_id    = var.cloudflare_zone_id
  setting_id = "ssl"
  value      = "strict"
}

################################################################################
# Cloudflare Redirect Rules
################################################################################

# In order to allow editing rulesets, the Cloudflare API token must have the following permissions:
# Account - Account Rulesets: Edit
# Zone - Single Redirect: Edit, Zone Settings: Edit, DNS: Edit
resource "cloudflare_ruleset" "redirect_www" {
  zone_id     = var.cloudflare_zone_id
  name        = "Redirect www to apex"
  description = "Redirect www.domain.com to domain.com"
  kind        = "zone"
  phase       = "http_request_dynamic_redirect"

  rules = [{
    ref         = "redirect_www_to_apex"
    action      = "redirect"
    expression  = "(http.host eq \"www.${var.domain_name}\")"
    description = "Redirect www to apex"

    action_parameters = {
      from_value = {
        status_code           = 301
        preserve_query_string = true

        target_url = {
          value = "https://${var.domain_name}/"
        }
      }
    }
  }]
}
