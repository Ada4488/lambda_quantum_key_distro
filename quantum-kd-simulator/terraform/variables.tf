variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "lambda_runtime" {
  description = "Lambda runtime version"
  type        = string
  default     = "python3.11"
}

variable "qkd_key_length" {
  description = "Default quantum key length"
  type        = number
  default     = 128
}

variable "qber_threshold" {
  description = "Quantum Bit Error Rate threshold for eavesdropping detection"
  type        = number
  default     = 0.11
}

# Placeholder for KMS Key ARN if managed centrally
# variable "kms_key_arn" {
#   description = "ARN of the KMS key for encryption"
#   type        = string
# }

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "availability_zones" {
  description = "List of Availability Zones to use"
  type        = list(string)
  # These are common for us-east-1, adjust if using a different region primarily
  default     = ["us-east-1a", "us-east-1b"]
}
