output "regional_certificate_arn" {
  description = "The ARN of the regional ACM certificate"
  value       = aws_acm_certificate.demo.arn
}

output "cloudfront_certificate_arn" {
  description = "The ARN of the CloudFront ACM certificate (us-east-1)"
  value       = aws_acm_certificate.cloudfront.arn
}

output "regional_validation_id" {
  description = "The ID of the regional certificate validation"
  value       = aws_acm_certificate_validation.demo.id
}

output "cloudfront_validation_id" {
  description = "The ID of the CloudFront certificate validation"
  value       = aws_acm_certificate_validation.cloudfront.id
}

################################################################################
# ACM Validation Record Details (for dns-cloudflare module)
################################################################################

output "acm_validation_record_name" {
  description = "Name component of the ACM certificate validation DNS record"
  value       = trimsuffix(local.cloudfront_validation.resource_record_name, ".")
  sensitive   = true
}

output "acm_validation_record_value" {
  description = "Value of the ACM certificate validation DNS record"
  value       = trimsuffix(local.cloudfront_validation.resource_record_value, ".")
  sensitive   = true
}

output "acm_validation_record_type" {
  description = "Type of the ACM certificate validation DNS record"
  value       = local.cloudfront_validation.resource_record_type
}

