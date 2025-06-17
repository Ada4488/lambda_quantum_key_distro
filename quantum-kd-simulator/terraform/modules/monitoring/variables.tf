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

variable "enable_alarms" {
  description = "Whether to enable CloudWatch alarms"
  type        = bool
  default     = true
}

variable "sns_email_endpoint" {
  description = "Email address to receive alarm notifications. Will be used to create SNS subscription."
  type        = string
  default     = ""
}

variable "lambda_error_rate_threshold" {
  description = "Percentage threshold for Lambda function errors that will trigger an alarm"
  type        = number
  default     = 5 # 5% error rate
}

variable "api_response_time_threshold" {
  description = "Threshold in milliseconds for API Gateway response time that will trigger an alarm"
  type        = number
  default     = 3000 # 3 seconds
}
