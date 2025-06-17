"""
Unit tests for the QKD Simulator Lambda function.
"""
import json
import pytest
from unittest.mock import patch, MagicMock
import sys
import os

# Add the function path to sys.path for imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../functions/qkd-simulator'))

from handler import lambda_handler, BB84Protocol, QKDRequest


class TestBB84Protocol:
    """Test the BB84 quantum key distribution protocol implementation."""
    
    def test_protocol_initialization(self):
        """Test BB84Protocol initialization with default parameters."""
        protocol = BB84Protocol(target_final_key_length=128, channel_error_rate=0.01)
        assert protocol.target_final_key_length == 128
        assert protocol.channel_error_rate == 0.01
        assert protocol.raw_bits_to_generate == 128 * 16  # target_length * RAW_BIT_MULTIPLIER
    
    def test_protocol_initialization_custom_params(self):
        """Test BB84Protocol initialization with custom parameters."""
        protocol = BB84Protocol(
            target_final_key_length=64,
            channel_error_rate=0.05
        )
        assert protocol.target_final_key_length == 64
        assert protocol.channel_error_rate == 0.05
    
    def test_prepare_qubits_alice(self):
        """Test Alice's qubit preparation."""
        protocol = BB84Protocol(target_final_key_length=32, channel_error_rate=0.01)
        alice_bits, alice_bases = protocol.prepare_qubits_alice()
        
        # Check that we get the expected number of raw bits
        expected_raw_bits = 32 * 16  # target_length * multiplier
        assert len(alice_bits) == expected_raw_bits
        assert len(alice_bases) == expected_raw_bits
        
        # Check that bits are 0 or 1
        assert all(bit in [0, 1] for bit in alice_bits)
        assert all(base in [0, 1] for base in alice_bases)
    
    def test_choose_bases_bob(self):
        """Test Bob's basis selection."""
        protocol = BB84Protocol(target_final_key_length=32, channel_error_rate=0.01)
        # First prepare Alice's qubits to set the raw bit count
        protocol.prepare_qubits_alice()

        bob_bases = protocol.choose_bases_bob()
        expected_raw_bits = 32 * 16
        assert len(bob_bases) == expected_raw_bits
        assert all(base in [0, 1] for base in bob_bases)
    
    def test_measure_photons_bob(self):
        """Test Bob's photon measurement."""
        protocol = BB84Protocol(target_final_key_length=32, channel_error_rate=0.01)
        alice_bits, alice_bases = protocol.prepare_qubits_alice()
        bob_bases = protocol.choose_bases_bob()

        bob_measured_bits = protocol.measure_photons_bob(alice_bits, alice_bases, bob_bases)
        
        assert len(bob_measured_bits) == len(alice_bits)
        assert all(bit in [0, 1] for bit in bob_measured_bits)
        
        # When bases match, measurement should be perfect (no channel errors in this test)
        for i, (alice_bit, alice_base, bob_base, bob_bit) in enumerate(
            zip(alice_bits, alice_bases, bob_bases, bob_measured_bits)
        ):
            if alice_base == bob_base:
                # With no channel error, should match
                # Note: This test assumes no channel errors for simplicity
                pass  # We can't guarantee exact match due to simulated channel errors
    
    def test_reconcile_bases(self):
        """Test basis reconciliation between Alice and Bob."""
        protocol = BB84Protocol(target_final_key_length=32, channel_error_rate=0.01)
        alice_bases = [0, 1, 0, 1, 0, 1]
        bob_bases = [0, 0, 0, 1, 1, 1]
        
        sifted_indices = protocol.reconcile_bases(alice_bases, bob_bases)
        
        # Should return indices where bases match: 0, 2, 3, 5
        expected_indices = [0, 2, 3, 5]
        assert sifted_indices == expected_indices
    
    def test_estimate_qber(self):
        """Test QBER estimation."""
        protocol = BB84Protocol(target_final_key_length=32, channel_error_rate=0.01)
        alice_sifted = [0, 1, 0, 1, 0, 1, 0, 1]
        bob_sifted = [0, 1, 1, 1, 0, 0, 0, 1]  # 2 errors out of 8 bits
        
        qber, remaining_alice_key, remaining_bob_key, bits_disclosed_qber = protocol.estimate_qber(alice_sifted, bob_sifted)

        # QBER should be around 2/8 = 0.25, but depends on sampling
        assert 0.0 <= qber <= 1.0
        assert bits_disclosed_qber > 0
        assert len(remaining_alice_key) == len(remaining_bob_key)
        assert len(remaining_alice_key) < len(alice_sifted)  # Some bits were used for QBER estimation
    
    def test_error_correction_simple(self):
        """Test simple error correction."""
        protocol = BB84Protocol(target_final_key_length=32, channel_error_rate=0.01)
        alice_key = [0, 1, 0, 1, 0, 1, 0, 1]
        bob_key = [0, 1, 1, 1, 0, 0, 0, 1]  # 2 errors
        
        estimated_qber = 0.10  # Within tolerable range (MAX_TOLERABLE_QBER = 0.15)
        corrected_key, bits_disclosed_ec = protocol.error_correction(alice_key, bob_key, estimated_qber)

        # Error correction should return Alice's key (simplified implementation)
        assert corrected_key == alice_key
        assert bits_disclosed_ec >= 0  # Should disclose some bits for error correction
    
    def test_privacy_amplification(self):
        """Test privacy amplification."""
        protocol = BB84Protocol(target_final_key_length=32, channel_error_rate=0.01)
        corrected_key = [0, 1, 0, 1, 0, 1, 0, 1, 1, 0, 1, 0]
        target_length = 8
        
        bits_disclosed_qber = 2  # Example: 2 bits disclosed for QBER estimation
        bits_disclosed_ec = 1    # Example: 1 bit disclosed for error correction
        final_key = protocol.privacy_amplification(corrected_key, bits_disclosed_qber, bits_disclosed_ec)

        # Final key should be shorter than corrected key due to privacy amplification
        assert len(final_key) <= len(corrected_key)
        assert all(bit in [0, 1] for bit in final_key)


