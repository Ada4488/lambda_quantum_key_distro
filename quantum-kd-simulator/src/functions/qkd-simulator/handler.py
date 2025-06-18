\
import json
import secrets
import os
import datetime
import base64
from typing import Dict, List, Tuple, Optional

import numpy as np # Ensure numpy is imported
from aws_lambda_powertools import Logger, Tracer, Metrics
from aws_lambda_powertools.utilities.typing import LambdaContext
from pydantic import BaseModel, Field
import boto3

logger = Logger()
tracer = Tracer()
metrics = Metrics()

DEFAULT_TARGET_KEY_LENGTH = 128  # Target length of the final secret key
DEFAULT_CHANNEL_ERROR_RATE = 0.01 # Simulated error rate of the quantum channel
RAW_BIT_MULTIPLIER = 16 # Heuristic: raw bits needed = target_key_length * MULTIPLIER
QBER_SAMPLE_FRACTION = 0.5 # Fraction of sifted key used to estimate QBER
MAX_TOLERABLE_QBER = 0.15 # Maximum QBER for which error correction is attempted

# Environment variables
DYNAMODB_TABLE_NAME = os.environ.get("DYNAMODB_TABLE_NAME")
KMS_KEY_ARN = os.environ.get("KMS_KEY_ARN")

# Initialize AWS clients outside the handler for reuse
dynamodb_client = boto3.client("dynamodb") if DYNAMODB_TABLE_NAME else None
kms_client = boto3.client("kms") if KMS_KEY_ARN else None

class QKDRequest(BaseModel):
    target_key_length: int = Field(default=DEFAULT_TARGET_KEY_LENGTH, gt=0, le=256)
    channel_error_rate: float = Field(default=DEFAULT_CHANNEL_ERROR_RATE, ge=0.0, le=0.5)

