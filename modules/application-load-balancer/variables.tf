variable "vpc_id" {
  description = "VPC ID where ALB will be deployed"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for ALB (minimum 2 for multi-AZ)"
  type        = list(string)
  validation {
    condition     = length(var.public_subnet_ids) >= 2
    error_message = "At least 2 public subnets are required for ALB"
  }
}

variable "certificate_arn" {
  description = "ARN of the SSL/TLS certificate for HTTPS listener"
  type        = string
}

variable "origin_verify_header" {
  description = "Custom header value for CloudFront origin verification"
  type        = string
  sensitive   = true
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "tags" {
  description = "Common tags to apply to all ALB resources"
  type        = map(string)
  default     = {}
}

variable "auto_destroy_tags" {
  description = "Tags for resources that should be auto-destroyed"
  type        = map(string)
  default     = {}
}
