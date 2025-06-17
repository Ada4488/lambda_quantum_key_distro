variable "environment" {
  description = "Deployment environment (e.g., dev, staging, prod). Note: function_name_prefix is preferred for naming resources if it includes the environment."
  type        = string
}

variable "function_name_prefix" {
  description = "Prefix for Lambda function names and related IAM resources (e.g., project-environment)."
  type        = string
}

variable "lambda_runtime" {
  description = "Lambda runtime for the functions."
  type        = string
  default     = "python3.11"
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds."
  type        = number
  default     = 300 # 5 minutes
}

variable "lambda_memory_size" {
  description = "Lambda function memory size in MB."
  type        = number
  default     = 256
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table for QKD sessions."
  type        = string
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket (if needed by any function in this module, e.g., key-validator)."
  type        = string
  default     = null
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for data encryption."
  type        = string
}

variable "crypto_layer_arn" {
  description = "ARN of the Crypto Lambda Layer."
  type        = string
}

variable "utilities_layer_arn" {
  description = "ARN of the Utilities Lambda Layer."
  type        = string
}

variable "aws_region" {
  description = "AWS Region for resource creation (e.g., for constructing ARNs in IAM policies)."
  type        = string
}

variable "aws_account_id" {
  description = "AWS Account ID for resource creation (e.g., for constructing ARNs in IAM policies)."
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources."
  type        = map(string)
  default     = {}
}

variable "eavesdrop_detections_table_name" {
  description = "Name of the DynamoDB table for eavesdropping detections."
  type        = string
  default     = null
}

variable "dynamodb_stream_arn" {
  description = "ARN of the DynamoDB Stream that triggers the eavesdrop-detector function."
  type        = string
  default     = null
}

variable "sns_topic_arn" {
  description = "ARN of the SNS Topic for security alerts."
  type        = string
  default     = null
}

resource "aws_lambda_function" "qkd_simulator" {
  filename      = data.archive_file.qkd_simulator_zip.output_path
  function_name = "${var.function_name_prefix}-qkd-simulator"
  role          = var.lambda_exec_role_arn
  handler       = "handler.lambda_handler" # For Python
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size

  source_code_hash = data.archive_file.qkd_simulator_zip.output_base64sha256

  layers = [
    var.crypto_layer_arn,
    var.utilities_layer_arn
  ]

  environment {
    # ... existing environment variables ...
  }

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.function_name_prefix}-qkd-simulator"
      Environment = var.environment
    }
  )
}