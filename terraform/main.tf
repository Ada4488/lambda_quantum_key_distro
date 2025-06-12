module "dynamodb" {
  source = "./modules/dynamodb"

  environment = var.environment
  common_tags = local.common_tags
  kms_key_arn = module.kms.key_arn # Pass KMS key ARN

  # You can override default table names here if needed:
  # qkd_sessions_table_name         = "my-custom-qkd-sessions"
  # eavesdrop_detections_table_name = "my-custom-eavesdrop-detections"
}

module "lambda_functions" {
  source = "./modules/lambda"

  environment                 = var.environment
  lambda_runtime              = var.lambda_runtime
  lambda_exec_role_arn        = aws_iam_role.lambda_exec_role.arn
  qkd_sessions_table_name     = module.dynamodb.qkd_sessions_table_name # Get from dynamodb module output
  # qkd_sessions_table_stream_arn = module.dynamodb.qkd_sessions_table_stream_arn # For eavesdrop_detector
  s3_bucket_name              = module.s3.primary_bucket_id # Get S3 bucket name from s3 module output
  kms_key_arn                 = module.kms.key_arn          # Pass KMS key for Lambda env vars if needed for direct crypto

  common_lambda_env_vars = {
    REGION       = var.aws_region
    ACCOUNT_ID   = data.aws_caller_identity.current.account_id # Assuming you add this data source
    LOG_LEVEL    = "INFO"                                     # Default log level
    POWERTOOLS_SERVICE_NAME = "qkd-simulator"                 # For AWS Lambda Powertools
  }

  common_tags             = local.common_tags
  lambda_source_base_path = "../src/functions"
  dist_path               = "../dist"
}

# KMS Module (Placeholder - to be defined in a future step)
module "kms" {
  source = "./modules/kms"

  environment          = var.environment
  common_tags          = local.common_tags
  lambda_exec_role_arn = aws_iam_role.lambda_exec_role.arn # Pass the Lambda role ARN
  aws_region           = var.aws_region                   # Pass the AWS region
}

module "s3" {
  source = "./modules/s3"

  environment        = var.environment
  common_tags        = local.common_tags
  kms_key_arn        = module.kms.key_arn # Pass KMS key ARN
  bucket_name_prefix = "qkd-sim"          # Example prefix, can be customized

  # Configure access logging if a dedicated logging bucket exists
  # enable_access_logging = true
  # s3_access_log_bucket_id = "my-centralized-s3-access-logs-bucket" 

  # Example CORS rule (adjust as needed for your frontend)
  # cors_rules = [
  #   {
  #     allowed_headers = ["Authorization", "Content-Type", "*"]
  #     allowed_methods = ["GET", "PUT", "POST", "DELETE"]
  #     allowed_origins = ["http://localhost:3000", "https://*.example.com"] # Replace with your frontend domains
  #     expose_headers  = ["ETag"]
  #     max_age_seconds = 3000
  #   }
  # ]
}

# Data source for AWS Account ID
data "aws_caller_identity" "current" {}

# Define common tags as a local variable
locals {
  common_tags = {
    Project     = "quantum-kd-simulator"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags # Use the local common_tags
  }
}