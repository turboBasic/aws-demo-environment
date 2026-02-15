################################################################################
# Regional ACM Certificate (eu-central-1)
################################################################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.30"
      configuration_aliases = [aws.us_east_1]
    }
  }
}

resource "aws_acm_certificate" "demo" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-regional-cert"
  })
}

resource "aws_acm_certificate_validation" "demo" {
  certificate_arn         = aws_acm_certificate.demo.arn
  validation_record_fqdns = [for dvo in aws_acm_certificate.demo.domain_validation_options : dvo.resource_record_name]
}

################################################################################
# CloudFront Certificate (us-east-1) with DNS Validation
################################################################################

resource "aws_acm_certificate" "cloudfront" {
  provider                  = aws.us_east_1
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-cloudfront-cert"
  })
}

resource "aws_acm_certificate_validation" "cloudfront" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.cloudfront.arn
  validation_record_fqdns = [for dvo in aws_acm_certificate.cloudfront.domain_validation_options : dvo.resource_record_name]
}

################################################################################
# ACM Validation Record Values (for dns-cloudflare module)
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

