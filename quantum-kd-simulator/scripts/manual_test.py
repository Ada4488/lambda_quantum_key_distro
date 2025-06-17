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
