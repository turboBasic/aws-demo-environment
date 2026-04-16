output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.application_load_balancer.alb_dns_name
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs_fargate.cluster_name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = module.ecs_fargate.service_name
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = module.static_site.cloudfront_distribution_id
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = module.static_site.cloudfront_domain_name
}

output "s3_static_bucket_name" {
  description = "S3 bucket name for static content"
  value       = module.static_site.s3_bucket_id
}

output "s3_static_bucket_arn" {
  description = "S3 bucket ARN for static content"
  value       = module.static_site.s3_bucket_arn
}

output "obsidian_vault_bucket_name" {
  description = "S3 bucket name for Obsidian vaults"
  value = module.obsidian_vaults.bucket_name
}

output "obsidian_sync_access_key_id" {
  description = "Access key ID for the IAM user with access to the Obsidian vaults S3 bucket"
  value = module.obsidian_vaults.access_key_id
}

################################################################################
# Generic Storage (S3 User with MFA) Outputs
################################################################################

output "generic_storage_access_key_id" {
  description = "Access key ID for the s3-user IAM account"
  value       = module.generic_storage.access_key_id
}

output "generic_storage_secret_access_key" {
  description = "Secret access key for the s3-user IAM account (sensitive)"
  value       = module.generic_storage.secret_access_key
  sensitive   = true
}

output "generic_storage_role_arn" {
  description = "ARN of the S3AccessRole with MFA enforcement"
  value       = module.generic_storage.role_arn
}

output "obsidian_sync_secret_access_key" {
  description = "Secret access key for the IAM user with access to the Obsidian vaults S3 bucket"
  value     = module.obsidian_vaults.secret_access_key
  sensitive = true
}