class BB84Protocol:
    def __init__(self, target_final_key_length: int, channel_error_rate: float):
        if target_final_key_length <= 0:
            raise ValueError("Target final key length must be positive.")
        self.target_final_key_length = target_final_key_length
        self.channel_error_rate = channel_error_rate
        # Calculate raw bits needed. This is a heuristic.
        # Needs to be enough for sifting (~50%), QBER sampling, EC, and PA.
        self.raw_bits_to_generate = target_final_key_length * RAW_BIT_MULTIPLIER
        if self.raw_bits_to_generate == 0 : # Ensure we generate some bits if target is very small
             self.raw_bits_to_generate = RAW_BIT_MULTIPLIER # Minimum raw bits
        logger.debug(f"BB84Protocol initialized: target_key={target_final_key_length}, error_rate={channel_error_rate}, raw_bits_needed={self.raw_bits_to_generate}")

    def prepare_qubits_alice(self) -> Tuple[List[int], List[int]]:
        bits = [secrets.randbelow(2) for _ in range(self.raw_bits_to_generate)]
        bases = [secrets.randbelow(2) for _ in range(self.raw_bits_to_generate)] # 0 for rectilinear (+), 1 for diagonal (x)
        logger.debug(f"Alice generated {len(bits)} bits and bases.")
        return bits, bases

    def choose_bases_bob(self) -> List[int]:
        bases = [secrets.randbelow(2) for _ in range(self.raw_bits_to_generate)]
        logger.debug(f"Bob chose {len(bases)} measurement bases.")
        return bases

    def measure_photons_bob(self, alice_photons: List[int], alice_bases: List[int], bob_measurement_bases: List[int]) -> List[int]:
        measured_bits = []
        if not (len(alice_photons) == len(alice_bases) == len(bob_measurement_bases) == self.raw_bits_to_generate):
            raise ValueError("Bit and base lists must match raw_bits_to_generate length.")

        for i in range(self.raw_bits_to_generate):
            photon = alice_photons[i]
            alice_base = alice_bases[i]
            bob_base = bob_measurement_bases[i]
            
            measured_bit = photon if alice_base == bob_base else secrets.randbelow(2)

            if secrets.SystemRandom().random() < self.channel_error_rate:
                measured_bit = 1 - measured_bit
            
            measured_bits.append(measured_bit)
        
        logger.debug(f"Bob measured {len(measured_bits)} bits.")
        return measured_bits

    def reconcile_bases(self, alice_bases: List[int], bob_bases: List[int]) -> List[int]:
        sifted_indices = []
        if len(alice_bases) != len(bob_bases):
            raise ValueError("Base lists must have the same length for reconciliation.")
            
        for i in range(len(alice_bases)):
            if alice_bases[i] == bob_bases[i]:
                sifted_indices.append(i)
        logger.debug(f"Basis reconciliation: {len(sifted_indices)} bits kept from {len(alice_bases)} raw bits.")
        return sifted_indices

    def estimate_qber(self, alice_sifted_key: List[int], bob_sifted_key: List[int]) -> Tuple[float, List[int], List[int], int]:
        if len(alice_sifted_key) != len(bob_sifted_key):
            raise ValueError("Sifted keys must have the same length for QBER estimation.")
        
        key_len = len(alice_sifted_key)
        if key_len == 0:
            return 0.0, [], [], 0

        sample_size = int(key_len * QBER_SAMPLE_FRACTION)
        if sample_size == 0 and key_len > 0: sample_size = 1 # Ensure at least one bit is sampled if possible
        if sample_size == 0 : return 0.0, [], [], 0 # Still no bits to sample

        sample_indices = sorted(secrets.SystemRandom().sample(range(key_len), sample_size))
        
        mismatches = 0
        for i in sample_indices:
            if alice_sifted_key[i] != bob_sifted_key[i]:
                mismatches += 1
        
        qber = mismatches / sample_size if sample_size > 0 else 0.0
        
        remaining_alice_key, remaining_bob_key = [], []
        sample_ptr = 0
        for i in range(key_len):
            if sample_ptr < len(sample_indices) and i == sample_indices[sample_ptr]:
                sample_ptr += 1
            else:
                remaining_alice_key.append(alice_sifted_key[i])
                remaining_bob_key.append(bob_sifted_key[i])
        
        bits_disclosed_for_qber = sample_size
        logger.debug(f"QBER Estimation: Sample size {sample_size}, mismatches {mismatches}, QBER {qber:.4f}. Disclosed {bits_disclosed_for_qber} bits.")
        return qber, remaining_alice_key, remaining_bob_key, bits_disclosed_for_qber

    def error_correction(self, alice_key_for_ec: List[int], bob_key_for_ec: List[int], estimated_qber: float) -> Tuple[List[int], int]:
        if estimated_qber > MAX_TOLERABLE_QBER:
            logger.error(f"Estimated QBER ({estimated_qber:.4f}) exceeds max tolerable QBER ({MAX_TOLERABLE_QBER}). Cannot proceed with error correction.")
            raise ValueError(f"QBER ({estimated_qber:.4f}) too high for error correction.")

        # Simplified: Assume Alice's key is correct, Bob's is corrected to match.
        # Real error correction (e.g., Cascade) leaks some information.
        # This leakage amount is complex to calculate; for simulation, we'll estimate it.
        # For this simulation, the number of bits disclosed is roughly proportional to QBER.
        # disclosed_bits_ec = int(len(alice_key_for_ec) * estimated_qber * 1.1) # Heuristic for Cascade-like leakage
        # A simpler approach for now: assume the main disclosure was for QBER estimation.
        # Or, for a very basic simulation, assume no *additional* bits are disclosed beyond parity checks,
        # and the key length might be slightly reduced.
        
        # For this simulation, we assume Bob's key is perfectly corrected to Alice's key.
        corrected_key = list(alice_key_for_ec)
        
        # Estimate bits disclosed during a hypothetical error correction process.
        # This is a placeholder. Real EC protocols have overhead.
        # Let's assume for simulation, the number of bits disclosed is a fraction of the key length based on QBER.
        # For example, information theory suggests about H(p)*n bits for n bits with error p.
        # H(p) = -p*log2(p) - (1-p)*log2(1-p).
        # If QBER is 0, H(0)=0. If QBER is 0.11 (BB84 threshold), H(0.11) approx 0.5 bits.
        disclosed_bits_ec = 0
        if estimated_qber > 0:
            # Simplified: assume a fixed overhead or a small fraction of bits are "used up" by EC
             disclosed_bits_ec = int(len(corrected_key) * estimated_qber) # Very rough estimate
        
        logger.info(f"Error correction (simulated). Corrected key length: {len(corrected_key)}. Estimated bits disclosed by EC: {disclosed_bits_ec}.")
        return corrected_key, disclosed_bits_ec

    def privacy_amplification(self, corrected_key: List[int], bits_disclosed_qber: int, bits_disclosed_ec: int) -> List[int]:
        current_length = len(corrected_key)

        # Note: bits_disclosed_qber were already removed during QBER estimation
        # The corrected_key already has those bits removed, so we only need to account for EC disclosure
        # and any additional security margin for privacy amplification

        # For privacy amplification, we need to account for:
        # 1. Information leaked during error correction (bits_disclosed_ec)
        # 2. Additional security margin (conservative approach)

        # In real QKD, privacy amplification removes bits based on the total information
        # that could have been leaked to an eavesdropper. For simulation, we'll use
        # a conservative approach: remove EC disclosure + small security margin

        security_margin = max(1, int(current_length * 0.1))  # 10% security margin
        total_bits_to_remove = bits_disclosed_ec + security_margin

        # If too many bits need to be removed, we might not get a useful key
        if current_length <= total_bits_to_remove:
            logger.warning(f"Not enough bits ({current_length}) for privacy amplification after accounting for {total_bits_to_remove} bits (EC: {bits_disclosed_ec}, margin: {security_margin}).")
            return []

        # Calculate the secure key length after privacy amplification
        secure_bits_pool_len = current_length - total_bits_to_remove

        # Final key length is the minimum of what's available and what's requested
        final_key_len = min(secure_bits_pool_len, self.target_final_key_length)

        if final_key_len <= 0:
            logger.warning("Privacy amplification resulted in zero or negative key length.")
            return []

        # Take the first `final_key_len` bits. (Hashing would be better in reality)
        amplified_key = corrected_key[:final_key_len]

        if len(amplified_key) < self.target_final_key_length:
            logger.warning(f"Privacy amplification resulted in a key shorter ({len(amplified_key)}) than target ({self.target_final_key_length}).")

        logger.info(f"Privacy amplification performed. Removed {total_bits_to_remove} bits (EC: {bits_disclosed_ec}, margin: {security_margin}). Final key length: {len(amplified_key)}.")
        return amplified_key

