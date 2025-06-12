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

# Placeholder for other monitoring resources like:
# - CloudWatch Dashboards
# - CloudWatch Alarms (CPU, Memory, Errors, Custom Metrics)
# - EventBridge rules for notifications
