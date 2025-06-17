resource "aws_kms_key" "qkd_key" {
  description             = var.key_description
  deletion_window_in_days = var.key_deletion_window_in_days
  enable_key_rotation     = var.enable_key_rotation

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.environment}-qkd-master-key"
      Environment = var.environment
    }
  )
}

resource "aws_kms_alias" "qkd_key_alias" {
  name          = "${var.environment}-${var.key_alias_name}"
  target_key_id = aws_kms_key.qkd_key.id
}
