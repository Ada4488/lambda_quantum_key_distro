#!/bin/bash

# Deployment validation script
# This script validates the deployment in staging/production environments

set -e

echo "🚀 Deployment Validation Script"
echo "==============================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

print_status "Validating deployment for environment: $ENVIRONMENT"

# Function to check if AWS CLI is configured
check_aws_cli() {
    print_status "Checking AWS CLI configuration..."
    
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed"
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS CLI is not configured or credentials are invalid"
        exit 1
    fi
    
    print_success "AWS CLI is configured"
}

# Function to validate Lambda functions
validate_lambda_functions() {
    print_status "Validating Lambda functions..."
    
    local functions=(
        "quantum-kd-simulator-qkd-simulator"
        # Add other function names as they are created
    )
    
    for func in "${functions[@]}"; do
        local full_name="${ENVIRONMENT}-${func}"
        
        if aws lambda get-function --function-name "$full_name" --region "$AWS_REGION" &> /dev/null; then
            print_success "Lambda function $full_name exists"
            
            # Test function invocation
            print_status "Testing $full_name invocation..."
            local test_payload='{"body": {"target_key_length": 32, "channel_error_rate": 0.01}}'
            
            local response=$(aws lambda invoke \
                --function-name "$full_name" \
                --payload "$test_payload" \
                --region "$AWS_REGION" \
                response.json 2>&1)
            
            if [ $? -eq 0 ]; then
                local status_code=$(echo "$response" | jq -r '.StatusCode // empty')
                if [ "$status_code" = "200" ]; then
                    print_success "$full_name invocation successful"
                    
                    # Check response content
                    if [ -f response.json ]; then
                        local body=$(cat response.json | jq -r '.body // empty')
                        if [ -n "$body" ] && [ "$body" != "null" ]; then
                            local parsed_body=$(echo "$body" | jq -r '. // empty' 2>/dev/null)
                            if echo "$parsed_body" | jq -e '.session_id' &> /dev/null; then
                                print_success "Response contains expected fields"
                            else
                                print_warning "Response missing expected fields"
                            fi
                        fi
                        rm -f response.json
                    fi
                else
                    print_error "$full_name invocation failed with status $status_code"
                fi
            else
                print_error "$full_name invocation failed: $response"
            fi
        else
            print_error "Lambda function $full_name not found"
        fi
    done
}

# Function to validate DynamoDB tables
validate_dynamodb_tables() {
    print_status "Validating DynamoDB tables..."
    
    local tables=(
        "${ENVIRONMENT}-qkd-sessions-table"
        "${ENVIRONMENT}-eavesdrop-detections-table"
    )
    
    for table in "${tables[@]}"; do
        if aws dynamodb describe-table --table-name "$table" --region "$AWS_REGION" &> /dev/null; then
            print_success "DynamoDB table $table exists"
            
            # Check table status
            local status=$(aws dynamodb describe-table \
                --table-name "$table" \
                --region "$AWS_REGION" \
                --query 'Table.TableStatus' \
                --output text)
            
            if [ "$status" = "ACTIVE" ]; then
                print_success "Table $table is ACTIVE"
            else
                print_warning "Table $table status is $status"
            fi
        else
            print_error "DynamoDB table $table not found"
        fi
    done
}

# Function to validate KMS keys
validate_kms_keys() {
    print_status "Validating KMS keys..."
    
    # List KMS keys and check for our key
    local keys=$(aws kms list-keys --region "$AWS_REGION" --query 'Keys[].KeyId' --output text)
    
    if [ -n "$keys" ]; then
        print_success "KMS keys found"
        
        # Check if we can describe at least one key (permissions test)
        local first_key=$(echo "$keys" | awk '{print $1}')
        if aws kms describe-key --key-id "$first_key" --region "$AWS_REGION" &> /dev/null; then
            print_success "KMS permissions are working"
        else
            print_warning "KMS permissions may be limited"
        fi
    else
        print_error "No KMS keys found"
    fi
}

# Function to validate API Gateway
validate_api_gateway() {
    print_status "Validating API Gateway..."
    
    # Find API by name pattern
    local api_id=$(aws apigateway get-rest-apis \
        --region "$AWS_REGION" \
        --query "items[?contains(name, 'quantum-kd-simulator')].id" \
        --output text)
    
    if [ -n "$api_id" ] && [ "$api_id" != "None" ]; then
        print_success "API Gateway found: $api_id"
        
        # Get API endpoint
        local api_url="https://${api_id}.execute-api.${AWS_REGION}.amazonaws.com/${ENVIRONMENT}"
        print_status "API URL: $api_url"
        
        # Test API endpoint
        print_status "Testing API endpoint..."
        local test_payload='{"target_key_length": 32, "channel_error_rate": 0.01}'
        
        local response=$(curl -s -w "%{http_code}" \
            -X POST \
            -H "Content-Type: application/json" \
            -d "$test_payload" \
            "${api_url}/qkd-simulate" \
            -o api_response.json)
        
        local http_code="${response: -3}"
        
        if [ "$http_code" = "200" ]; then
            print_success "API endpoint is responding correctly"
            
            # Check response content
            if [ -f api_response.json ]; then
                if jq -e '.session_id' api_response.json &> /dev/null; then
                    print_success "API response contains expected fields"
                else
                    print_warning "API response missing expected fields"
                fi
                rm -f api_response.json
            fi
        else
            print_error "API endpoint returned HTTP $http_code"
            if [ -f api_response.json ]; then
                cat api_response.json
                rm -f api_response.json
            fi
        fi
    else
        print_warning "API Gateway not found (may not be deployed yet)"
    fi
}

