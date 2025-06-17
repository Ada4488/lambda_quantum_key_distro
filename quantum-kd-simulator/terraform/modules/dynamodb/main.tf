resource "aws_dynamodb_table" "qkd_sessions" {
  name         = "${var.environment}-${var.qkd_sessions_table_name}"
  billing_mode = var.billing_mode
  hash_key     = "sessionId"

  attribute {
    name = "sessionId"
    type = "S"
  }

  # TTL attribute
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  # Server-side encryption
  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn # If null, uses AWS owned CMK
  }

  # Point-in-time recovery
  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  # DynamoDB Streams (conditionally enabled)
  dynamic "stream_specification" {
    for_each = var.stream_enabled_qkd_sessions ? [1] : []
    content {
      stream_enabled   = true
      stream_view_type = var.stream_view_type_qkd_sessions
    }
  }

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.environment}-${var.qkd_sessions_table_name}"
      Environment = var.environment
    }
  )
}

resource "aws_dynamodb_table" "eavesdrop_detections" {
  name         = "${var.environment}-${var.eavesdrop_detections_table_name}"
  billing_mode = var.billing_mode
  hash_key     = "sessionId"
  range_key    = "detectionTimestamp"

  attribute {
    name = "sessionId"
    type = "S"
  }

  attribute {
    name = "detectionTimestamp"
    type = "N"
  }

  # TTL attribute (optional, can be added if needed)
  # ttl {
  #   attribute_name = "ttl"
  #   enabled        = true
  # }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn # If null, uses AWS owned CMK
  }

  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.environment}-${var.eavesdrop_detections_table_name}"
      Environment = var.environment
    }
  )
}

# Encryption Metadata Table for Key Validator
resource "aws_dynamodb_table" "encryption_metadata" {
  name         = "${var.environment}-${var.encryption_metadata_table_name}"
  billing_mode = var.billing_mode
  hash_key     = "encryptionId"

  attribute {
    name = "encryptionId"
    type = "S"
  }

  # Optional GSI for querying by session ID
  attribute {
    name = "sessionId"
    type = "S"
  }

  global_secondary_index {
    name     = "SessionIdIndex"
    hash_key = "sessionId"
    projection_type = "ALL"
  }

  # TTL attribute for automatic cleanup
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.environment}-${var.encryption_metadata_table_name}"
      Environment = var.environment
    }
  )
}
