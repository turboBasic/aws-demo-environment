variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "Must be a valid IPv4 CIDR block"
  }
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets (must match number of AZs)"
  type        = list(string)
  validation {
    condition     = length(var.public_subnet_cidrs) >= 2
    error_message = "At least 2 public subnets are required for ALB"
  }
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets"
  type        = list(string)
  validation {
    condition     = length(var.private_subnet_cidrs) >= 1
    error_message = "At least 1 private subnet is required"
  }
}

variable "region" {
  description = "AWS region for VPC endpoint service names"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "tags" {
  description = "Common tags to apply to all networking resources"
  type        = map(string)
  default     = {}
}

variable "auto_destroy_tags" {
  description = "Tags for resources that should be auto-destroyed"
  type        = map(string)
  default     = {}
}

variable "create_nat_gateway" {
  description = "Whether to create NAT Gateway for private subnet internet access"
  type        = bool
  default     = false
}
