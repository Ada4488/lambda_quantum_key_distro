variable "environment" {
  description = "Deployment environment (e.g., dev, staging, prod)"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources in this module."
  type        = map(string)
  default     = {}
}

variable "lambda_exec_role_arn" {
  description = "ARN of the Lambda execution role to grant KMS permissions."
  type        = string
}

variable "aws_region" {
  description = "AWS region for constructing service principals or conditions in KMS policy."
  type        = string
}
