
locals {
  # Ensure the layer name is unique, perhaps by appending a hash of the requirements file
  # For now, we'll use a fixed suffix, but a hash is better for production to force updates when requirements change.
  crypto_layer_name    = "${var.layer_name_prefix}-crypto-layer"
  utilities_layer_name = "${var.layer_name_prefix}-utilities-layer"
}

# Crypto Layer
# ----------------------------------------------------------------------------------------------------------------------
data "archive_file" "crypto_layer_zip" {
  type        = "zip"
  source_dir  = var.crypto_layer_source_path  # Path to the directory containing requirements.txt and built packages
  output_path = "${path.module}/dist/crypto_layer.zip"
}

resource "aws_lambda_layer_version" "crypto_layer" {
  filename            = data.archive_file.crypto_layer_zip.output_path
  layer_name          = local.crypto_layer_name
  source_code_hash    = data.archive_file.crypto_layer_zip.output_base64sha256
  compatible_runtimes = var.compatible_runtimes
  description         = "Lambda layer containing cryptographic libraries."

  # TODO: Add licensing information if required by any of the packages
  # license_info = "GPLv3"

  tags = var.tags
}

# Utilities Layer
# ----------------------------------------------------------------------------------------------------------------------
data "archive_file" "utilities_layer_zip" {
  type        = "zip"
  source_dir  = var.utilities_layer_source_path # Path to the directory containing requirements.txt and built packages
  output_path = "${path.module}/dist/utilities_layer.zip"
}

resource "aws_lambda_layer_version" "utilities_layer" {
  filename            = data.archive_file.utilities_layer_zip.output_path
  layer_name          = local.utilities_layer_name
  source_code_hash    = data.archive_file.utilities_layer_zip.output_base64sha256
  compatible_runtimes = var.compatible_runtimes
  description         = "Lambda layer containing utility libraries like Powertools."

  # TODO: Add licensing information if required by any of the packages

  tags = var.tags
}
