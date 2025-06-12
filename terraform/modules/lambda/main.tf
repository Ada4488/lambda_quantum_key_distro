# Lambda module main.tf
# This file will contain the AWS Lambda function resources,
# IAM roles specific to these lambdas (if not using a general one from root),
# event source mappings, and other related configurations.

data "archive_file" "qkd_simulator_zip" {
  type        = "zip"
  source_dir  = "${path.module}/${var.lambda_source_base_path}/qkd-simulator/"
  output_path = "${path.module}/${var.dist_path}/qkd-simulator.zip"
}

resource "aws_lambda_function" "qkd_simulator" {
  filename         = data.archive_file.qkd_simulator_zip.output_path
  source_code_hash = data.archive_file.qkd_simulator_zip.output_base64sha256
  function_name    = "${var.environment}-${var.qkd_simulator_function_name}"
  role             = var.lambda_exec_role_arn
  handler          = "handler.lambda_handler"
  runtime          = var.lambda_runtime
  timeout          = 300
  memory_size      = 512

  environment {
    variables = merge(
      var.common_lambda_env_vars,
      {
        DYNAMODB_TABLE_NAME = var.qkd_sessions_table_name
      }
    )
  }

  tracing_config {
    mode = "Active"
  }

  tags = merge(
    var.common_tags,
    {
      Name     = "${var.environment}-${var.qkd_simulator_function_name}"
      Function = "qkd-simulator"
    }
  )

  depends_on = [data.archive_file.qkd_simulator_zip]
}

# Note: The actual zipping and deployment strategy needs to be finalized.
# The above data.archive_file is one way. Another is to pre-zip and upload to S3,
# then reference the S3 object in the aws_lambda_function resource.
# For CI/CD, a build step would typically handle zipping.
