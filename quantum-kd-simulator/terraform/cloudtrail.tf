# AWS CloudTrail and S3 bucket for logs will be defined here

# S3 bucket for CloudTrail logs
resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket = "${var.environment}-qkd-cloudtrail-logs-${data.aws_caller_identity.current.account_id}" # Unique bucket name

  tags = {
    Name        = "${var.environment}-qkd-cloudtrail-logs"
    Environment = var.environment
    Project     = "quantum-kd-simulator"
    ManagedBy   = "terraform"
  }
}

# Policy for the CloudTrail S3 bucket
data "aws_iam_policy_document" "cloudtrail_s3_policy" {
  statement {
    sid = "AWSCloudTrailAclCheck"
    actions = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.cloudtrail_logs.arn]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }

  statement {
    sid = "AWSCloudTrailWrite"
    actions = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.cloudtrail_logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

resource "aws_s3_bucket_policy" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id
  policy = data.aws_iam_policy_document.cloudtrail_s3_policy.json
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail_logs_sse" {
  bucket = aws_s3_bucket.cloudtrail_logs.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail_logs_public_access" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CloudWatch Logs group for CloudTrail
resource "aws_cloudwatch_log_group" "cloudtrail_log_group" {
  name              = "/aws/cloudtrail/${var.environment}-qkd-trail"
  retention_in_days = 90 # Adjust as needed

  tags = {
    Name        = "${var.environment}-qkd-cloudtrail-cw-logs"
    Environment = var.environment
    Project     = "quantum-kd-simulator"
    ManagedBy   = "terraform"
  }
}

# IAM Role for CloudTrail to write to CloudWatch Logs
resource "aws_iam_role" "cloudtrail_cw_role" {
  name = "${var.environment}-qkd-cloudtrail-cw-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
  tags = {
    Name        = "${var.environment}-qkd-cloudtrail-cw-role"
    Environment = var.environment
    Project     = "quantum-kd-simulator"
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_policy" "cloudtrail_cw_policy" {
  name   = "${var.environment}-qkd-cloudtrail-cw-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "${aws_cloudwatch_log_group.cloudtrail_log_group.arn}:*"
      }
    ]
  })
  tags = {
    Name        = "${var.environment}-qkd-cloudtrail-cw-policy"
    Environment = var.environment
    Project     = "quantum-kd-simulator"
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "cloudtrail_cw_attachment" {
  role       = aws_iam_role.cloudtrail_cw_role.name
  policy_arn = aws_iam_policy.cloudtrail_cw_policy.arn
}

# Data source for current AWS account ID
data "aws_caller_identity" "current" {}

# CloudTrail Trail
resource "aws_cloudtrail" "main_trail" {
  name                          = "${var.environment}-qkd-management-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.id
  s3_key_prefix                 = "AWSLogs"
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail_log_group.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_cw_role.arn

  # Enable for data events if needed (e.g., S3 object-level logging, Lambda invocations)
  # event_selector {
  #   read_write_type           = "All"
  #   include_management_events = true
  #
  #   data_resource {
  #     type = "AWS::S3::Object"
  #     values = ["arn:aws:s3:::"] # Log data events for all S3 buckets; refine as needed
  #   }
  # }
  #
  # event_selector {
  #   read_write_type           = "All"
  #   include_management_events = true # Management events are still included
  #
  #   data_resource {
  #     type = "AWS::Lambda::Function"
  #     values = ["arn:aws:lambda"] # Log data events for all Lambda functions; refine as needed
  #   }
  # }

  tags = {
    Name        = "${var.environment}-qkd-main-trail"
    Environment = var.environment
    Project     = "quantum-kd-simulator"
    ManagedBy   = "terraform"
  }
}

output "cloudtrail_s3_bucket_name" {
  description = "Name of the S3 bucket for CloudTrail logs"
  value       = aws_s3_bucket.cloudtrail_logs.bucket
}

output "cloudtrail_log_group_name" {
  description = "Name of the CloudWatch Logs group for CloudTrail"
  value       = aws_cloudwatch_log_group.cloudtrail_log_group.name
}