@tracer.capture_lambda_handler
@logger.inject_lambda_context(log_event=True) # Log event for debugging
def lambda_handler(event: dict, context: LambdaContext) -> dict:
    logger.info(f"Received event: {event}")

    if not DYNAMODB_TABLE_NAME or not KMS_KEY_ARN:
        logger.error("Missing DYNAMODB_TABLE_NAME or KMS_KEY_ARN environment variables.")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Server configuration error.'})
        }

    try:
        request_data = QKDRequest(**event.get('body', {} if isinstance(event.get('body'), dict) else json.loads(event.get('body', '{}'))))
        logger.info(f"Validated request: key_length={request_data.target_key_length}, error_rate={request_data.channel_error_rate}")

        protocol = BB84Protocol(
            target_final_key_length=request_data.target_key_length,
            channel_error_rate=request_data.channel_error_rate
        )
        
        session_id = secrets.token_hex(16)
        logger.append_keys(sessionId=session_id) # Add session_id to subsequent logs

        # 1. Alice prepares qubits
        alice_bits, alice_bases = protocol.prepare_qubits_alice()
        
        # 2. Bob chooses bases
        bob_bases = protocol.choose_bases_bob()
        
        # 3. Bob measures photons
        bob_measured_bits = protocol.measure_photons_bob(alice_bits, alice_bases, bob_bases)
        
        # 4. Basis Reconciliation
        sifted_indices = protocol.reconcile_bases(alice_bases, bob_bases)
        alice_sifted_key = [alice_bits[i] for i in sifted_indices]
        bob_sifted_key = [bob_measured_bits[i] for i in sifted_indices]
        sifted_key_length = len(alice_sifted_key)
        logger.info(f"Sifted key length: {sifted_key_length}")

        if sifted_key_length == 0:
            logger.warning("Sifted key is empty. Cannot proceed.")
            # Store minimal session data
            _store_session_data(session_id, alice_bases, bob_bases, 0, 0.0, 0, 0, None, "Sifted key empty")
            return {
                'statusCode': 200, # Or 400/500 depending on if this is client or server issue
                'body': json.dumps({
                    'message': 'QKD simulation failed: Sifted key is empty.',
                    'sessionId': session_id,
                })
            }

        # 5. Estimate QBER
        estimated_qber, alice_key_for_ec, bob_key_for_ec, bits_disclosed_qber = protocol.estimate_qber(alice_sifted_key, bob_sifted_key)
        logger.info(f"Estimated QBER: {estimated_qber:.4f}. Key length for EC: {len(alice_key_for_ec)}")

        # 6. Error Correction
        try:
            corrected_key, bits_disclosed_ec = protocol.error_correction(alice_key_for_ec, bob_key_for_ec, estimated_qber)
        except ValueError as e: # Handles QBER too high
            logger.error(f"Error correction failed: {str(e)}")
            _store_session_data(session_id, alice_bases, bob_bases, sifted_key_length, estimated_qber, 0, 0, None, f"Error correction failed: {str(e)}")
            return {
                'statusCode': 400, # QBER too high is a result of the (simulated) channel
                'body': json.dumps({
                    'message': f'QKD simulation failed: {str(e)}',
                    'sessionId': session_id,
                    'estimatedQBER': estimated_qber
                })
            }
        corrected_key_length = len(corrected_key)
        logger.info(f"Corrected key length: {corrected_key_length}")

        if corrected_key_length == 0:
            logger.warning("Corrected key is empty. Cannot proceed to privacy amplification.")
            _store_session_data(session_id, alice_bases, bob_bases, sifted_key_length, estimated_qber, 0, 0, None, "Corrected key empty")
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'QKD simulation failed: Corrected key is empty.',
                    'sessionId': session_id,
                })
            }
            
        # 7. Privacy Amplification
        final_secure_key = protocol.privacy_amplification(corrected_key, bits_disclosed_qber, bits_disclosed_ec)
        final_key_length = len(final_secure_key)
        logger.info(f"Final secure key length: {final_key_length}")

        if final_key_length == 0:
            logger.warning("Final secure key is empty after privacy amplification.")
            status_message = "Final key empty after PA"
        elif final_key_length < protocol.target_final_key_length:
            status_message = f"Key generated, but shorter ({final_key_length}) than target ({protocol.target_final_key_length})."
        else:
            status_message = "QKD process simulated successfully."

        # 8. Encrypt final key with KMS and store session data
        encrypted_final_key_b64 = None
        if final_key_length > 0:
            try:
                final_key_bytes = json.dumps(final_secure_key).encode('utf-8')
                encrypt_response = kms_client.encrypt(KeyId=KMS_KEY_ARN, Plaintext=final_key_bytes)
                encrypted_final_key_b64 = base64.b64encode(encrypt_response['CiphertextBlob']).decode('utf-8')
                logger.info("Final key encrypted successfully with KMS.")
            except Exception as e:
                logger.exception("Failed to encrypt final key with KMS.")
                # Decide if this is fatal or if we store without encrypted key / store error
                status_message = "QKD successful, but key encryption failed." # Overwrite status
                # Proceed to store other data, but log this severe issue.

        _store_session_data(
            session_id, alice_bases, bob_bases, sifted_key_length, estimated_qber,
            corrected_key_length, final_key_length, encrypted_final_key_b64, status_message
        )
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': status_message,
                'sessionId': session_id,
                'finalKeyLength': final_key_length,
                'estimatedQBER': round(estimated_qber, 4)
            })
        }

    except ValueError as ve: # Catch Pydantic validation errors or other ValueErrors
        logger.error(f"Validation or value error: {str(ve)}")
        return {'statusCode': 400, 'body': json.dumps({'error': str(ve)})}
    except Exception as e:
        logger.exception("Error during QKD simulation")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Internal server error during QKD simulation.'})
        }

