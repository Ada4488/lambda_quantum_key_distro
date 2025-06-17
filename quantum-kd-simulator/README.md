# Quantum Key Distribution Simulator

A comprehensive AWS-based simulation of quantum key distribution using the BB84 protocol, featuring eavesdropping detection and secure file encryption capabilities.

## 🎯 Overview

This project implements a complete quantum key distribution (QKD) system simulation that demonstrates:

- **BB84 Protocol Implementation**: Quantum bit generation, basis reconciliation, error correction, and privacy amplification
- **Eavesdropping Detection**: Statistical analysis of quantum bit error rates (QBER) to detect potential security breaches
- **Secure File Encryption**: AES-256-GCM encryption using quantum-derived keys
- **Real-time Monitoring**: CloudWatch metrics, alarms, and security dashboards
- **Scalable Infrastructure**: Serverless AWS architecture with auto-scaling capabilities

## 🏗️ Architecture

### Core Components

1. **QKD Simulator Lambda** - Implements the BB84 protocol
2. **Eavesdrop Detector Lambda** - Analyzes QBER for security threats
3. **Key Validator Lambda** - Handles file encryption/decryption
4. **API Gateway** - RESTful API endpoints
5. **DynamoDB** - Session and detection data storage
6. **S3** - File storage and processing triggers
7. **CloudWatch** - Monitoring and alerting

### Technology Stack

- **Backend**: Python 3.11, AWS Lambda, API Gateway
- **Storage**: DynamoDB, S3
- **Security**: KMS, IAM, VPC endpoints
- **Monitoring**: CloudWatch, SNS
- **Infrastructure**: Terraform
- **Frontend**: React.js (optional)

## 🚀 Quick Start

### Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.0
- Python 3.11+
- Node.js 16+ (for frontend)
- Docker (for local testing)

### 1. Clone and Setup

```bash
git clone <repository-url>
cd quantum-kd-simulator

# Set up Python virtual environment
python -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate

# Install development dependencies
pip install -r requirements-dev.txt
```

### 2. Configure Deployment

```bash
# Copy and customize Terraform variables
cp terraform/terraform.tfvars.example terraform/terraform.tfvars

# Edit terraform.tfvars with your AWS account details
vim terraform/terraform.tfvars
```

### 3. Deploy Infrastructure

```bash
# Run the deployment script
./scripts/deploy.sh

# Or deploy manually
cd terraform
terraform init
terraform plan
terraform apply
```

### 4. Test the System

```bash
# Run comprehensive tests
./scripts/run_tests.sh

# Validate deployment
./scripts/validate_deployment.sh dev
```

## 📚 Documentation

- [**Testing Guide**](TESTING.md) - Comprehensive testing instructions
- [**API Documentation**](docs/api.md) - REST API reference
- [**Architecture Guide**](docs/architecture.md) - System design details
- [**Security Guide**](docs/security.md) - Security implementation
- [**Deployment Guide**](docs/deployment.md) - Production deployment

## 🧪 Testing

### Local Testing

```bash
# Set up local testing environment
./scripts/setup_local_testing.sh

# Start LocalStack for AWS simulation
docker-compose -f docker-compose.localstack.yml up -d

# Run all tests
./scripts/run_tests.sh
```

### Test Categories

- **Unit Tests**: Individual component testing
- **Integration Tests**: End-to-end workflow testing
- **Security Tests**: Vulnerability scanning
- **Performance Tests**: Load and benchmark testing
- **Infrastructure Tests**: Terraform validation

## 🔐 Security Features

### Quantum Security
- BB84 protocol implementation with polarization states
- Quantum bit error rate (QBER) monitoring
- Statistical eavesdropping detection
- Secure random number generation

### Classical Security
- AES-256-GCM encryption
- KMS key management
- IAM least-privilege access
- VPC endpoints for private communication
- WAF protection for API Gateway

### Monitoring & Alerting
- Real-time QBER monitoring
- Automated eavesdropping alerts
- CloudWatch dashboards
- SNS notifications for security events

## 📊 API Endpoints

### QKD Operations
```
POST /api/v1/qkd/generate    # Generate quantum key
GET  /api/v1/qkd/session/{id} # Get session details
GET  /api/v1/health          # Health check
```

### Example Usage

```bash
# Generate a quantum key
curl -X POST https://your-api-url/api/v1/qkd/generate \
  -H "Content-Type: application/json" \
  -d '{
    "target_key_length": 128,
    "channel_error_rate": 0.01
  }'
```

## 🎛️ Configuration

### Environment Variables

```bash
# Lambda Functions
DYNAMODB_TABLE_NAME=qkd-sessions-table
KMS_KEY_ARN=arn:aws:kms:region:account:key/key-id
POWERTOOLS_SERVICE_NAME=qkd-simulator

# Eavesdrop Detector
EAVESDROP_DETECTIONS_TABLE=eavesdrop-detections-table
ALERTS_SNS_TOPIC_ARN=arn:aws:sns:region:account:topic-name

# Key Validator
QKD_SESSIONS_TABLE=qkd-sessions-table
ENCRYPTION_METADATA_TABLE=encryption-metadata-table
OUTPUT_BUCKET=qkd-encrypted-files
```

### Terraform Variables

Key variables in `terraform.tfvars`:

```hcl
aws_region     = "us-east-1"
environment    = "dev"
project_name   = "quantum-kd-simulator"
aws_account_id = "123456789012"

# Performance tuning
lambda_memory_size = 512
lambda_timeout     = 300

# Security settings
qber_threshold = 0.11
sns_email_endpoint = "admin@example.com"
```

## 📈 Monitoring

### CloudWatch Metrics

- `QBERValue` - Quantum bit error rate
- `EavesdropDetections` - Security breach count
- `KeyGenerations` - Successful key generations
- `FilesEncrypted` - File encryption operations

### Alarms

- High QBER detection
- Lambda function errors
- API Gateway latency
- DynamoDB throttling

## 🔧 Development

### Project Structure

```
quantum-kd-simulator/
├── src/
│   ├── functions/          # Lambda functions
│   ├── layers/            # Lambda layers
│   ├── shared/            # Shared utilities
│   └── tests/             # Test files
├── terraform/             # Infrastructure code
├── frontend/              # React application
├── scripts/               # Deployment scripts
└── docs/                  # Documentation
```

### Adding New Features

1. Implement Lambda function in `src/functions/`
2. Add Terraform resources in `terraform/modules/`
3. Update main Terraform configuration
4. Add comprehensive tests
5. Update documentation

## 🚨 Troubleshooting

### Common Issues

1. **Lambda timeout errors**: Increase memory/timeout in Terraform
2. **DynamoDB throttling**: Switch to on-demand billing
3. **KMS access denied**: Check IAM permissions
4. **API Gateway CORS**: Update CORS configuration

### Debug Commands

```bash
# Check Lambda logs
aws logs tail /aws/lambda/function-name --follow

# Test API endpoints
curl -v https://your-api-url/api/v1/health

# Validate Terraform
terraform validate && terraform plan
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Add comprehensive tests
4. Update documentation
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- BB84 Protocol by Bennett and Brassard (1984)
- AWS Lambda Powertools team
- Quantum cryptography research community

## 📞 Support

For questions and support:
- Create an issue in the repository
- Check the [documentation](docs/)
- Review the [testing guide](TESTING.md)

---

**⚠️ Disclaimer**: This is a simulation for educational and demonstration purposes. Not suitable for production cryptographic applications.
