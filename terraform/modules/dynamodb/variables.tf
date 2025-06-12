variable "environment" {
  description = "Deployment environment (e.g., dev, staging, prod)"
  type        = string
}

variable "qkd_sessions_table_name" {
  description = "Name for the QKD sessions DynamoDB table."
  type        = string
  default     = "qkd-sessions"
}

variable "eavesdrop_detections_table_name" {
  description = "Name for the eavesdrop detections DynamoDB table."
  type        = string
  default     = "eavesdrop-detections"
}

variable "kms_key_arn" {
  description = "ARN of the KMS key to use for DynamoDB server-side encryption."
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources in this module."
  type        = map(string)
  default     = {}
}
