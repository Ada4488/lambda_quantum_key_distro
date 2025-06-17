data "archive_file" "qkd_simulator_zip" {
  type        = "zip"
  source_dir  = "../../src/functions/qkd-simulator/"
  output_path = "../../.terraform/archives/qkd-simulator.zip"
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "${var.function_name_prefix}-qkd-simulator-exec-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
  tags = var.common_tags
}

resource "aws_iam_policy" "lambda_dynamodb_policy" {
  name        = "${var.function_name_prefix}-qkd-simulator-dynamodb-policy"
  description = "IAM policy for Lambda to access the QKD sessions DynamoDB table"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:dynamodb:${var.aws_region}:${var.aws_account_id}:table/${var.dynamodb_table_name}"
      }
    ]
  })
  tags = var.common_tags
}

resource "aws_iam_policy" "lambda_kms_policy" {
  name        = "${var.function_name_prefix}-qkd-simulator-kms-policy"
  description = "IAM policy for Lambda to use the KMS key for encryption/decryption"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Effect   = "Allow"
        Resource = var.kms_key_arn
      }
    ]
  })
  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb_attachment" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_kms_attachment" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_kms_policy.arn
}

resource "aws_lambda_function" "qkd_simulator" {
  function_name = "${var.function_name_prefix}-qkd-simulator"
  handler       = "handler.lambda_handler" # Assuming the handler function in handler.py is lambda_handler
  runtime       = var.lambda_runtime
  role          = aws_iam_role.lambda_exec_role.arn
  memory_size   = var.lambda_memory_size
  timeout       = var.lambda_timeout

  filename         = data.archive_file.qkd_simulator_zip.output_path
  source_code_hash = data.archive_file.qkd_simulator_zip.output_base64sha256

  layers = [
    var.crypto_layer_arn,
    var.utilities_layer_arn
  ]

  environment {
    variables = {
      DYNAMODB_TABLE = var.dynamodb_table_name
      KMS_KEY_ARN    = var.kms_key_arn
      POWERTOOLS_SERVICE_NAME = "qkd-simulator"
      LOG_LEVEL        = "INFO"
    }
  }

  tracing_config {
    mode = "Active" # Enable AWS X-Ray tracing
  }

  tags = merge(var.common_tags, {
    Name = "${var.function_name_prefix}-qkd-simulator"
  })

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_iam_role_policy_attachment.lambda_dynamodb_attachment,
    aws_iam_role_policy_attachment.lambda_kms_attachment
  ]
}

# Packaging the eavesdrop-detector Lambda function
data "archive_file" "eavesdrop_detector_zip" {
  type        = "zip"
  source_dir  = "../../src/functions/eavesdrop-detector/" # Path to the function code
  output_path = "../../dist/eavesdrop-detector.zip"
}

# Eavesdrop Detector Lambda Function
resource "aws_lambda_function" "eavesdrop_detector" {
  function_name = "${var.function_name_prefix}-eavesdrop-detector"
  handler       = "handler.lambda_handler"
  runtime       = var.lambda_runtime
  role          = aws_iam_role.lambda_exec_role.arn

  filename         = data.archive_file.eavesdrop_detector_zip.output_path
  source_code_hash = data.archive_file.eavesdrop_detector_zip.output_base64sha256

  layers = [
    var.crypto_layer_arn,
    var.utilities_layer_arn
  ]

  environment {
    variables = {
      EAVESDROP_DETECTIONS_TABLE = var.eavesdrop_detections_table_name
      ALERTS_SNS_TOPIC_ARN       = var.sns_topic_arn # Optional, can be empty
      POWERTOOLS_SERVICE_NAME     = "eavesdrop-detector"
      LOG_LEVEL                   = "INFO"
    }
  }

  timeout     = var.lambda_timeout
  memory_size = var.lambda_memory_size

  tracing_config {
    mode = "Active" # Enable X-Ray tracing
  }

  tags = merge(var.common_tags, {
    Name = "${var.function_name_prefix}-eavesdrop-detector"
  })

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_iam_role_policy_attachment.lambda_dynamodb_attachment,
    aws_iam_role_policy_attachment.lambda_kms_attachment
  ]
}

# Event Source Mapping for DynamoDB Streams to trigger eavesdrop-detector
resource "aws_lambda_event_source_mapping" "dynamodb_stream" {
  count             = var.dynamodb_stream_arn != null ? 1 : 0
  event_source_arn  = var.dynamodb_stream_arn
  function_name     = aws_lambda_function.eavesdrop_detector.function_name
  starting_position = "LATEST"
  batch_size        = 10 # Process 10 records at a time
  enabled           = true

  # Optional configuration for better reliability and performance
  maximum_retry_attempts       = 3
  maximum_record_age_in_seconds = 60 # Only process fresh records
  parallelization_factor       = 1 # Number of batches to process in parallel per shard
}

# Packaging the key-validator Lambda function
data "archive_file" "key_validator_zip" {
  type        = "zip"
  source_dir  = "../../src/functions/key-validator/" # Path to the function code
  output_path = "../../dist/key-validator.zip"
}

# Key Validator Lambda Function
resource "aws_lambda_function" "key_validator" {
  function_name = "${var.function_name_prefix}-key-validator"
  handler       = "handler.lambda_handler"
  runtime       = var.lambda_runtime
  role          = aws_iam_role.lambda_exec_role.arn

  filename         = data.archive_file.key_validator_zip.output_path
  source_code_hash = data.archive_file.key_validator_zip.output_base64sha256

  layers = [
    var.crypto_layer_arn,
    var.utilities_layer_arn
  ]

  environment {
    variables = {
      QKD_SESSIONS_TABLE        = var.dynamodb_table_name
      ENCRYPTION_METADATA_TABLE = var.encryption_metadata_table_name
      KMS_KEY_ARN               = var.kms_key_arn
      OUTPUT_BUCKET             = var.s3_bucket_name
      POWERTOOLS_SERVICE_NAME   = "key-validator"
      LOG_LEVEL                 = "INFO"
    }
  }

  timeout     = var.lambda_timeout
  memory_size = var.lambda_memory_size

  tracing_config {
    mode = "Active" # Enable X-Ray tracing
  }

  tags = merge(var.common_tags, {
    Name = "${var.function_name_prefix}-key-validator"
  })

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_iam_role_policy_attachment.lambda_dynamodb_attachment,
    aws_iam_role_policy_attachment.lambda_kms_attachment,
    aws_iam_role_policy_attachment.lambda_s3_attachment
  ]
}

# S3 permissions for Lambda (needed for key-validator)
resource "aws_iam_policy" "lambda_s3_policy" {
  name        = "${var.function_name_prefix}-lambda-s3-policy"
  description = "IAM policy for Lambda to access the S3 bucket"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:HeadObject",
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = [
          "arn:aws:s3:::${var.s3_bucket_name}",
          "arn:aws:s3:::${var.s3_bucket_name}/*"
        ]
      }
    ]
  })
  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "lambda_s3_attachment" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_s3_policy.arn
}

# Create the S3 event trigger for key-validator function
resource "aws_lambda_permission" "allow_bucket" {
  count         = var.s3_bucket_name != null ? 1 : 0
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.key_validator.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${var.s3_bucket_name}"
}