def _store_session_data(session_id: str, alice_bases: List[int], bob_bases: List[int],
                        sifted_len: int, qber: float, corrected_len: int, final_len: int,
                        encrypted_key_b64: Optional[str], status: str):
    if not dynamodb_client or not DYNAMODB_TABLE_NAME:
        logger.error("DynamoDB client or table name not configured. Cannot store session data.")
        return

    timestamp = datetime.datetime.utcnow().isoformat()
    # TTL for 24 hours
    ttl_timestamp = int((datetime.datetime.utcnow() + datetime.timedelta(hours=24)).timestamp())

    # Storing all bases can be large. Consider storing hashes or truncated versions if too big.
    # For now, store them if they are not excessively large.
    # Max item size in DynamoDB is 400KB.
    # A list of 128*16 = 2048 integers is small. json.dumps([0]*2048) is ~4KB.
    item_to_store = {
        'sessionId': {'S': session_id},
        'timestamp': {'S': timestamp},
        'ttl': {'N': str(ttl_timestamp)},
        'siftedKeyLength': {'N': str(sifted_len)},
        'estimatedQBER': {'S': f"{qber:.4f}"}, # Store as string for consistent formatting
        'correctedKeyLength': {'N': str(corrected_len)},
        'finalKeyLength': {'N': str(final_len)},
        'status': {'S': status},
        # 'aliceBases': {'S': json.dumps(alice_bases)}, # Potentially large
        # 'bobBases': {'S': json.dumps(bob_bases)},     # Potentially large
    }
    if encrypted_key_b64:
        item_to_store['encryptedFinalKey'] = {'S': encrypted_key_b64} # Storing as Base64 string

    try:
        dynamodb_client.put_item(
            TableName=DYNAMODB_TABLE_NAME,
            Item=item_to_store
        )
        logger.info(f"Session data stored successfully in DynamoDB for session {session_id}.")
    except Exception as e:
        logger.exception(f"Failed to store session data in DynamoDB for session {session_id}.")


