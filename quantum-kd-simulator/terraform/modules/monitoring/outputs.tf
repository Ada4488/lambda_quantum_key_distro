# Outputs for the monitoring module (e.g., CloudWatch Dashboard names, Log Group ARNs)

output "log_group_names" {
  description = "Names of the created CloudWatch Log Groups"
  value       = { for k, v in aws_cloudwatch_log_group.lambda_log_groups : k => v.name }
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = var.enable_alarms && var.sns_email_endpoint != "" ? aws_sns_topic.alerts[0].arn : null
}

output "lambda_error_alarms" {
  description = "Map of Lambda functions to their error alarms"
  value       = var.enable_alarms ? { for k, v in aws_cloudwatch_metric_alarm.lambda_errors : k => v.arn } : {}
}
