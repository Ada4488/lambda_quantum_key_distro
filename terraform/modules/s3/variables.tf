variable "environment" {
  description = "Deployment environment (e.g., dev, staging, prod)"
  type        = string
}

variable "bucket_name_prefix" {
  description = "Prefix for the S3 bucket name. Full name will be ${environment}-${bucket_name_prefix}-qkd-data."
  type        = string
  default     = "app"
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for S3 server-side encryption."
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources in this module."
  type        = map(string)
  default     = {}
}

variable "enable_access_logging" {
  description = "Flag to enable S3 server access logging for the primary bucket."
  type        = bool
  default     = false
}

variable "s3_access_log_bucket_id" {
  description = "The ID (name) of the S3 bucket where server access logs will be delivered. Required if enable_access_logging is true."
  type        = string
  default     = "" # e.g., my-s3-access-logs-bucket
}

variable "lifecycle_log_retention_days" {
  description = "Number of days to retain logs in the S3 bucket (if logs are stored here)."
  type        = number
  default     = 90
}

variable "lifecycle_noncurrent_version_transition_days" {
  description = "Number of days after which to transition noncurrent versions to a colder storage class."
  type        = number
  default     = 30
}

variable "lifecycle_noncurrent_version_expiration_days" {
  description = "Number of days after which to expire noncurrent versions."
  type        = number
  default     = 365
}

variable "lifecycle_abort_incomplete_multipart_upload_days" {
  description = "Number of days after which to abort incomplete multipart uploads."
  type        = number
  default     = 7
}

variable "cors_rules" {
  description = "A list of CORS rule objects. See AWS S3 CORS documentation for structure."
  type        = list(object({
    allowed_headers = optional(list(string))
    allowed_methods = list(string)
    allowed_origins = list(string)
    expose_headers  = optional(list(string))
    max_age_seconds = optional(number)
  }))
  default     = []
  # Example:
  # default = [
  #   {
  #     allowed_headers = ["Authorization", "Content-Type"]
  #     allowed_methods = ["GET", "POST"]
  #     allowed_origins = ["https://example.com"]
  #     expose_headers  = ["ETag"]
  #     max_age_seconds = 3000
  #   }
  # ]
}
