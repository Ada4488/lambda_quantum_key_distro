# IAM roles and policies will be defined here

data "aws_iam_policy_document" "lambda_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_exec_role" {
  name               = "${var.environment}-lambda-execution-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
  tags = {
    Name        = "${var.environment}-lambda-execution-role"
    Project     = "quantum-kd-simulator"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Basic Lambda execution policy: CloudWatch Logs and X-Ray
resource "aws_iam_policy" "lambda_basic_execution_policy" {
  name        = "${var.environment}-lambda-basic-execution-policy"
  description = "Allows Lambda functions to write logs to CloudWatch and send trace data to X-Ray."
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*" # Restrict if specific log group names are known
      },
      {
        Effect = "Allow",
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ],
        Resource = "*" # X-Ray requires "*" for resource
      }
    ]
  })
  tags = {
    Name        = "${var.environment}-lambda-basic-execution-policy"
    Project     = "quantum-kd-simulator"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution_attachment" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_basic_execution_policy.arn
}

# Policy to allow Lambda to read from specific Secrets Manager secrets
resource "aws_iam_policy" "lambda_secrets_manager_read_policy" {
  name        = "${var.environment}-lambda-secrets-manager-read-policy"
  description = "Allows Lambda functions to read specific secrets from AWS Secrets Manager."
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "secretsmanager:GetSecretValue"
        ],
        # It's crucial to scope this down to the specific secret(s) the Lambda needs.
        # Using the ARN from the secrets.tf output.
        Resource = [
          aws_secretsmanager_secret.qkd_app_secrets.arn
        ]
      }
    ]
  })
  tags = {
    Name        = "${var.environment}-lambda-secrets-manager-read-policy"
    Project     = "quantum-kd-simulator"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "lambda_secrets_manager_read_attachment" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_secrets_manager_read_policy.arn
  depends_on = [aws_secretsmanager_secret.qkd_app_secrets] # Ensure secret exists before attaching policy
}

# Placeholder for specific service permissions (DynamoDB, S3, KMS, etc.)
# These will be added as separate policies or inline policies and attached to lambda_exec_role.

# Example: DynamoDB permissions (to be refined)
# resource "aws_iam_policy" "lambda_dynamodb_policy" {
#   name        = "${var.environment}-lambda-dynamodb-policy"
#   description = "Allows Lambda functions to interact with specific DynamoDB tables."
#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Effect = "Allow",
#         Action = [
#           "dynamodb:GetItem",
#           "dynamodb:PutItem",
#           "dynamodb:UpdateItem",
#           "dynamodb:DeleteItem",
#           "dynamodb:Query",
#           "dynamodb:Scan"
#         ],
#         Resource = [
#           module.dynamodb.qkd_sessions_table_arn, # Example, assuming module outputs ARN
#           module.dynamodb.eavesdrop_detections_table_arn # Example
#         ]
#       }
#     ]
#   })
# }

# resource "aws_iam_role_policy_attachment" "lambda_dynamodb_attachment" {
#   role       = aws_iam_role.lambda_exec_role.name
#   policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
# }
