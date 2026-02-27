variable "bucket_name" {
  description = "The name of the S3 bucket for Obsidian vaults"
  type        = string
}

variable "iam_user_name" {
  description = "The name of the IAM user for Obsidian vault access"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "account_id" {
  description = "AWS account ID for S3 bucket naming"
  type        = string
}

variable "noncurrent_version_retention_days" {
  description = "Number of days to retain noncurrent S3 object versions before expiring them"
  type        = number
  default     = 30
}

variable "noncurrent_versions_to_keep" {
  description = "Number of most recent noncurrent versions to keep regardless of age"
  type        = number
  default     = 5
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
