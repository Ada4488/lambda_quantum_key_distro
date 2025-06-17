#!/bin/bash

# Setup script for local testing environment
# This script sets up LocalStack for AWS service simulation

set -e

echo "🚀 Setting up Local Testing Environment"
echo "======================================="

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker first."
    exit 1
fi

print_status "Docker is running ✅"

# Create docker-compose file for LocalStack
print_status "Creating LocalStack configuration..."
cat > docker-compose.localstack.yml << EOF
version: '3.8'

services:
  localstack:
    container_name: qkd-localstack
    image: localstack/localstack:latest
    ports:
      - "4566:4566"            # LocalStack Gateway
      - "4510-4559:4510-4559"  # External services port range
    environment:
      - DEBUG=1
      - LAMBDA_EXECUTOR=docker
      - DOCKER_HOST=unix:///var/run/docker.sock
      - SERVICES=lambda,dynamodb,kms,s3,apigateway,iam,cloudformation
      - DATA_DIR=/tmp/localstack/data
      - PERSISTENCE=1
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock"
      - "./localstack-data:/tmp/localstack"
    networks:
      - qkd-network

networks:
  qkd-network:
    driver: bridge
EOF

# Create LocalStack initialization script
print_status "Creating LocalStack initialization script..."
cat > scripts/init_localstack.sh << 'EOF'
#!/bin/bash

# Wait for LocalStack to be ready
echo "Waiting for LocalStack to be ready..."
while ! curl -s http://localhost:4566/health | grep -q "running"; do
    sleep 2
done

echo "LocalStack is ready! 🎉"

# Set AWS CLI to use LocalStack
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
export AWS_ENDPOINT_URL=http://localhost:4566

# Create DynamoDB table
echo "Creating DynamoDB table..."
aws dynamodb create-table \
    --table-name qkd-sessions-table \
    --attribute-definitions \
        AttributeName=session_id,AttributeType=S \
    --key-schema \
        AttributeName=session_id,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --endpoint-url http://localhost:4566

# Create KMS key
echo "Creating KMS key..."
KMS_KEY=$(aws kms create-key \
    --description "QKD Simulator Test Key" \
    --endpoint-url http://localhost:4566 \
    --query 'KeyMetadata.KeyId' \
    --output text)

echo "KMS Key ID: $KMS_KEY"

# Create S3 bucket for Terraform state
echo "Creating S3 bucket for Terraform state..."
aws s3 mb s3://quantum-kd-terraform-state \
    --endpoint-url http://localhost:4566

# Save environment variables for testing
cat > .env.local << EOL
AWS_ACCESS_KEY_ID=test
AWS_SECRET_ACCESS_KEY=test
AWS_DEFAULT_REGION=us-east-1
AWS_ENDPOINT_URL=http://localhost:4566
DYNAMODB_TABLE_NAME=qkd-sessions-table
KMS_KEY_ARN=arn:aws:kms:us-east-1:000000000000:key/$KMS_KEY
EOL

echo "✅ LocalStack setup complete!"
echo "Environment variables saved to .env.local"
EOF

chmod +x scripts/init_localstack.sh

# Create test runner for local environment
print_status "Creating local test runner..."
cat > scripts/test_local.sh << 'EOF'
#!/bin/bash

# Test runner for local environment with LocalStack

set -e

echo "🧪 Running Local Tests with LocalStack"
echo "======================================"

# Load local environment variables
if [ -f .env.local ]; then
    export $(cat .env.local | xargs)
fi

# Activate virtual environment
source .venv/bin/activate

# Run tests against LocalStack
echo "Running unit tests..."
pytest src/tests/test_qkd_simulator.py -v

echo "Running integration tests against LocalStack..."
pytest src/tests/test_integration.py -v -m integration

echo "✅ Local tests completed!"
EOF

chmod +x scripts/test_local.sh

# Create manual testing script
print_status "Creating manual testing script..."
cat > scripts/manual_test.py << 'EOF'
#!/usr/bin/env python3
"""
Manual testing script for QKD Simulator.
This script allows you to test the Lambda function manually.
"""

import json
import sys
import os
import requests
import boto3
from datetime import datetime

# Add the function path for imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../src/functions/qkd-simulator'))

