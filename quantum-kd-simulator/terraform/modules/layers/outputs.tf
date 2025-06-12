
output "crypto_layer_arn" {
  description = "The ARN of the crypto Lambda layer version."
  value       = aws_lambda_layer_version.crypto_layer.arn
}

output "crypto_layer_version_arn" {
  description = "The ARN of the crypto Lambda layer version including the version."
  value       = aws_lambda_layer_version.crypto_layer.arn
}

output "utilities_layer_arn" {
  description = "The ARN of the utilities Lambda layer version."
  value       = aws_lambda_layer_version.utilities_layer.arn
}

output "utilities_layer_version_arn" {
  description = "The ARN of the utilities Lambda layer version including the version."
  value       = aws_lambda_layer_version.utilities_layer.arn
}
