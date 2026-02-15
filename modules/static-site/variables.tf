variable "domain_name" {
  description = "Domain name for CloudFront distribution (alias)"
  type        = string
}

variable "alb_dns_name" {
  description = "DNS name of the ALB serving as the dynamic content origin"
  type        = string
}

variable "cloudfront_certificate_arn" {
  description = "ARN of ACM certificate in us-east-1 for CloudFront"
  type        = string
}

variable "origin_verify_header" {
  description = "Custom header value for ALB origin verification"
  type        = string
  sensitive   = true
}

variable "account_id" {
  description = "AWS account ID for S3 bucket naming"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "price_class" {
  description = "CloudFront price class (PriceClass_100, PriceClass_200, PriceClass_All)"
  type        = string
  default     = "PriceClass_100"
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
