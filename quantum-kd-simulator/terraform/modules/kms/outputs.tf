output "key_arn" {
  description = "ARN of the KMS key"
  value       = aws_kms_key.qkd_key.arn
}

output "key_id" {
  description = "ID of the KMS key"
  value       = aws_kms_key.qkd_key.id
}

output "alias_name" {
  description = "Name of the KMS key alias"
  value       = aws_kms_alias.qkd_key_alias.name
}

output "alias_arn" {
  description = "ARN of the KMS key alias"
  value       = aws_kms_alias.qkd_key_alias.arn
}
