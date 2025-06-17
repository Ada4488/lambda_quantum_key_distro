variable "environment" {
  description = "Deployment environment (e.g., dev, staging, prod)"
  type        = string
}

variable "qkd_sessions_table_name" {
  description = "Name for the QKD sessions DynamoDB table"
  type        = string
  default     = "qkd-sessions" # Default name, can be prefixed with environment
}

variable "eavesdrop_detections_table_name" {
  description = "Name for the eavesdrop detections DynamoDB table"
  type        = string
  default     = "eavesdrop-detections" # Default name, can be prefixed with environment
}

variable "encryption_metadata_table_name" {
  description = "Name for the encryption metadata DynamoDB table"
  type        = string
  default     = "encryption-metadata" # Default name, can be prefixed with environment
}

variable "billing_mode" {
  description = "DynamoDB billing mode (PROVISIONED or PAY_PER_REQUEST)"
  type        = string
  default     = "PAY_PER_REQUEST"
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for DynamoDB table encryption. If null, uses AWS owned CMK."
  type        = string
  default     = null
}

variable "enable_point_in_time_recovery" {
  description = "Whether to enable Point-in-Time Recovery for the tables"
  type        = bool
  default     = true
}

variable "stream_enabled_qkd_sessions" {
  description = "Enable DynamoDB Streams for the QKD sessions table"
  type        = bool
  default     = true # Enabled for eavesdrop-detector function
}

variable "stream_view_type_qkd_sessions" {
  description = "Specifies the information that will be written to the stream for QKD sessions table."
  type        = string
  default     = "NEW_AND_OLD_IMAGES" # Common choice for streams
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
