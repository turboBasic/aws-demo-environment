variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "aws-demo"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "demo"
}

variable "ttl_minutes" {
  description = "Number of minutes before the demo environment is automatically destroyed"
  type        = number
  default     = 1440 # 24 hours
}

variable "state_key" {
  description = "S3 key for the demo environment Terraform state file"
  type        = string
  default     = "aws-demo/terraform.tfstate"
}
