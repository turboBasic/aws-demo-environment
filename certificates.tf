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
  content = aws_lb.demo.dns_name
  type    = "CNAME"
  ttl     = 1
  proxied = true # orange cloud, Cloudflare proxy
}

resource "cloudflare_zone_setting" "ssl" {
  zone_id    = var.cloudflare_zone_id
  setting_id = "ssl"
  value      = "strict"
}
