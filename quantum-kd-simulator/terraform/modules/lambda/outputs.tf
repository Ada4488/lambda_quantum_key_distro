output "qkd_simulator_arn" {
  description = "ARN of the QKD Simulator Lambda function."
  value       = aws_lambda_function.qkd_simulator.arn
}

output "qkd_simulator_invoke_arn" {
  description = "Invoke ARN of the QKD Simulator Lambda function."
  value       = aws_lambda_function.qkd_simulator.invoke_arn
}

output "qkd_simulator_name" {
  description = "Name of the QKD Simulator Lambda function."
  value       = aws_lambda_function.qkd_simulator.function_name
}

output "lambda_exec_role_arn" {
  description = "ARN of the IAM role used by the Lambda functions."
  value       = aws_iam_role.lambda_exec_role.arn
}

output "eavesdrop_detector_arn" {
  description = "ARN of the Eavesdrop Detector Lambda function."
  value       = aws_lambda_function.eavesdrop_detector.arn
}

output "eavesdrop_detector_name" {
  description = "Name of the Eavesdrop Detector Lambda function."
  value       = aws_lambda_function.eavesdrop_detector.function_name
}

output "key_validator_arn" {
  description = "ARN of the Key Validator Lambda function."
  value       = aws_lambda_function.key_validator.arn
}

output "key_validator_invoke_arn" {
  description = "Invoke ARN of the Key Validator Lambda function."
  value       = aws_lambda_function.key_validator.invoke_arn
}

output "key_validator_name" {
  description = "Name of the Key Validator Lambda function."
  value       = aws_lambda_function.key_validator.function_name
}
