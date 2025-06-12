output "qkd_sessions_table_name" {
  description = "Name of the QKD sessions DynamoDB table."
  value       = aws_dynamodb_table.qkd_sessions.name
}

output "qkd_sessions_table_arn" {
  description = "ARN of the QKD sessions DynamoDB table."
  value       = aws_dynamodb_table.qkd_sessions.arn
}

output "qkd_sessions_table_stream_arn" {
  description = "Stream ARN of the QKD sessions DynamoDB table."
  value       = aws_dynamodb_table.qkd_sessions.stream_arn
}

output "eavesdrop_detections_table_name" {
  description = "Name of the eavesdrop detections DynamoDB table."
  value       = aws_dynamodb_table.eavesdrop_detections.name
}

output "eavesdrop_detections_table_arn" {
  description = "ARN of the eavesdrop detections DynamoDB table."
  value       = aws_dynamodb_table.eavesdrop_detections.arn
}
