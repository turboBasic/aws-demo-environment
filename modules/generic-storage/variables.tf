variable "user_name" {
  default = "s3-user"
  type    = string
}

variable "bucket_name" {
  description = "Name of the S3 bucket to create"
  type        = string
  default     = "00-personal"

  validation {
    condition = (
      length(var.bucket_name) >= 3 &&
      length(var.bucket_name) <= 50 &&
      can(regex("^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$", var.bucket_name))
    )
    error_message = "bucket_name must be 3-50 characters, use lowercase letters/numbers/hyphens, and start/end with a letter or number. The 50-char limit reserves room for '-<12-digit-account-id>'."
  }
}
