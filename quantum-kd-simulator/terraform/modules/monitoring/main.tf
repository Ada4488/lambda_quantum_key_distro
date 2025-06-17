# Resources for the monitoring module

# CloudWatch Log Groups for Lambda Functions
resource "aws_cloudwatch_log_group" "lambda_log_groups" {
  for_each = toset(var.lambda_function_names)

  name              = "/aws/lambda/${each.key}"
  retention_in_days = var.log_retention_in_days

  tags = {
    Name        = "/aws/lambda/${each.key}"
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = "quantum-kd-simulator"
  }
}

# SNS Topic for alerting if email endpoint is provided
resource "aws_sns_topic" "alerts" {
  count = var.enable_alarms && var.sns_email_endpoint != "" ? 1 : 0
  name  = "qkd-simulator-${var.environment}-alerts"
}

# SNS subscription for email alerting
resource "aws_sns_topic_subscription" "email_alerts" {
  count     = var.enable_alarms && var.sns_email_endpoint != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts[0].arn
  protocol  = "email"
  endpoint  = var.sns_email_endpoint
}

# Lambda Error Rate Alarms (1 per function)
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  for_each = var.enable_alarms ? toset(var.lambda_function_names) : []

  alarm_name        = "${each.value}-error-rate-alarm"
  alarm_description = "Triggers when the error rate for ${each.value} exceeds ${var.lambda_error_rate_threshold}%"

  comparison_operator = "GreaterThanThreshold"
  threshold           = var.lambda_error_rate_threshold
  evaluation_periods  = 1
  
  # The period in seconds over which the specified statistic is applied.
  # Using 5 minute period for cost efficiency (1 minute would generate more data points)
  period = 300

  namespace   = "AWS/Lambda"
  metric_name = "Errors"
  statistic   = "Sum"
  dimensions = {
    FunctionName = each.value
  }

  # Only create an alarm action if we have an SNS topic
  alarm_actions = var.sns_email_endpoint != "" ? [aws_sns_topic.alerts[0].arn] : []
  ok_actions    = var.sns_email_endpoint != "" ? [aws_sns_topic.alerts[0].arn] : []

  treat_missing_data = "notBreaching" # Don't alert when there's no data (e.g., no invocations)

  tags = {
    Name        = "${each.value}-error-rate-alarm"
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = "quantum-kd-simulator"
  }
}

# Lambda Duration Alarm for QKD simulator (most important function to monitor)
resource "aws_cloudwatch_metric_alarm" "qkd_simulator_duration" {
  count = var.enable_alarms && contains(var.lambda_function_names, "qkd-simulator") ? 1 : 0
  
  alarm_name        = "qkd-simulator-duration-alarm"
  alarm_description = "Triggers when the QKD Simulator execution time approaches timeout"

  comparison_operator = "GreaterThanThreshold"
  threshold           = 0.80 # Alert when using 80% of configured timeout
  evaluation_periods  = 1
  period              = 300
  
  namespace   = "AWS/Lambda"
  metric_name = "Duration"
  statistic   = "Maximum"
  
  dimensions = {
    FunctionName = "qkd-simulator"
  }
  
  # Only create an alarm action if we have an SNS topic
  alarm_actions = var.sns_email_endpoint != "" ? [aws_sns_topic.alerts[0].arn] : []
  
  treat_missing_data = "notBreaching"
  
  tags = {
    Name        = "qkd-simulator-duration-alarm"
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = "quantum-kd-simulator"
  }
}

# Basic API Gateway 4xx and 5xx error monitoring
resource "aws_cloudwatch_metric_alarm" "api_errors" {
  count = var.enable_alarms ? 1 : 0
  
  alarm_name        = "api-gateway-error-alarm"
  alarm_description = "Triggers when the API Gateway has a high rate of 4xx or 5xx errors"
  
  comparison_operator = "GreaterThanThreshold"
  threshold           = 5  # More than 5 errors in the period
  evaluation_periods  = 1
  period              = 300
  
  namespace   = "AWS/ApiGateway"
  metric_name = "5XXError"  # Could also monitor 4XXError separately
  statistic   = "Sum"
  
  dimensions = {
    ApiName = var.api_name
  }
  
  # Only create an alarm action if we have an SNS topic
  alarm_actions = var.sns_email_endpoint != "" ? [aws_sns_topic.alerts[0].arn] : []
  
  treat_missing_data = "notBreaching"
  
  tags = {
    Name        = "api-gateway-error-alarm"
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = "quantum-kd-simulator"
  }
}
