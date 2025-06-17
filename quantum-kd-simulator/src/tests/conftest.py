"""
Pytest configuration and shared fixtures for quantum-kd-simulator tests.
"""
import os
import pytest
import boto3
from moto import mock_aws
from unittest.mock import patch


@pytest.fixture(scope="session")
def aws_credentials():
    """Mocked AWS Credentials for moto."""
    os.environ["AWS_ACCESS_KEY_ID"] = "testing"
    os.environ["AWS_SECRET_ACCESS_KEY"] = "testing"
    os.environ["AWS_SECURITY_TOKEN"] = "testing"
    os.environ["AWS_SESSION_TOKEN"] = "testing"
    os.environ["AWS_DEFAULT_REGION"] = "us-east-1"


@pytest.fixture
def mock_env_vars():
    """Mock environment variables for Lambda functions."""
    env_vars = {
        "DYNAMODB_TABLE_NAME": "test-qkd-sessions-table",
        "KMS_KEY_ARN": "arn:aws:kms:us-east-1:123456789012:key/test-key-id",
        "AWS_REGION": "us-east-1"
    }
    
    with patch.dict(os.environ, env_vars):
        yield env_vars


@pytest.fixture
def mock_dynamodb_table(aws_credentials, mock_env_vars):
    """Create a mock DynamoDB table for testing."""
    with mock_aws():
        dynamodb = boto3.resource("dynamodb", region_name="us-east-1")

        # Create the table
        table = dynamodb.create_table(
            TableName="test-qkd-sessions-table",
            KeySchema=[
                {"AttributeName": "session_id", "KeyType": "HASH"}
            ],
            AttributeDefinitions=[
                {"AttributeName": "session_id", "AttributeType": "S"}
            ],
            BillingMode="PAY_PER_REQUEST"
        )

        yield table


@pytest.fixture
def mock_kms_key(aws_credentials, mock_env_vars):
    """Create a mock KMS key for testing."""
    with mock_aws():
        kms = boto3.client("kms", region_name="us-east-1")

        # Create a test key
        key = kms.create_key(
            Description="Test KMS key for QKD simulator",
            KeyUsage="ENCRYPT_DECRYPT"
        )

        yield key["KeyMetadata"]["KeyId"]


@pytest.fixture
def sample_qkd_request():
    """Sample QKD request for testing."""
    return {
        "target_key_length": 64,
        "channel_error_rate": 0.05
    }


@pytest.fixture
def lambda_context():
    """Mock Lambda context for testing."""
    class MockLambdaContext:
        def __init__(self):
            self.function_name = "test-qkd-simulator"
            self.function_version = "$LATEST"
            self.invoked_function_arn = "arn:aws:lambda:us-east-1:123456789012:function:test-qkd-simulator"
            self.memory_limit_in_mb = 128
            self.remaining_time_in_millis = 30000
            self.log_group_name = "/aws/lambda/test-qkd-simulator"
            self.log_stream_name = "2023/01/01/[$LATEST]test123"
            self.aws_request_id = "test-request-id"
    
    return MockLambdaContext()
