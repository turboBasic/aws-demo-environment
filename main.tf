terraform {
  required_version = ">= 1.14"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.30"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

################################################################################
# Origin Verification Header (for ALB origin protection in CloudFront)
################################################################################

resource "random_password" "origin_verify" {
  length  = 32
  special = false
}

################################################################################
# Networking Module
################################################################################

module "networking" {
  source = "./modules/networking"

  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = [local.network_cidrs.public_a, local.network_cidrs.public_b]
  private_subnet_cidrs = [local.network_cidrs.private_a]
  region               = var.aws_region
  name_prefix          = local.name_prefix
  create_nat_gateway   = var.create_nat_gateway

  tags = local.common_tags

  auto_destroy_tags = local.auto_destroy_tags
}

################################################################################
# Application Load Balancer Module
################################################################################

module "application_load_balancer" {
  source = "./modules/application-load-balancer"

  vpc_id               = module.networking.vpc_id
  public_subnet_ids    = module.networking.public_subnet_ids
  certificate_arn      = module.ssl_certificates.regional_certificate_arn
  origin_verify_header = random_password.origin_verify.result
  name_prefix          = local.name_prefix

  tags = local.common_tags

  auto_destroy_tags = local.auto_destroy_tags
}

################################################################################
# ECS Fargate Module
################################################################################

module "ecs_fargate" {
  source = "./modules/ecs-fargate"

  name_prefix           = local.name_prefix
  vpc_id                = module.networking.vpc_id
  public_subnet_ids     = module.networking.public_subnet_ids
  alb_security_group_id = module.application_load_balancer.alb_security_group_id
  target_group_arn      = module.application_load_balancer.target_group_arn
  region                = var.aws_region

  container_image = "httpd:2.4"
  container_port  = 80
  task_cpu        = "256"
  task_memory     = "512"
  desired_count   = 1

  tags = local.common_tags

  auto_destroy_tags = local.auto_destroy_tags
}

################################################################################
# SSL Certificates Module
################################################################################

module "ssl_certificates" {
  source = "./modules/ssl-certificates"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  domain_name = var.domain_name
  name_prefix = local.name_prefix

  tags = local.common_tags
}

################################################################################
# Static Site (S3 + CloudFront) Module
################################################################################

module "static_site" {
  source = "./modules/static-site"

  domain_name                = var.domain_name
  alb_dns_name               = module.application_load_balancer.alb_dns_name
  cloudfront_certificate_arn = module.ssl_certificates.cloudfront_certificate_arn
  account_id                 = data.aws_caller_identity.current.account_id
  origin_verify_header       = random_password.origin_verify.result
  name_prefix                = local.name_prefix

  tags = local.common_tags
}

################################################################################
# DNS Cloudflare Module (DNS records, zone settings, redirect rules)
################################################################################

module "dns_cloudflare" {
  source = "./modules/dns-cloudflare"

  providers = {
    cloudflare = cloudflare
  }

  cloudflare_zone_id          = var.cloudflare_zone_id
  domain_name                 = var.domain_name
  cloudfront_domain_name      = module.static_site.cloudfront_domain_name
  acm_validation_record_name  = module.ssl_certificates.acm_validation_record_name
  acm_validation_record_value = module.ssl_certificates.acm_validation_record_value
  acm_validation_record_type  = module.ssl_certificates.acm_validation_record_type
}
