output "qkd_sessions_table_name" {
  description = "Name of the QKD sessions DynamoDB table"
  value       = aws_dynamodb_table.qkd_sessions.name
}

output "qkd_sessions_table_arn" {
  description = "ARN of the QKD sessions DynamoDB table"
  value       = aws_dynamodb_table.qkd_sessions.arn
}

output "qkd_sessions_stream_arn" {
  description = "ARN of the DynamoDB Stream for the QKD sessions table."
  value       = var.stream_enabled_qkd_sessions ? aws_dynamodb_table.qkd_sessions.stream_arn : null
}

output "eavesdrop_detections_table_name" {
  description = "Name of the eavesdrop detections DynamoDB table"
  value       = aws_dynamodb_table.eavesdrop_detections.name
}

output "eavesdrop_detections_table_arn" {
  description = "ARN of the eavesdrop detections DynamoDB table"
  value       = aws_dynamodb_table.eavesdrop_detections.arn
}

output "encryption_metadata_table_name" {
  description = "Name of the encryption metadata DynamoDB table"
  value       = aws_dynamodb_table.encryption_metadata.name
}

output "encryption_metadata_table_arn" {
  description = "ARN of the encryption metadata DynamoDB table"
  value       = aws_dynamodb_table.encryption_metadata.arn
}
