# S3 Bucket for Encrypted Messages and other application data

resource "aws_s3_bucket" "primary_bucket" {
  bucket = "${var.environment}-${var.bucket_name_prefix}-qkd-data"
  # acl    = "private" # Deprecated, use aws_s3_bucket_ownership_controls and aws_s3_bucket_public_access_block

  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-${var.bucket_name_prefix}-qkd-data"
    }
  )
}

# Bucket Ownership Controls: Recommended for new buckets
resource "aws_s3_bucket_ownership_controls" "primary_bucket_ownership" {
  bucket = aws_s3_bucket.primary_bucket.id
  rule {
    object_ownership = "BucketOwnerEnforced" # Disables ACLs, recommended
  }
}

# Public Access Block: Essential for security
resource "aws_s3_bucket_public_access_block" "primary_bucket_public_access" {
  bucket = aws_s3_bucket.primary_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Versioning Configuration
resource "aws_s3_bucket_versioning" "primary_bucket_versioning" {
  bucket = aws_s3_bucket.primary_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Server-Side Encryption Configuration
resource "aws_s3_bucket_server_side_encryption_configuration" "primary_bucket_sse" {
  bucket = aws_s3_bucket.primary_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true # Recommended for cost savings and performance
  }
}

# Bucket Policy: Enforce encryption and deny HTTP (example)
data "aws_iam_policy_document" "primary_bucket_policy_doc" {
  statement {
    sid    = "DenyIncorrectEncryptionHeader"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions = ["s3:PutObject"]
    resources = [
      "${aws_s3_bucket.primary_bucket.arn}/*",
    ]
    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["aws:kms"]
    }
  }

  statement {
    sid    = "DenyUnEncryptedObjectUploads"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions = ["s3:PutObject"]
    resources = [
      "${aws_s3_bucket.primary_bucket.arn}/*",
    ]
    condition {
      test     = "Null"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["true"]
    }
  }

  statement {
    sid    = "DenyHTTP"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions = ["s3:*"] # Apply to all S3 actions
    resources = [
      aws_s3_bucket.primary_bucket.arn,
      "${aws_s3_bucket.primary_bucket.arn}/*",
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
  # Add other statements as needed, e.g., for Lambda access
}

resource "aws_s3_bucket_policy" "primary_bucket_policy" {
  bucket = aws_s3_bucket.primary_bucket.id
  policy = data.aws_iam_policy_document.primary_bucket_policy_doc.json
  depends_on = [aws_s3_bucket_public_access_block.primary_bucket_public_access]
}

# Access Logging Configuration (Optional)
resource "aws_s3_bucket_logging" "primary_bucket_logging" {
  count = var.enable_access_logging ? 1 : 0

  bucket = aws_s3_bucket.primary_bucket.id

  target_bucket = var.s3_access_log_bucket_id
  target_prefix = "log/${var.bucket_name_prefix}-qkd-data/"
}

# Lifecycle Configuration
resource "aws_s3_bucket_lifecycle_configuration" "primary_bucket_lifecycle" {
  bucket = aws_s3_bucket.primary_bucket.id

  rule {
    id     = "log"
    status = "Enabled"

    filter {
      prefix = "log/"
    }

    expiration {
      days = var.lifecycle_log_retention_days # e.g., 90 days for logs
    }
  }

  rule {
    id     = "general"
    status = "Enabled"

    # Example: Transition older versions of objects to Glacier Deep Archive
    noncurrent_version_transition {
      noncurrent_days = var.lifecycle_noncurrent_version_transition_days # e.g., 30 days
      storage_class   = "DEEP_ARCHIVE"
    }

    noncurrent_version_expiration {
      noncurrent_days = var.lifecycle_noncurrent_version_expiration_days # e.g., 365 days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = var.lifecycle_abort_incomplete_multipart_upload_days # e.g., 7 days
    }
  }
  depends_on = [aws_s3_bucket_versioning.primary_bucket_versioning]
}

# CORS Configuration
resource "aws_s3_bucket_cors_configuration" "primary_bucket_cors" {
  count  = length(var.cors_rules) > 0 ? 1 : 0
  bucket = aws_s3_bucket.primary_bucket.id

  dynamic "cors_rule" {
    for_each = var.cors_rules
    content {
      allowed_headers = lookup(cors_rule.value, "allowed_headers", null)
      allowed_methods = lookup(cors_rule.value, "allowed_methods", [])
      allowed_origins = lookup(cors_rule.value, "allowed_origins", [])
      expose_headers  = lookup(cors_rule.value, "expose_headers", null)
      max_age_seconds = lookup(cors_rule.value, "max_age_seconds", null)
    }
  }
  depends_on = [aws_s3_bucket_public_access_block.primary_bucket_public_access]
}
