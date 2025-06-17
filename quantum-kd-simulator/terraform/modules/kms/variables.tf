variable "environment" {
  description = "Deployment environment (e.g., dev, staging, prod)"
  type        = string
}

variable "key_alias_name" {
  description = "Alias name for the KMS key"
  type        = string
  default     = "alias/qkd-cmk"
}

variable "key_description" {
  description = "Description for the KMS key"
  type        = string
  default     = "KMS key for QKD project data encryption"
}

variable "key_deletion_window_in_days" {
  description = "Number of days to wait before deleting the KMS key"
  type        = number
  default     = 7
}

variable "enable_key_rotation" {
  description = "Whether to enable automatic key rotation for the KMS key"
  type        = bool
  default     = true
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
