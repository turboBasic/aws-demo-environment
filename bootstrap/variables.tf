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

variable "github_repo" {
  description = "GitHub repository URL for the demo environment"
  type        = string
  default     = "https://github.com/turboBasic/aws-demo-environment.git"
}

variable "github_token" {
  description = "GitHub personal access token for cloning the repository"
  type        = string
  sensitive   = true
}

variable "ttl_hours" {
  description = "Number of hours before the demo environment is automatically destroyed"
  type        = number
  default     = 24
}

variable "state_key" {
  description = "S3 key for the demo environment Terraform state file"
  type        = string
  default     = "aws-demo/terraform.tfstate"
}