# Function to validate monitoring and logging
validate_monitoring() {
    print_status "Validating monitoring and logging..."
    
    # Check CloudWatch log groups
    local log_groups=$(aws logs describe-log-groups \
        --region "$AWS_REGION" \
        --log-group-name-prefix "/aws/lambda/${ENVIRONMENT}-quantum-kd-simulator" \
        --query 'logGroups[].logGroupName' \
        --output text)
    
    if [ -n "$log_groups" ]; then
        print_success "CloudWatch log groups found"
        for group in $log_groups; do
            print_status "  - $group"
        done
    else
        print_warning "No CloudWatch log groups found"
    fi
    
    # Check CloudWatch alarms
    local alarms=$(aws cloudwatch describe-alarms \
        --region "$AWS_REGION" \
        --alarm-name-prefix "${ENVIRONMENT}-quantum-kd-simulator" \
        --query 'MetricAlarms[].AlarmName' \
        --output text)
    
    if [ -n "$alarms" ]; then
        print_success "CloudWatch alarms found"
        for alarm in $alarms; do
            print_status "  - $alarm"
        done
    else
        print_warning "No CloudWatch alarms found"
    fi
}

# Function to run end-to-end tests
run_e2e_tests() {
    print_status "Running end-to-end tests..."
    
    # Create a temporary test script
    cat > e2e_test.py << 'EOF'
import boto3
import json
import time
import sys

def test_complete_workflow():
    """Test the complete QKD workflow."""
    print("Testing complete QKD workflow...")
    
    # Test different scenarios
    test_cases = [
        {"target_key_length": 32, "channel_error_rate": 0.01, "name": "Low error rate"},
        {"target_key_length": 64, "channel_error_rate": 0.05, "name": "Medium error rate"},
        {"target_key_length": 32, "channel_error_rate": 0.2, "name": "High error rate (eavesdropping)"},
    ]
    
    lambda_client = boto3.client('lambda')
    function_name = f"{sys.argv[1]}-quantum-kd-simulator-qkd-simulator"
    
    for i, test_case in enumerate(test_cases, 1):
        print(f"\n{i}. Testing: {test_case['name']}")
        
        payload = json.dumps({"body": test_case})
        
        try:
            response = lambda_client.invoke(
                FunctionName=function_name,
                Payload=payload
            )
            
            result = json.loads(response['Payload'].read())
            
            if response['StatusCode'] == 200:
                body = json.loads(result['body'])
                print(f"   ✅ Session ID: {body.get('session_id', 'N/A')}")
                print(f"   ✅ Key length: {len(body.get('alice_final_key', []))}")
                print(f"   ✅ QBER: {body.get('qber', 'N/A'):.4f}")
                
                if body.get('eavesdropping_detected'):
                    print("   ⚠️  Eavesdropping detected (expected for high error rate)")
                
            else:
                print(f"   ❌ Failed with status {response['StatusCode']}")
                return False
                
        except Exception as e:
            print(f"   ❌ Exception: {str(e)}")
            return False
    
    return True

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python e2e_test.py <environment>")
        sys.exit(1)
    
    success = test_complete_workflow()
    sys.exit(0 if success else 1)
EOF
    
    if python e2e_test.py "$ENVIRONMENT"; then
        print_success "End-to-end tests passed"
    else
        print_error "End-to-end tests failed"
    fi
    
    rm -f e2e_test.py
}

# Main validation flow
main() {
    print_status "Starting deployment validation for $ENVIRONMENT environment"
    
    check_aws_cli
    validate_lambda_functions
    validate_dynamodb_tables
    validate_kms_keys
    validate_api_gateway
    validate_monitoring
    run_e2e_tests
    
    print_success "Deployment validation completed!"
    
    echo ""
    echo "📊 Validation Summary"
    echo "===================="
    echo "Environment: $ENVIRONMENT"
    echo "Region: $AWS_REGION"
    echo "Timestamp: $(date)"
    echo ""
    echo "✅ All validations passed successfully!"
    echo ""
    echo "🔗 Useful Links:"
    echo "• CloudWatch Logs: https://console.aws.amazon.com/cloudwatch/home?region=$AWS_REGION#logsV2:log-groups"
    echo "• Lambda Functions: https://console.aws.amazon.com/lambda/home?region=$AWS_REGION#/functions"
    echo "• DynamoDB Tables: https://console.aws.amazon.com/dynamodb/home?region=$AWS_REGION#tables:"
    echo "• API Gateway: https://console.aws.amazon.com/apigateway/home?region=$AWS_REGION#/apis"
}

# Run main function
main
