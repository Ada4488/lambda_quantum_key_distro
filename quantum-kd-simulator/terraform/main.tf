terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
  backend "s3" {
    bucket = "quantum-kd-terraform-state"
    key    = "quantum-kd-simulator/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "quantum-kd-simulator"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# Lambda Layers Module
module "lambda_layers" {
  source = "./modules/layers"

  layer_name_prefix           = var.project_name
  crypto_layer_source_path    = "${path.root}/../src/layers/crypto-layer/python"    # Adjust if your build process places packages elsewhere
  utilities_layer_source_path = "${path.root}/../src/layers/utilities-layer/python" # Adjust if your build process places packages elsewhere
  compatible_runtimes         = ["python3.9", "python3.10", "python3.11", "python3.12"] # Or specific to your lambda
  tags                        = local.common_tags
}

# Lambda Functions Module
module "lambda_functions" {
  source = "./modules/lambda"

  function_name_prefix = "${var.project_name}-${var.environment}"
  lambda_runtime       = "python3.11" # Or from var.lambda_runtime if defined at root
  lambda_timeout       = var.lambda_timeout
  lambda_memory_size   = var.lambda_memory_size

  dynamodb_table_name = module.dynamodb.qkd_sessions_table_name
  eavesdrop_detections_table_name = module.dynamodb.eavesdrop_detections_table_name
  encryption_metadata_table_name = module.dynamodb.encryption_metadata_table_name
  dynamodb_stream_arn = module.dynamodb.qkd_sessions_stream_arn
  kms_key_arn         = module.kms.key_arn
  crypto_layer_arn    = module.layers.crypto_layer_arn
  utilities_layer_arn = module.layers.utilities_layer_arn

  aws_region     = var.aws_region
  aws_account_id = var.aws_account_id
  common_tags    = local.common_tags

  s3_bucket_name = module.s3_qkd_data.bucket_id # Pass S3 bucket name to lambda module
  sns_topic_arn = module.monitoring.sns_topic_arn # SNS topic for alerts
}

# API Gateway Module
module "api_gateway" {
  source = "./modules/api-gateway"

  api_name             = "${var.project_name}-${var.environment}-api"
  stage_name           = var.environment # or a specific stage name like "v1"
  lambda_invoke_arn    = module.lambda_functions.qkd_simulator_invoke_arn
  lambda_function_name = module.lambda_functions.qkd_simulator_name
  aws_region           = var.aws_region
  aws_account_id       = var.aws_account_id
  common_tags          = local.common_tags

  depends_on = [module.lambda_functions]
}

# DynamoDB Module
module "dynamodb" {
  source = "./modules/dynamodb"
  
  environment = var.environment
  kms_key_arn = module.kms.key_arn # Pass KMS key if needed for DynamoDB encryption via module
  common_tags = local.common_tags # Pass common tags
  # Pass billing mode from root variables
  billing_mode = var.dynamodb_billing_mode
  # Explicitly pass table names if you want to control them from root or keep defaults
  # qkd_sessions_table_name = "qkd-sessions" 
  # eavesdrop_detections_table_name = "eavesdrop-detections"
  # stream_enabled_qkd_sessions = true # Example: enable stream if eavesdrop detector is ready
}

# S3 Module
module "s3_qkd_data" {
  source = "./modules/s3"

  bucket_name = "${var.project_name}-${var.environment}-qkd-data"
  kms_key_arn = module.kms.key_arn # Use the same KMS key for S3 encryption
  common_tags = local.common_tags

  # Configure S3 bucket notification for key-validator function
  lambda_function_arn = module.lambda_functions.key_validator_arn
  notification_filter_prefix = "uploads/"

  # Enable CORS for frontend access
  enable_cors = true
  cors_allowed_origins = ["http://localhost:3000", "https://*.${var.project_name}.com"]

  # Enable lifecycle management
  enable_lifecycle = true
  object_expiration_days = 90

  force_destroy = var.environment != "prod" # Allow destruction in non-prod environments

  depends_on = [module.lambda_functions]
}

# KMS Module (Placeholder - assuming you'll create a KMS module or define KMS key elsewhere)
module "kms" {
  source      = "./modules/kms"
  environment = var.environment
  key_deletion_window_in_days = var.kms_key_deletion_window_in_days
  common_tags = local.common_tags
}

# Monitoring Module
module "monitoring" {
  source = "./modules/monitoring"

  environment           = var.environment
  lambda_function_names = [
    module.lambda_functions.qkd_simulator_name,
    module.lambda_functions.eavesdrop_detector_name,
    module.lambda_functions.key_validator_name
  ]
  api_name              = module.api_gateway.api_id
  log_retention_in_days = 7  # Keep logs for 7 days to minimize costs

  # Enable basic alarms but don't set email endpoint by default (optional)
  enable_alarms        = true
  sns_email_endpoint   = var.sns_email_endpoint  # Set this in terraform.tfvars for alerts

  # For Lambda functions, alert if error rate exceeds 5%
  lambda_error_rate_threshold = 5

  # For API Gateway, alert if p95 latency exceeds 3000ms
  api_response_time_threshold = 3000
}

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}