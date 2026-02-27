variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-central-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "demo"
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "aws-demo"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "create_nat_gateway" {
  description = "Whether to create NAT Gateway for private subnet internet access (increases cost by ~$1/day)"
  type        = bool
  default     = false
}

variable "domain_name" {
  description = "The domain name for the ACM certificate"
  type        = string
  default     = "turbobasic.dev"
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "The Cloudflare zone ID"
  type        = string
  sensitive   = true
}

variable "obsidian_bucket_name" {
  description = "The name of the S3 bucket for Obsidian vaults"
  type        = string
  default     = "obsidian-sync"
}

variable "obsidian_iam_user_name" {
  description = "The name of the IAM user for Obsidian vault access"
  type        = string
  default     = "obsidian-sync-user"
}
