variable "crypto_layer_arn" {
  description = "ARN of the Crypto Lambda Layer."
  type        = string
}

variable "utilities_layer_arn" {
  description = "ARN of the Utilities Lambda Layer."
  type        = string
}

resource "aws_lambda_function" "qkd_simulator" {
  filename      = data.archive_file.qkd_simulator_zip.output_path
  function_name = "${var.function_name_prefix}-qkd-simulator"
  role          = var.lambda_exec_role_arn
  handler       = "handler.lambda_handler" # For Python
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size

  source_code_hash = data.archive_file.qkd_simulator_zip.output_base64sha256

  layers = [
    var.crypto_layer_arn,
    var.utilities_layer_arn
  ]

  environment {
    # ... existing environment variables ...
  }

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.function_name_prefix}-qkd-simulator"
      Environment = var.environment
    }
  )
}