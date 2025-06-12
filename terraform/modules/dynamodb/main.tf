resource "aws_dynamodb_table" "qkd_sessions" {
  name         = "${var.environment}-${var.qkd_sessions_table_name}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "session_id"

  attribute {
    name = "session_id"
    type = "S"
  }

  # Other attributes (alice_bits, bob_bits, etc.) are schemaless and don't need to be defined here
  # unless they are part of a key or index.

  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES" # For eavesdrop-detector Lambda

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn # Use customer-managed KMS key
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-${var.qkd_sessions_table_name}"
    }
  )
}

resource "aws_dynamodb_table" "eavesdrop_detections" {
  name         = "${var.environment}-${var.eavesdrop_detections_table_name}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "session_id"
  range_key    = "detection_timestamp"

  attribute {
    name = "session_id"
    type = "S"
  }

  attribute {
    name = "detection_timestamp"
    type = "N"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn # Use customer-managed KMS key
  }

  point_in_time_recovery {
    enabled = true # Best practice
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-${var.eavesdrop_detections_table_name}"
    }
  )
}
