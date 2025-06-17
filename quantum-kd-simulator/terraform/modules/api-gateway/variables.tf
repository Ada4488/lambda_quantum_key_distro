variable "api_name" {
  description = "Name for the API Gateway."
  type        = string
  default     = "qkd-simulator-api"
}

variable "stage_name" {
  description = "Name of the deployment stage."
  type        = string
  default     = "dev"
}

variable "lambda_invoke_arn" {
  description = "ARN of the Lambda function to invoke (e.g., qkd-simulator)."
  type        = string
}

variable "lambda_function_name" {
  description = "Name of the Lambda function (used for permissions)."
  type        = string
}

variable "aws_region" {
  description = "AWS Region for resource creation."
  type        = string
}

variable "aws_account_id" {
  description = "AWS Account ID for resource creation."
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources."
  type        = map(string)
  default     = {}
}
