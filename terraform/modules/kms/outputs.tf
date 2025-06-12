output "key_arn" {
  description = "ARN of the customer managed KMS key."
  value       = aws_kms_key.qkd_cmk.arn
}

output "key_id" {
  description = "ID of the customer managed KMS key."
  value       = aws_kms_key.qkd_cmk.key_id
}
