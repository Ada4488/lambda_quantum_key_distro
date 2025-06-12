# VPC, Subnets, Route Tables, Internet Gateway, NAT Gateway, and VPC Endpoints will be defined here.

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.environment}-qkd-vpc"
    Environment = var.environment
    Project     = "quantum-kd-simulator"
    ManagedBy   = "terraform"
  }
}

# Internet Gateway for public subnets
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.environment}-qkd-igw"
    Environment = var.environment
    Project     = "quantum-kd-simulator"
    ManagedBy   = "terraform"
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index % length(var.availability_zones)] # Distribute across AZs
  map_public_ip_on_launch = true # Instances launched in public subnets get a public IP

  tags = {
    Name        = "${var.environment}-qkd-public-subnet-${count.index + 1}"
    Environment = var.environment
    Project     = "quantum-kd-simulator"
    ManagedBy   = "terraform"
    Tier        = "public"
  }
}

# Private Subnets
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index % length(var.availability_zones)] # Distribute across AZs

  tags = {
    Name        = "${var.environment}-qkd-private-subnet-${count.index + 1}"
    Environment = var.environment
    Project     = "quantum-kd-simulator"
    ManagedBy   = "terraform"
    Tier        = "private"
  }
}

# Route Table for Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name        = "${var.environment}-qkd-public-rt"
    Environment = var.environment
    Project     = "quantum-kd-simulator"
    ManagedBy   = "terraform"
  }
}

# Associate Public Subnets with Public Route Table
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Route Table for Private Subnets (initially no outbound internet, NAT Gateway would be added here)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  # No default route to IGW. If NAT Gateway is needed, routes will be added here.
  # For now, only local VPC traffic is routed.

  tags = {
    Name        = "${var.environment}-qkd-private-rt"
    Environment = var.environment
    Project     = "quantum-kd-simulator"
    ManagedBy   = "terraform"
  }
}

# Associate Private Subnets with Private Route Table
resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# --- VPC Gateway Endpoints ---

# S3 Gateway Endpoint
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${var.aws_region}.s3" # Make sure var.aws_region is correctly set
  route_table_ids = concat(
    aws_route_table.public[*].id,
    aws_route_table.private[*].id
  )

  tags = {
    Name        = "${var.environment}-s3-gw-endpoint"
    Environment = var.environment
    Project     = "quantum-kd-simulator"
    ManagedBy   = "terraform"
  }
}

# DynamoDB Gateway Endpoint
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${var.aws_region}.dynamodb" # Make sure var.aws_region is correctly set
  route_table_ids = concat(
    aws_route_table.public[*].id,
    aws_route_table.private[*].id
  )

  tags = {
    Name        = "${var.environment}-dynamodb-gw-endpoint"
    Environment = var.environment
    Project     = "quantum-kd-simulator"
    ManagedBy   = "terraform"
  }
}

# --- VPC Interface Endpoints ---

# Security Group for Interface Endpoints
resource "aws_security_group" "interface_endpoints_sg" {
  name        = "${var.environment}-interface-endpoints-sg"
  description = "Security group for VPC interface endpoints, allows HTTPS from within VPC"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block] # Allow traffic from within the VPC
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # Allow all outbound traffic
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-interface-endpoints-sg"
    Environment = var.environment
    Project     = "quantum-kd-simulator"
    ManagedBy   = "terraform"
  }
}

# Secrets Manager Interface Endpoint
resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type = "Interface"

  subnet_ids = aws_subnet.private[*].id # Typically place interface endpoints in private subnets
  security_group_ids = [
    aws_security_group.interface_endpoints_sg.id
  ]
  private_dns_enabled = true

  tags = {
    Name        = "${var.environment}-secretsmanager-vpce"
    Environment = var.environment
    Project     = "quantum-kd-simulator"
    ManagedBy   = "terraform"
  }
}

# CloudWatch Logs Interface Endpoint
resource "aws_vpc_endpoint" "logs" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type = "Interface"

  subnet_ids = aws_subnet.private[*].id # Place in private subnets
  security_group_ids = [
    aws_security_group.interface_endpoints_sg.id
  ]
  private_dns_enabled = true

  tags = {
    Name        = "${var.environment}-logs-vpce"
    Environment = var.environment
    Project     = "quantum-kd-simulator"
    ManagedBy   = "terraform"
  }
}

# API Gateway (execute-api) Interface Endpoint
resource "aws_vpc_endpoint" "execute_api" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.execute-api"
  vpc_endpoint_type = "Interface"

  subnet_ids = aws_subnet.private[*].id # Place in private subnets
  security_group_ids = [
    aws_security_group.interface_endpoints_sg.id
  ]
  private_dns_enabled = true

  tags = {
    Name        = "${var.environment}-execute-api-vpce"
    Environment = var.environment
    Project     = "quantum-kd-simulator"
    ManagedBy   = "terraform"
  }
}

# Outputs for network resources (can be expanded)
output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of IDs of private subnets"
  value       = aws_subnet.private[*].id
}
