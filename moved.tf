################################################################################
# Moved Blocks for Networking Module Migration
# These blocks ensure zero downtime by telling Terraform about the resource
# address changes when transitioning from root module to modules/networking
#
# Apply these moved blocks BEFORE removing the old resource definitions
################################################################################

moved {
  from = aws_vpc.main
  to   = module.networking.aws_vpc.main
}

moved {
  from = aws_internet_gateway.main
  to   = module.networking.aws_internet_gateway.main
}

moved {
  from = aws_subnet.public_a
  to   = module.networking.aws_subnet.public_a
}

moved {
  from = aws_subnet.public_b
  to   = module.networking.aws_subnet.public_b
}

moved {
  from = aws_subnet.private_a
  to   = module.networking.aws_subnet.private_a
}

moved {
  from = aws_eip.nat
  to   = module.networking.aws_eip.nat
}

moved {
  from = aws_nat_gateway.main
  to   = module.networking.aws_nat_gateway.main
}

moved {
  from = aws_route_table.public
  to   = module.networking.aws_route_table.public
}

moved {
  from = aws_route_table.private
  to   = module.networking.aws_route_table.private
}

moved {
  from = aws_route_table_association.public_a
  to   = module.networking.aws_route_table_association.public_a
}

moved {
  from = aws_route_table_association.public_b
  to   = module.networking.aws_route_table_association.public_b
}

moved {
  from = aws_route_table_association.private_a
  to   = module.networking.aws_route_table_association.private_a
}

moved {
  from = aws_vpc_endpoint.s3
  to   = module.networking.aws_vpc_endpoint.s3
}
################################################################################
# Moved Blocks for ALB Module Migration
# These blocks ensure zero downtime by telling Terraform about the resource
# address changes when transitioning from root module to modules/application-load-balancer
################################################################################

moved {
  from = aws_security_group.alb
  to   = module.application_load_balancer.aws_security_group.alb
}

moved {
  from = aws_vpc_security_group_ingress_rule.alb_https
  to   = module.application_load_balancer.aws_vpc_security_group_ingress_rule.alb_https
}

moved {
  from = aws_vpc_security_group_ingress_rule.alb_http
  to   = module.application_load_balancer.aws_vpc_security_group_ingress_rule.alb_http
}

moved {
  from = aws_vpc_security_group_egress_rule.alb_all
  to   = module.application_load_balancer.aws_vpc_security_group_egress_rule.alb_all
}

moved {
  from = aws_lb.demo
  to   = module.application_load_balancer.aws_lb.demo
}

moved {
  from = aws_lb_target_group.demo
  to   = module.application_load_balancer.aws_lb_target_group.demo
}

moved {
  from = aws_lb_listener.http
  to   = module.application_load_balancer.aws_lb_listener.http
}

moved {
  from = aws_lb_listener.https
  to   = module.application_load_balancer.aws_lb_listener.https
}

moved {
  from = aws_lb_listener_rule.cloudfront_origin
  to   = module.application_load_balancer.aws_lb_listener_rule.cloudfront_origin
}
################################################################################
# Moved Blocks for Web Instance Module Migration
# These blocks ensure zero downtime by telling Terraform about the resource
# address changes when transitioning from root module to modules/web-instance
################################################################################

moved {
  from = aws_security_group.ec2
  to   = module.web_instance.aws_security_group.ec2
}

moved {
  from = aws_vpc_security_group_ingress_rule.ec2_http_from_alb
  to   = module.web_instance.aws_vpc_security_group_ingress_rule.ec2_http_from_alb
}

moved {
  from = aws_vpc_security_group_egress_rule.ec2_all
  to   = module.web_instance.aws_vpc_security_group_egress_rule.ec2_all
}

moved {
  from = aws_instance.demo
  to   = module.web_instance.aws_instance.demo
}
################################################################################
# Moved Blocks for Static Site Module Migration
# These blocks ensure zero downtime by telling Terraform about the resource
# address changes when transitioning from root module to modules/static-site
################################################################################

moved {
  from = aws_cloudfront_origin_access_control.s3
  to   = module.static_site.aws_cloudfront_origin_access_control.s3
}

moved {
  from = aws_s3_bucket.static
  to   = module.static_site.aws_s3_bucket.static
}

moved {
  from = aws_s3_bucket_versioning.static
  to   = module.static_site.aws_s3_bucket_versioning.static
}

moved {
  from = aws_s3_bucket_server_side_encryption_configuration.static
  to   = module.static_site.aws_s3_bucket_server_side_encryption_configuration.static
}

moved {
  from = aws_s3_bucket_public_access_block.static
  to   = module.static_site.aws_s3_bucket_public_access_block.static
}

moved {
  from = aws_s3_bucket_lifecycle_configuration.static
  to   = module.static_site.aws_s3_bucket_lifecycle_configuration.static
}

moved {
  from = aws_cloudfront_distribution.main
  to   = module.static_site.aws_cloudfront_distribution.main
}

moved {
  from = aws_s3_bucket_policy.static
  to   = module.static_site.aws_s3_bucket_policy.static
}

################################################################################
# SSL Certificates Module Moved Blocks
################################################################################

moved {
  from = aws_acm_certificate.demo
  to   = module.ssl_certificates.aws_acm_certificate.demo
}

moved {
  from = aws_acm_certificate_validation.demo
  to   = module.ssl_certificates.aws_acm_certificate_validation.demo
}

moved {
  from = aws_acm_certificate.cloudfront
  to   = module.ssl_certificates.aws_acm_certificate.cloudfront
}

moved {
  from = aws_acm_certificate_validation.cloudfront
  to   = module.ssl_certificates.aws_acm_certificate_validation.cloudfront
}

################################################################################
# DNS Cloudflare Module Relocations
################################################################################

# ACM validation DNS record moved from root to dns_cloudflare module
moved {
  from = module.ssl_certificates.cloudflare_dns_record.acm_validation
  to   = module.dns_cloudflare.cloudflare_dns_record.acm_validation
}

# Zone SSL setting moved from ssl_certificates to dns_cloudflare module
moved {
  from = module.ssl_certificates.cloudflare_zone_setting.ssl
  to   = module.dns_cloudflare.cloudflare_zone_setting.ssl
}

# www to apex redirect ruleset moved from ssl_certificates to dns_cloudflare module
moved {
  from = module.ssl_certificates.cloudflare_ruleset.redirect_www
  to   = module.dns_cloudflare.cloudflare_ruleset.redirect_www
}

# CloudFront apex domain record moved from root to dns_cloudflare module
moved {
  from = cloudflare_dns_record.demo
  to   = module.dns_cloudflare.cloudflare_dns_record.demo
}

# CloudFront www subdomain record moved from root to dns_cloudflare module
moved {
  from = cloudflare_dns_record.www
  to   = module.dns_cloudflare.cloudflare_dns_record.www
}
