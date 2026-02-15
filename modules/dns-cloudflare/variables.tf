variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for DNS records and settings"
  type        = string
  sensitive   = true
}

variable "domain_name" {
  description = "The primary domain name"
  type        = string
}

variable "cloudfront_domain_name" {
  description = "CloudFront distribution domain name for CNAME records"
  type        = string
}

variable "acm_validation_record_name" {
  description = "Name component of the ACM certificate validation CNAME record"
  type        = string
  sensitive   = true
}

variable "acm_validation_record_value" {
  description = "Value of the ACM certificate validation CNAME record"
  type        = string
  sensitive   = true
}

variable "acm_validation_record_type" {
  description = "Record type for ACM certificate validation (typically CNAME)"
  type        = string
  default     = "CNAME"
}
