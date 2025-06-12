variable "environment" {
  description = "Deployment environment (e.g., dev, staging, prod)"
  type        = string
}

variable "lambda_runtime" {
  description = "The runtime environment for the Lambda functions (e.g., python3.11)"
  type        = string
}

variable "lambda_exec_role_arn" {
  description = "ARN of the IAM role for Lambda execution"
  type        = string
}

variable "qkd_simulator_function_name" {
  description = "Name for the QKD Simulator Lambda function"
  type        = string
  default     = "qkd-simulator"
}

variable "eavesdrop_detector_function_name" {
  description = "Name for the Eavesdrop Detector Lambda function"
  type        = string
  default     = "eavesdrop-detector"
}

variable "key_validator_function_name" {
  description = "Name for the Key Validator Lambda function"
  type        = string
  default     = "key-validator"
}

variable "common_lambda_env_vars" {
  description = "Common environment variables for all Lambda functions"
  type        = map(string)
  default     = {}
}

variable "qkd_sessions_table_name" {
  description = "Name of the DynamoDB table for QKD sessions"
  type        = string
}

# variable "crypto_layer_arn" {
#   description = "ARN of the Crypto Lambda Layer"
#   type        = string
# }

# variable "powertools_layer_arn" {
#   description = "ARN of the AWS Lambda Powertools Layer"
#   type        = string
# }

# variable "private_subnet_ids" {
#   description = "List of private subnet IDs for Lambda VPC configuration"
#   type        = list(string)
#   default     = []
# }

# variable "lambda_security_group_id" {
#   description = "Security group ID for Lambda functions in VPC"
#   type        = string
#   default     = "" # Only if VPC config is used
# }

# variable "default_dlq_arn" {
#   description = "ARN of the default Dead Letter Queue (SQS or SNS) for Lambda functions"
#   type        = string
#   default     = "" # Optional: only if DLQs are configured by default
# }

variable "common_tags" {
  description = "Common tags to apply to all resources in this module"
  type        = map(string)
  default     = {}
}

variable "lambda_source_base_path" {
  description = "Base path for Lambda source code, relative to the module directory."
  type        = string
  default     = "../../src/functions" # e.g., ../../src/functions
}

variable "dist_path" {
  description = "Path to the dist directory for zipped artifacts, relative to the module directory."
  type        = string
  default     = "../../dist"
}
