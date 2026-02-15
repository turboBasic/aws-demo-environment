output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.application_load_balancer.alb_dns_name
}

output "ec2_instance_id" {
  description = "ID of the demo EC2 instance"
  value       = module.web_instance.instance_id
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
