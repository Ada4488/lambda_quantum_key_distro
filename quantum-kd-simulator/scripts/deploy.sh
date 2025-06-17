#!/bin/bash

# Quantum KD Simulator Deployment Script
# This script deploys the complete infrastructure and Lambda functions

set -e  # Exit on any error

echo "🚀 Quantum KD Simulator Deployment"
echo "=================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
ENVIRONMENT=${1:-dev}
AWS_REGION=${AWS_REGION:-us-east-1}
PROJECT_NAME="quantum-kd-simulator"

print_status "Deploying to environment: $ENVIRONMENT"
print_status "AWS Region: $AWS_REGION"

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if AWS CLI is installed and configured
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed"
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS CLI is not configured or credentials are invalid"
        exit 1
    fi
    
    # Check if Terraform is installed
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed"
        exit 1
    fi
    
    # Check if Python is available
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 is not installed"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Build Lambda layers
build_layers() {
    print_status "Building Lambda layers..."
    
    # Create dist directory
    mkdir -p ../dist
    
    # Build crypto layer
    print_status "Building crypto layer..."
    cd ../src/layers/crypto-layer
    if [ ! -d "python" ]; then
        mkdir -p python
        pip install -r requirements.txt -t python/
    fi
    cd ../../../scripts
    
    # Build utilities layer
    print_status "Building utilities layer..."
    cd ../src/layers/utilities-layer
    if [ ! -d "python" ]; then
        mkdir -p python
        pip install -r requirements.txt -t python/
    fi
    cd ../../../scripts
    
    print_success "Lambda layers built successfully"
}

# Package Lambda functions
package_functions() {
    print_status "Packaging Lambda functions..."
    
    # Package QKD Simulator
    print_status "Packaging QKD Simulator function..."
    cd ../src/functions/qkd-simulator
    if [ -f "../../../dist/qkd-simulator.zip" ]; then
        rm "../../../dist/qkd-simulator.zip"
    fi
    zip -r "../../../dist/qkd-simulator.zip" . -x "*.pyc" "__pycache__/*"
    cd ../../../scripts
    
    # Package Eavesdrop Detector
    print_status "Packaging Eavesdrop Detector function..."
    cd ../src/functions/eavesdrop-detector
    if [ -f "../../../dist/eavesdrop-detector.zip" ]; then
        rm "../../../dist/eavesdrop-detector.zip"
    fi
    zip -r "../../../dist/eavesdrop-detector.zip" . -x "*.pyc" "__pycache__/*"
    cd ../../../scripts
    
    # Package Key Validator
    print_status "Packaging Key Validator function..."
    cd ../src/functions/key-validator
    if [ -f "../../../dist/key-validator.zip" ]; then
        rm "../../../dist/key-validator.zip"
    fi
    zip -r "../../../dist/key-validator.zip" . -x "*.pyc" "__pycache__/*"
    cd ../../../scripts
    
    print_success "Lambda functions packaged successfully"
}

# Deploy infrastructure
deploy_infrastructure() {
    print_status "Deploying infrastructure with Terraform..."
    
    cd ../terraform
    
    # Initialize Terraform
    print_status "Initializing Terraform..."
    terraform init
    
    # Validate configuration
    print_status "Validating Terraform configuration..."
    terraform validate
    
    # Plan deployment
    print_status "Planning Terraform deployment..."
    terraform plan -var="environment=$ENVIRONMENT" -out=tfplan
    
    # Apply deployment
    print_status "Applying Terraform deployment..."
    terraform apply tfplan
    
    # Clean up plan file
    rm -f tfplan
    
    cd ../scripts
    
    print_success "Infrastructure deployed successfully"
}

# Get deployment outputs
get_outputs() {
    print_status "Getting deployment outputs..."
    
    cd ../terraform
    
    # Get API Gateway URL
    API_URL=$(terraform output -raw api_gateway_url 2>/dev/null || echo "Not available")
    
    # Get S3 bucket name
    S3_BUCKET=$(terraform output -raw s3_bucket_name 2>/dev/null || echo "Not available")
    
    # Get DynamoDB table names
    QKD_TABLE=$(terraform output -raw qkd_sessions_table_name 2>/dev/null || echo "Not available")
    DETECTIONS_TABLE=$(terraform output -raw eavesdrop_detections_table_name 2>/dev/null || echo "Not available")
    
    cd ../scripts
    
    echo ""
    echo "📊 Deployment Summary"
    echo "===================="
    echo "Environment: $ENVIRONMENT"
    echo "Region: $AWS_REGION"
    echo "API Gateway URL: $API_URL"
    echo "S3 Bucket: $S3_BUCKET"
    echo "QKD Sessions Table: $QKD_TABLE"
    echo "Detections Table: $DETECTIONS_TABLE"
    echo ""
}

# Test deployment
test_deployment() {
    print_status "Testing deployment..."
    
    # Run basic validation
    if [ -f "./validate_deployment.sh" ]; then
        ./validate_deployment.sh $ENVIRONMENT
    else
        print_warning "Deployment validation script not found"
    fi
}

# Main deployment flow
main() {
    print_status "Starting deployment process..."
    
    check_prerequisites
    build_layers
    package_functions
    deploy_infrastructure
    get_outputs
    test_deployment
    
    print_success "Deployment completed successfully!"
    
    echo ""
    echo "🎉 Next Steps:"
    echo "=============="
    echo "1. Test the API endpoints using the provided URL"
    echo "2. Upload files to the S3 bucket to test encryption"
    echo "3. Monitor CloudWatch logs and metrics"
    echo "4. Set up additional monitoring and alerts as needed"
    echo ""
    echo "📚 Documentation:"
    echo "• API Documentation: See docs/api.md"
    echo "• Testing Guide: See TESTING.md"
    echo "• Architecture: See docs/architecture.md"
}

# Handle script arguments
case "${1:-deploy}" in
    "deploy")
        main
        ;;
    "destroy")
        print_warning "Destroying infrastructure..."
        cd ../terraform
        terraform destroy -var="environment=$ENVIRONMENT"
        cd ../scripts
        print_success "Infrastructure destroyed"
        ;;
    "plan")
        print_status "Planning deployment..."
        cd ../terraform
        terraform plan -var="environment=$ENVIRONMENT"
        cd ../scripts
        ;;
    *)
        echo "Usage: $0 [deploy|destroy|plan] [environment]"
        echo "  deploy  - Deploy the infrastructure (default)"
        echo "  destroy - Destroy the infrastructure"
        echo "  plan    - Show deployment plan"
        echo ""
        echo "Environment defaults to 'dev' if not specified"
        exit 1
        ;;
esac
