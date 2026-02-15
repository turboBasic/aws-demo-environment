variable "vpc_id" {
  description = "VPC ID where EC2 instance will be deployed"
  type        = string
}

variable "private_subnet_id" {
  description = "Private subnet ID for EC2 instance placement"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "alb_security_group_id" {
  description = "Security group ID of the ALB for ingress rules"
  type        = string
}

variable "user_data" {
  description = "User data script for EC2 initialization"
  type        = string
  default     = ""
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "auto_destroy_tags" {
  description = "Tags for resources that should be auto-destroyed"
  type        = map(string)
  default     = {}
}
