variable "bucket_name" {
  description = "Name of the S3 bucket. A unique name will be generated if not provided."
  type        = string
  default     = null
}

variable "acl" {
  description = "The canned ACL to apply. Defaults to 'private'."
  type        = string
  default     = "private"
}

variable "versioning" {
  description = "A state of versioning. Defaults to true."
  type        = bool
  default     = true
}

variable "force_destroy" {
  description = "A boolean that indicates all objects should be deleted from the bucket so that the bucket can be destroyed without error. These objects are not recoverable. Defaults to false."
  type        = bool
  default     = false
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for S3 server-side encryption. If not provided, AES256 will be used."
  type        = string
  default     = null
}

variable "common_tags" {
  description = "Common tags to apply to all resources."
  type        = map(string)
  default     = {}
}

variable "lambda_function_arn" {
  description = "ARN of the Lambda function to trigger on S3 events"
  type        = string
  default     = null
}

variable "notification_filter_prefix" {
  description = "Object key name prefix for S3 event notifications"
  type        = string
  default     = ""
}

variable "notification_filter_suffix" {
  description = "Object key name suffix for S3 event notifications"
  type        = string
  default     = ""
}

variable "enable_cors" {
  description = "Enable CORS configuration for the bucket"
  type        = bool
  default     = false
}

variable "cors_allowed_origins" {
  description = "List of allowed origins for CORS"
  type        = list(string)
  default     = ["*"]
}

variable "enable_lifecycle" {
  description = "Enable lifecycle configuration for the bucket"
  type        = bool
  default     = false
}

variable "object_expiration_days" {
  description = "Number of days after which objects expire"
  type        = number
  default     = 365
}
