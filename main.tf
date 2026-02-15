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
# Networking Module
################################################################################

module "networking" {
  source = "./modules/networking"

  vpc_cidr             = var.vpc_cidr
  availability_zones   = data.aws_availability_zones.available.names
  public_subnet_cidrs  = [local.public_a_cidr, local.public_b_cidr]
  private_subnet_cidrs = [local.private_a_cidr]
  region               = var.aws_region
  name_prefix          = local.name_prefix

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
  certificate_arn      = aws_acm_certificate_validation.demo.certificate_arn
  origin_verify_header = random_password.origin_verify.result
  name_prefix          = local.name_prefix

  tags = local.common_tags

  auto_destroy_tags = local.auto_destroy_tags
}
################################################################################
# Web Instance Module
################################################################################

module "web_instance" {
  source = "./modules/web-instance"

  vpc_id                = module.networking.vpc_id
  private_subnet_id     = module.networking.private_subnet_a_id
  ami_id                = data.aws_ami.al2023.id
  instance_type         = var.instance_type
  alb_security_group_id = module.application_load_balancer.alb_security_group_id
  user_data             = file("${path.module}/scripts/user_data.sh")
  name_prefix           = local.name_prefix

  tags = local.common_tags

  auto_destroy_tags = local.auto_destroy_tags
}