def test_lambda_locally():
    """Test the Lambda function locally."""
    print("🧪 Testing Lambda Function Locally")
    print("==================================")
    
    # Import the handler
    from handler import lambda_handler
    
    # Mock Lambda context
    class MockContext:
        def __init__(self):
            self.function_name = "qkd-simulator"
            self.aws_request_id = "test-request-id"
            self.remaining_time_in_millis = 30000
    
    # Test cases
    test_cases = [
        {
            "name": "Small key test",
            "body": {"target_key_length": 32, "channel_error_rate": 0.01}
        },
        {
            "name": "Medium key test", 
            "body": {"target_key_length": 64, "channel_error_rate": 0.05}
        },
        {
            "name": "Large key test",
            "body": {"target_key_length": 128, "channel_error_rate": 0.02}
        },
        {
            "name": "High error rate test",
            "body": {"target_key_length": 32, "channel_error_rate": 0.2}
        }
    ]
    
    for i, test_case in enumerate(test_cases, 1):
        print(f"\n{i}. {test_case['name']}")
        print("-" * 40)
        
        event = {"body": test_case["body"]}
        context = MockContext()
        
        try:
            start_time = datetime.now()
            response = lambda_handler(event, context)
            end_time = datetime.now()
            
            execution_time = (end_time - start_time).total_seconds()
            
            print(f"Status Code: {response['statusCode']}")
            print(f"Execution Time: {execution_time:.2f}s")
            
            if response['statusCode'] == 200:
                body = json.loads(response['body'])
                print(f"Session ID: {body.get('session_id', 'N/A')}")
                print(f"Key Length: {len(body.get('alice_final_key', []))}")
                print(f"QBER: {body.get('qber', 'N/A'):.4f}")
                print(f"Key Rate: {body.get('key_generation_rate', 'N/A')} bits/s")
                
                if body.get('eavesdropping_detected'):
                    print("⚠️  Eavesdropping detected!")
                else:
                    print("✅ Secure key generated")
            else:
                print(f"❌ Error: {response['body']}")
                
        except Exception as e:
            print(f"❌ Exception: {str(e)}")

def test_api_endpoint():
    """Test the API endpoint if deployed."""
    print("\n🌐 Testing API Endpoint")
    print("======================")
    
    # This would be your actual API Gateway URL
    api_url = "https://your-api-id.execute-api.us-east-1.amazonaws.com/dev/qkd-simulate"
    
    test_payload = {
        "target_key_length": 64,
        "channel_error_rate": 0.05
    }
    
    try:
        response = requests.post(
            api_url,
            json=test_payload,
            headers={"Content-Type": "application/json"},
            timeout=30
        )
        
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.text}")
        
    except requests.exceptions.RequestException as e:
        print(f"❌ API test failed: {str(e)}")
        print("Note: Update the api_url variable with your actual API Gateway URL")

def test_aws_resources():
    """Test AWS resources connectivity."""
    print("\n☁️  Testing AWS Resources")
    print("========================")
    
    # Load environment variables
    if os.path.exists('.env.local'):
        with open('.env.local', 'r') as f:
            for line in f:
                if '=' in line:
                    key, value = line.strip().split('=', 1)
                    os.environ[key] = value
    
    try:
        # Test DynamoDB
        dynamodb = boto3.client('dynamodb', endpoint_url=os.environ.get('AWS_ENDPOINT_URL'))
        tables = dynamodb.list_tables()
        print(f"✅ DynamoDB connected. Tables: {tables['TableNames']}")
        
        # Test KMS
        kms = boto3.client('kms', endpoint_url=os.environ.get('AWS_ENDPOINT_URL'))
        keys = kms.list_keys()
        print(f"✅ KMS connected. Keys found: {len(keys['Keys'])}")
        
    except Exception as e:
        print(f"❌ AWS resources test failed: {str(e)}")

if __name__ == "__main__":
    print("🔬 QKD Simulator Manual Testing")
    print("==============================")
    
    # Set up environment for local testing
    os.environ.setdefault('DYNAMODB_TABLE_NAME', 'qkd-sessions-table')
    os.environ.setdefault('KMS_KEY_ARN', 'arn:aws:kms:us-east-1:000000000000:key/test-key')
    
    test_lambda_locally()
    test_aws_resources()
    # test_api_endpoint()  # Uncomment when you have a deployed API
    
    print("\n🎉 Manual testing complete!")
EOF

chmod +x scripts/manual_test.py

print_success "Local testing environment setup complete!"

echo ""
echo "📋 Next Steps:"
echo "=============="
echo "1. Start LocalStack: docker-compose -f docker-compose.localstack.yml up -d"
echo "2. Initialize LocalStack: ./scripts/init_localstack.sh"
echo "3. Run local tests: ./scripts/test_local.sh"
echo "4. Manual testing: python scripts/manual_test.py"
echo ""
echo "📁 Files created:"
echo "• docker-compose.localstack.yml - LocalStack configuration"
echo "• scripts/init_localstack.sh - LocalStack initialization"
echo "• scripts/test_local.sh - Local test runner"
echo "• scripts/manual_test.py - Manual testing script"
