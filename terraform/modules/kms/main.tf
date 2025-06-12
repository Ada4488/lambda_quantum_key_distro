# KMS Module main.tf

resource "aws_kms_key" "qkd_cmk" {
  description             = "Customer managed key for QKD Simulator project encryption"
  deletion_window_in_days = 10 # Or your preferred value, min 7, max 30
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.kms_key_policy.json

  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-qkd-master-key"
    }
  )
}

# Default KMS key policy that allows root user full access and enables IAM policies to grant further permissions.
data "aws_iam_policy_document" "kms_key_policy" {
  statement {
    sid    = "Enable IAM User Permissions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  # Add other statements as needed, e.g., for specific service roles to use the key.
  # For example, allowing the Lambda execution role to encrypt/decrypt:
  statement {
    sid    = "Allow Lambda to use the key for DynamoDB and S3 (example)"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [var.lambda_exec_role_arn] # Pass the Lambda role ARN to this module
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"] # Refers to this key
    # Optionally, add conditions for services like DynamoDB or S3
    # condition {
    #   test     = "StringEquals"
    #   variable = "kms:ViaService"
    #   values   = ["dynamodb.${var.aws_region}.amazonaws.com", "s3.${var.aws_region}.amazonaws.com"]
    # }
  }
}

data "aws_caller_identity" "current" {}
