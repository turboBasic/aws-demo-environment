resource "aws_acm_certificate" "demo" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"
}

resource "aws_acm_certificate_validation" "demo" {
  certificate_arn         = aws_acm_certificate.demo.arn
  validation_record_fqdns = [for dvo in aws_acm_certificate.demo.domain_validation_options : dvo.resource_record_name]
}

# Create Cloudflare CNAMEs for DNS validation
resource "cloudflare_dns_record" "acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.demo.domain_validation_options :
    dvo.domain_name => dvo
    if !startswith(dvo.domain_name, "*.")
  }

  zone_id = var.cloudflare_zone_id
  name    = trimsuffix(each.value.resource_record_name, ".")
  content = trimsuffix(each.value.resource_record_value, ".")
  type    = each.value.resource_record_type
  ttl     = 1
  proxied = false # must be gray cloud for ACM validation
}

resource "cloudflare_dns_record" "demo" {
  zone_id = var.cloudflare_zone_id
  name    = var.domain_name
  content = aws_cloudfront_distribution.main.domain_name
  type    = "CNAME"
  ttl     = 1
  proxied = true # orange cloud, Cloudflare proxy
}

resource "cloudflare_zone_setting" "ssl" {
  zone_id    = var.cloudflare_zone_id
  setting_id = "ssl"
  value      = "strict"
}

# www redirect to apex
resource "cloudflare_dns_record" "www" {
  zone_id = var.cloudflare_zone_id
  name    = "www.${var.domain_name}"
  content = aws_cloudfront_distribution.main.domain_name
  type    = "CNAME"
  ttl     = 1
  proxied = true # must be proxied for redirect rules to work
}

# In order to allow editing rulesets, the Cloudflare API token must have the following permissions:
# Account - Account Rulesets:Edit
# Zone - Single Redirect:Edit, Zone Settings:Edit, DNS:Edit
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

resource "cloudflare_dns_record" "acm_validation_cloudfront" {
  for_each = {
    for dvo in aws_acm_certificate.cloudfront.domain_validation_options :
    dvo.domain_name => dvo
    if !startswith(dvo.domain_name, "*.")
  }

  zone_id = var.cloudflare_zone_id
  name    = trimsuffix(each.value.resource_record_name, ".")
  content = trimsuffix(each.value.resource_record_value, ".")
  type    = each.value.resource_record_type
  ttl     = 1
  proxied = false # CRITICAL: DNS validation must not be proxied
}

resource "aws_acm_certificate_validation" "cloudfront" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.cloudfront.arn
  validation_record_fqdns = [for dvo in aws_acm_certificate.cloudfront.domain_validation_options : dvo.resource_record_name]
}