# Example of how to use (for local testing, not part of Lambda handler)
if __name__ == '__main__':
    # Mock environment variables for local testing
    os.environ["DYNAMODB_TABLE_NAME"] = "qkd-sessions-table"
    os.environ["KMS_KEY_ARN"] = "arn:aws:kms:us-east-1:123456789012:key/your-kms-key-id" # Replace with a mock or dummy ARN

    # Mock boto3 clients for local testing if not connecting to AWS
    class MockKMSClient:
        def encrypt(self, KeyId, Plaintext):
            logger.info(f"[MockKMS] Encrypting {len(Plaintext)} bytes for KeyId {KeyId}")
            return {'CiphertextBlob': b"mockEncryptedData-" + Plaintext}
    
    class MockDynamoDBClient:
        def put_item(self, TableName, Item):
            logger.info(f"[MockDynamoDB] Storing item to {TableName}: {json.dumps(Item, indent=2)}")

    # kms_client = MockKMSClient() # Uncomment to use mock
    # dynamodb_client = MockDynamoDBClient() # Uncomment to use mock
    
    # Re-initialize clients if mocks are used after initial global init
    if os.environ.get("USE_MOCK_AWS_CLIENTS"):
        kms_client = MockKMSClient()
        dynamodb_client = MockDynamoDBClient()


    test_event_body_success = {
        "target_key_length": 16, # Request a small key for faster local test
        "channel_error_rate": 0.02 
    }
    test_event_body_high_qber = {
        "target_key_length": 16,
        "channel_error_rate": 0.20 # High error rate likely to cause QBER > MAX_TOLERABLE_QBER
    }
    test_event_body_empty_sift = { # Will require very high error rate or very small raw_bits_to_generate
         "target_key_length": 1, # Smallest target
         "channel_error_rate": 0.49 # Very high, close to 50%
    }


    # To make this test run, you might need to adjust RAW_BIT_MULTIPLIER temporarily
    # or ensure the mock clients are properly set up.
    # The global kms_client and dynamodb_client are initialized at module load.
    # For local testing with mocks, you might need to structure it differently or re-assign them.

    # print("\\n--- Test Case: Successful Key Generation ---")
    # response_success = lambda_handler({'body': json.dumps(test_event_body_success)}, LambdaContext())
    # print(f"Response (Success): {json.dumps(response_success, indent=2)}")

    # print("\\n--- Test Case: High QBER leading to failure ---")
    # response_high_qber = lambda_handler({'body': json.dumps(test_event_body_high_qber)}, LambdaContext())
    # print(f"Response (High QBER): {json.dumps(response_high_qber, indent=2)}")
    
    # print("\\n--- Test Case: Empty Sifted Key (Potentially) ---")
    # # This case is tricky to reliably hit without manipulating internal constants like RAW_BIT_MULTIPLIER
    # # For now, we'll assume it might happen with extreme parameters.
    # # RAW_BIT_MULTIPLIER = 2 # Temporarily reduce for this test case if needed
    # response_empty_sift = lambda_handler({'body': json.dumps(test_event_body_empty_sift)}, LambdaContext())
    # print(f"Response (Empty Sift): {json.dumps(response_empty_sift, indent=2)}")
    # # RAW_BIT_MULTIPLIER = 16 # Reset if changed

    # Example of direct protocol usage:
    print("\\n--- Direct Protocol Test ---")
    try:
        protocol_test = BB84Protocol(target_final_key_length=8, channel_error_rate=0.05)
        alice_b, alice_bas = protocol_test.prepare_qubits_alice()
        bob_bas = protocol_test.choose_bases_bob()
        bob_m_b = protocol_test.measure_photons_bob(alice_b, alice_bas, bob_bas)
        sift_idx = protocol_test.reconcile_bases(alice_bas, bob_bas)
        
        alice_sift = [alice_b[i] for i in sift_idx]
        bob_sift = [bob_m_b[i] for i in sift_idx]
        print(f"Alice Sifted ({len(alice_sift)}): {alice_sift[:20]}...")
        print(f"Bob Sifted   ({len(bob_sift)}): {bob_sift[:20]}...")

        if not alice_sift:
            print("Sifted key is empty in direct test.")
        else:
            qber_est, alice_ec, bob_ec, disc_qber = protocol_test.estimate_qber(alice_sift, bob_sift)
            print(f"Estimated QBER: {qber_est:.4f}, disclosed for QBER: {disc_qber}")
            print(f"Alice for EC ({len(alice_ec)}): {alice_ec[:20]}...")
            
            corrected_k, disc_ec = protocol_test.error_correction(alice_ec, bob_ec, qber_est)
            print(f"Corrected Key ({len(corrected_k)}): {corrected_k[:20]}..., disclosed for EC: {disc_ec}")

            final_k = protocol_test.privacy_amplification(corrected_k, disc_qber, disc_ec)
            print(f"Final Amplified Key ({len(final_k)}): {final_k[:20]}...")
            print(f"Target final key length: {protocol_test.target_final_key_length}")

    except Exception as e:
        print(f"Error in direct protocol test: {e}")

    # Note: The local __main__ test won't fully work with real AWS calls unless credentials
    # and resources are configured. Use mocks or a localstack setup for thorough local tests.
    # The provided mock clients are very basic.
    print("\\nTo run lambda_handler tests locally, ensure AWS credentials/region are set,")
    print("or use more robust mocking for KMS and DynamoDB (e.g., moto library).")
    print("Example: `os.environ['AWS_DEFAULT_REGION'] = 'us-east-1'`")
    print("And ensure DYNAMODB_TABLE_NAME and KMS_KEY_ARN point to actual or mocked resources.")
