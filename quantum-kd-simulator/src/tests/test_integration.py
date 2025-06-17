"""
Integration tests for the QKD Simulator.
Tests the complete flow including AWS services.
"""
import json
import pytest
import boto3
from moto import mock_aws
import sys
import os

# Add the function path to sys.path for imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../functions/qkd-simulator'))

from handler import lambda_handler


@pytest.mark.integration
@pytest.mark.aws
class TestQKDSimulatorIntegration:
    """Integration tests for the complete QKD simulator workflow."""
    
    def test_end_to_end_qkd_simulation(self, mock_dynamodb_table, mock_kms_key, lambda_context):
        """Test complete end-to-end QKD simulation."""
        # Test with various key lengths and error rates
        test_cases = [
            {"target_key_length": 32, "channel_error_rate": 0.01},
            {"target_key_length": 64, "channel_error_rate": 0.05},
            {"target_key_length": 128, "channel_error_rate": 0.02},
        ]
        
        for test_case in test_cases:
            event = {"body": test_case}
            
            with mock_aws():
                # Create DynamoDB table
                dynamodb = boto3.resource("dynamodb", region_name="us-east-1")
                table = dynamodb.create_table(
                    TableName="test-qkd-sessions-table",
                    KeySchema=[{"AttributeName": "session_id", "KeyType": "HASH"}],
                    AttributeDefinitions=[{"AttributeName": "session_id", "AttributeType": "S"}],
                    BillingMode="PAY_PER_REQUEST"
                )
                
                # Create KMS key
                kms = boto3.client("kms", region_name="us-east-1")
                key_response = kms.create_key(Description="Test key")
                key_id = key_response["KeyMetadata"]["KeyId"]
                
                # Set environment variables
                os.environ["DYNAMODB_TABLE_NAME"] = "test-qkd-sessions-table"
                os.environ["KMS_KEY_ARN"] = f"arn:aws:kms:us-east-1:123456789012:key/{key_id}"
                
                response = lambda_handler(event, lambda_context)
                
                # Verify response
                assert response['statusCode'] == 200
                body = json.loads(response['body'])
                
                # Check required fields
                assert 'session_id' in body
                assert 'alice_final_key' in body
                assert 'bob_final_key' in body
                assert 'qber' in body
                assert 'key_generation_rate' in body
                
                # Verify key properties
                assert len(body['alice_final_key']) == test_case['target_key_length']
                assert len(body['bob_final_key']) == test_case['target_key_length']
                assert body['alice_final_key'] == body['bob_final_key']  # Keys should match
                
                # Verify QBER is reasonable
                assert 0 <= body['qber'] <= 1
                
                # Verify session was stored in DynamoDB
                stored_item = table.get_item(Key={'session_id': body['session_id']})
                assert 'Item' in stored_item
    
    def test_eavesdropping_detection(self, mock_dynamodb_table, mock_kms_key, lambda_context):
        """Test eavesdropping detection with high error rates."""
        event = {
            "body": {
                "target_key_length": 64,
                "channel_error_rate": 0.25  # Very high error rate
            }
        }
        
        with mock_aws():
            # Setup AWS resources
            dynamodb = boto3.resource("dynamodb", region_name="us-east-1")
            table = dynamodb.create_table(
                TableName="test-qkd-sessions-table",
                KeySchema=[{"AttributeName": "session_id", "KeyType": "HASH"}],
                AttributeDefinitions=[{"AttributeName": "session_id", "AttributeType": "S"}],
                BillingMode="PAY_PER_REQUEST"
            )

            kms = boto3.client("kms", region_name="us-east-1")
            key_response = kms.create_key(Description="Test key")
            key_id = key_response["KeyMetadata"]["KeyId"]
            
            os.environ["DYNAMODB_TABLE_NAME"] = "test-qkd-sessions-table"
            os.environ["KMS_KEY_ARN"] = f"arn:aws:kms:us-east-1:123456789012:key/{key_id}"
            
            response = lambda_handler(event, lambda_context)
            
            # Should still return success but with eavesdropping detection
            assert response['statusCode'] == 200
            body = json.loads(response['body'])
            
            # Should detect potential eavesdropping
            if 'eavesdropping_detected' in body:
                assert body['eavesdropping_detected'] is True
            
            # QBER should be high
            assert body['qber'] > 0.15  # Above threshold
    
    def test_multiple_concurrent_sessions(self, mock_dynamodb_table, mock_kms_key, lambda_context):
        """Test handling multiple concurrent QKD sessions."""
        sessions = []
        
        with mock_aws():
            # Setup AWS resources
            dynamodb = boto3.resource("dynamodb", region_name="us-east-1")
            table = dynamodb.create_table(
                TableName="test-qkd-sessions-table",
                KeySchema=[{"AttributeName": "session_id", "KeyType": "HASH"}],
                AttributeDefinitions=[{"AttributeName": "session_id", "AttributeType": "S"}],
                BillingMode="PAY_PER_REQUEST"
            )

            kms = boto3.client("kms", region_name="us-east-1")
            key_response = kms.create_key(Description="Test key")
            key_id = key_response["KeyMetadata"]["KeyId"]
            
            os.environ["DYNAMODB_TABLE_NAME"] = "test-qkd-sessions-table"
            os.environ["KMS_KEY_ARN"] = f"arn:aws:kms:us-east-1:123456789012:key/{key_id}"
            
            # Create multiple sessions
            for i in range(5):
                event = {
                    "body": {
                        "target_key_length": 32,
                        "channel_error_rate": 0.01
                    }
                }
                
                response = lambda_handler(event, lambda_context)
                assert response['statusCode'] == 200
                
                body = json.loads(response['body'])
                sessions.append(body['session_id'])
            
            # Verify all sessions are unique
            assert len(set(sessions)) == 5
            
            # Verify all sessions are stored in DynamoDB
            for session_id in sessions:
                stored_item = table.get_item(Key={'session_id': session_id})
                assert 'Item' in stored_item
    
    def test_performance_benchmarks(self, mock_dynamodb_table, mock_kms_key, lambda_context):
        """Test performance benchmarks for different key lengths."""
        import time
        
        test_cases = [
            {"target_key_length": 32, "expected_max_time": 5.0},
            {"target_key_length": 64, "expected_max_time": 10.0},
            {"target_key_length": 128, "expected_max_time": 20.0},
        ]
        
        with mock_aws():
            # Setup AWS resources
            dynamodb = boto3.resource("dynamodb", region_name="us-east-1")
            table = dynamodb.create_table(
                TableName="test-qkd-sessions-table",
                KeySchema=[{"AttributeName": "session_id", "KeyType": "HASH"}],
                AttributeDefinitions=[{"AttributeName": "session_id", "AttributeType": "S"}],
                BillingMode="PAY_PER_REQUEST"
            )

            kms = boto3.client("kms", region_name="us-east-1")
            key_response = kms.create_key(Description="Test key")
            key_id = key_response["KeyMetadata"]["KeyId"]
            
            os.environ["DYNAMODB_TABLE_NAME"] = "test-qkd-sessions-table"
            os.environ["KMS_KEY_ARN"] = f"arn:aws:kms:us-east-1:123456789012:key/{key_id}"
            
            for test_case in test_cases:
                event = {
                    "body": {
                        "target_key_length": test_case["target_key_length"],
                        "channel_error_rate": 0.01
                    }
                }
                
                start_time = time.time()
                response = lambda_handler(event, lambda_context)
                end_time = time.time()
                
                execution_time = end_time - start_time
                
                assert response['statusCode'] == 200
                assert execution_time < test_case["expected_max_time"], \
                    f"Execution took {execution_time:.2f}s, expected < {test_case['expected_max_time']}s"
                
                body = json.loads(response['body'])
                print(f"Key length {test_case['target_key_length']}: {execution_time:.2f}s, "
                      f"Rate: {body.get('key_generation_rate', 'N/A')} bits/s")