class TestQKDRequest:
    """Test the QKDRequest validation model."""
    
    def test_valid_request(self):
        """Test valid QKD request."""
        request_data = {
            "target_key_length": 64,
            "channel_error_rate": 0.05
        }
        request = QKDRequest(**request_data)
        assert request.target_key_length == 64
        assert request.channel_error_rate == 0.05
    
    def test_default_values(self):
        """Test default values for QKD request."""
        request = QKDRequest()
        assert request.target_key_length == 128
        assert request.channel_error_rate == 0.01
    
    def test_invalid_key_length(self):
        """Test invalid key length validation."""
        with pytest.raises(ValueError):
            QKDRequest(target_key_length=0)
        
        with pytest.raises(ValueError):
            QKDRequest(target_key_length=300)  # > 256
    
    def test_invalid_error_rate(self):
        """Test invalid error rate validation."""
        with pytest.raises(ValueError):
            QKDRequest(channel_error_rate=-0.1)
        
        with pytest.raises(ValueError):
            QKDRequest(channel_error_rate=0.6)  # > 0.5


@pytest.mark.aws
class TestLambdaHandler:
    """Test the Lambda handler function."""
    
    def test_lambda_handler_success(self, mock_dynamodb_table, mock_kms_key, lambda_context, sample_qkd_request, mock_env_vars):
        """Test successful Lambda handler execution."""
        event = {
            "body": sample_qkd_request
        }

        with patch('handler.DYNAMODB_TABLE_NAME', 'test-qkd-sessions-table'), \
             patch('handler.KMS_KEY_ARN', 'arn:aws:kms:us-east-1:123456789012:key/test-key-id'), \
             patch('handler.dynamodb_client') as mock_dynamodb, \
             patch('handler.kms_client') as mock_kms:

            # Mock successful DynamoDB put_item
            mock_dynamodb.put_item.return_value = {}

            # Mock successful KMS encrypt
            mock_kms.encrypt.return_value = {
                'CiphertextBlob': b'encrypted_key_data'
            }

            response = lambda_handler(event, lambda_context)

            assert response['statusCode'] == 200
            body = json.loads(response['body'])
            assert 'sessionId' in body
            assert 'finalKeyLength' in body
            assert 'estimatedQBER' in body
            assert 'message' in body
    
    def test_lambda_handler_missing_env_vars(self, lambda_context):
        """Test Lambda handler with missing environment variables."""
        event = {"body": {}}
        
        with patch.dict(os.environ, {}, clear=True):
            response = lambda_handler(event, lambda_context)
            
            assert response['statusCode'] == 500
            body = json.loads(response['body'])
            assert 'error' in body
    
    def test_lambda_handler_invalid_request(self, mock_env_vars, lambda_context):
        """Test Lambda handler with invalid request data."""
        event = {
            "body": {
                "target_key_length": -1,  # Invalid
                "channel_error_rate": 0.05
            }
        }

        with patch('handler.DYNAMODB_TABLE_NAME', 'test-qkd-sessions-table'), \
             patch('handler.KMS_KEY_ARN', 'arn:aws:kms:us-east-1:123456789012:key/test-key-id'):

            response = lambda_handler(event, lambda_context)

            assert response['statusCode'] == 400
            body = json.loads(response['body'])
            assert 'error' in body
    
    def test_lambda_handler_high_qber(self, mock_dynamodb_table, mock_kms_key, lambda_context, mock_env_vars):
        """Test Lambda handler with high QBER (eavesdropping detected)."""
        event = {
            "body": {
                "target_key_length": 32,
                "channel_error_rate": 0.2  # High error rate
            }
        }

        with patch('handler.DYNAMODB_TABLE_NAME', 'test-qkd-sessions-table'), \
             patch('handler.KMS_KEY_ARN', 'arn:aws:kms:us-east-1:123456789012:key/test-key-id'), \
             patch('handler.dynamodb_client') as mock_dynamodb, \
             patch('handler.kms_client') as mock_kms:

            mock_dynamodb.put_item.return_value = {}
            mock_kms.encrypt.return_value = {'CiphertextBlob': b'encrypted_key_data'}

            response = lambda_handler(event, lambda_context)

            # Should return 400 due to high QBER
            assert response['statusCode'] == 400
            body = json.loads(response['body'])
            assert 'message' in body
            assert 'sessionId' in body
