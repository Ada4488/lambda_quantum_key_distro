output "qkd_simulator_lambda_arn" {
  description = "ARN of the QKD Simulator Lambda function"
  value       = aws_lambda_function.qkd_simulator.arn
}

output "qkd_simulator_lambda_name" {
  description = "Name of the QKD Simulator Lambda function"
  value       = aws_lambda_function.qkd_simulator.function_name
}

# output "eavesdrop_detector_lambda_arn" {
#   description = "ARN of the Eavesdrop Detector Lambda function"
#   value       = aws_lambda_function.eavesdrop_detector.arn
# }

# output "key_validator_lambda_arn" {
#   description = "ARN of the Key Validator Lambda function"
#   value       = aws_lambda_function.key_validator.arn
# }
