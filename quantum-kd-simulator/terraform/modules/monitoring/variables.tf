# Variables for the monitoring module (e.g., log retention period, alarm thresholds)

variable "environment" {
  description = "The deployment environment (e.g., dev, staging, prod)"
  type        = string
}

variable "lambda_function_names" {
  description = "A list of Lambda function names to create log groups for."
  type        = list(string)
  default     = []
}

variable "log_retention_in_days" {
  description = "Number of days to retain logs in CloudWatch Log Groups."
  type        = number
  default     = 7 # Default to 7 days, adjust as needed
}
