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
  
  environment         = var.environment
  dynamodb_table_name = module.dynamodb.table_name # Assuming dynamodb module outputs table_name
  s3_bucket_name     = module.s3.bucket_name      # Assuming s3 module outputs bucket_name
  kms_key_arn        = module.kms.key_arn         # Assuming a kms module or variable for kms_key_arn

  # Add layer ARNs
  crypto_layer_arn    = module.lambda_layers.crypto_layer_version_arn
  utilities_layer_arn = module.lambda_layers.utilities_layer_version_arn
}

# API Gateway Module
module "api_gateway" {
  source = "./modules/api-gateway"
  
  environment             = var.environment
  qkd_simulator_arn      = module.lambda_functions.qkd_simulator_arn
  key_validator_arn      = module.lambda_functions.key_validator_arn
  # cognito_user_pool_arn  = module.cognito.user_pool_arn # Assuming a cognito module
}

# DynamoDB Module
module "dynamodb" {
  source = "./modules/dynamodb"
  
  environment = var.environment
  # kms_key_arn = module.kms.key_arn # Pass KMS key if needed for DynamoDB encryption via module
}

# S3 Module
module "s3" {
  source = "./modules/s3"
  
  environment = var.environment
  # kms_key_arn = module.kms.key_arn # Pass KMS key if needed for S3 encryption via module
}

# KMS Module (Placeholder - assuming you'll create a KMS module or define KMS key elsewhere)
# module "kms" {
#   source = "./modules/kms" # Example path
#   environment = var.environment
# }

# Monitoring Module
module "monitoring" {
  source = "./modules/monitoring"
  
  environment        = var.environment
  lambda_function_names = [
    module.lambda_functions.qkd_simulator_name,
    module.lambda_functions.eavesdrop_detector_name,
    module.lambda_functions.key_validator_name
  ]
  api_gateway_id = module.api_gateway.api_id
}