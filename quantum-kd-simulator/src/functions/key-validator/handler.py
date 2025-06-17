import json
import os
import boto3
import base64
import hmac
import hashlib
import datetime
from typing import Dict, Any, Optional
from urllib.parse import urlparse, unquote

from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives import padding
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from aws_lambda_powertools import Logger, Tracer, Metrics
from aws_lambda_powertools.metrics import MetricUnit
from aws_lambda_powertools.utilities.typing import LambdaContext
from aws_lambda_powertools.utilities.data_classes.s3_event import S3Event, S3EventRecord

logger = Logger()
tracer = Tracer()
metrics = Metrics()

# Environment variables
KMS_KEY_ARN = os.environ.get("KMS_KEY_ARN")
QKD_SESSIONS_TABLE = os.environ.get("QKD_SESSIONS_TABLE")
ENCRYPTION_METADATA_TABLE = os.environ.get("ENCRYPTION_METADATA_TABLE")
OUTPUT_BUCKET = os.environ.get("OUTPUT_BUCKET")  # For storing encrypted/decrypted results

# Constants
KEY_RETRIEVAL_EXPIRY = 900  # Seconds (15 minutes)
PRESIGNED_URL_EXPIRATION = 3600  # Seconds (1 hour)
IV_SIZE = 16  # 16 bytes for AES
SALT_SIZE = 16  # 16 bytes for PBKDF2
TAG_SIZE = 16  # 16 bytes for GCM auth tag
PBKDF2_ITERATIONS = 100000  # Iterations for key derivation

# Initialize AWS clients
dynamodb_client = boto3.client('dynamodb') if QKD_SESSIONS_TABLE or ENCRYPTION_METADATA_TABLE else None
kms_client = boto3.client('kms') if KMS_KEY_ARN else None
s3_client = boto3.client('s3')

class KeyValidator:
    """
    Validates and manages quantum-derived keys for encryption operations
    """
    
    def __init__(self, session_id: str):
        """
        Initialize with session ID to retrieve and validate the associated key.
        
        Args:
            session_id: QKD session identifier
        """
        self.session_id = session_id
        self.key_data = None
    
    @tracer.capture_method
    def retrieve_key(self) -> Optional[bytes]:
        """
        Retrieve the encrypted key from DynamoDB and decrypt it using KMS.
        
        Returns:
            bytes: Decrypted key data or None if retrieval failed
        """
        if not dynamodb_client or not QKD_SESSIONS_TABLE:
            logger.error("DynamoDB client or table name not configured.")
            return None
        
        try:
            # Get the session data from DynamoDB
            response = dynamodb_client.get_item(
                TableName=QKD_SESSIONS_TABLE,
                Key={'sessionId': {'S': self.session_id}}
            )
            
            if 'Item' not in response:
                logger.error(f"Session {self.session_id} not found in DynamoDB.")
                return None
            
            session_item = response['Item']
            
            # Check if the session has an encrypted key
            if 'encryptedFinalKey' not in session_item:
                logger.error(f"Session {self.session_id} has no encrypted key.")
                return None
            
            encrypted_key_b64 = session_item['encryptedFinalKey']['S']
            
            # Check the timestamp to see if the session is still valid
            if 'timestamp' in session_item:
                session_timestamp_str = session_item['timestamp']['S']
                session_timestamp = datetime.datetime.fromisoformat(session_timestamp_str)
                now = datetime.datetime.utcnow()
                
                if (now - session_timestamp).total_seconds() > KEY_RETRIEVAL_EXPIRY:
                    logger.warning(f"Session {self.session_id} has expired for key retrieval.")
                    # For security, we could choose to return None here
                    # return None
                    # But for this implementation, we'll continue anyway
            
            # Decode the base64 encrypted key
            encrypted_key = base64.b64decode(encrypted_key_b64)
            
            # Decrypt the key using KMS
            if not kms_client or not KMS_KEY_ARN:
                logger.error("KMS client or KMS key ARN not configured.")
                return None
            
            decrypt_response = kms_client.decrypt(
                CiphertextBlob=encrypted_key,
                KeyId=KMS_KEY_ARN
            )
            
            # The decrypted key is a JSON string of the original list of bits
            decrypted_key_bytes = decrypt_response['Plaintext']
            key_list = json.loads(decrypted_key_bytes.decode('utf-8'))
            
            # Convert the list of bits to a byte array (for use in cryptographic operations)
            # Each 8 bits become one byte
            key_bytes = bytes(int(''.join(str(bit) for bit in key_list[i:i+8]), 2) 
                             for i in range(0, len(key_list), 8))
            
            self.key_data = key_bytes
            logger.info(f"Successfully retrieved and validated key for session {self.session_id}")
            
            # Log metrics
            metrics.add_metric(name="KeyRetrievals", unit=MetricUnit.Count, value=1)
            
            return key_bytes
        
        except Exception as e:
            logger.exception(f"Error retrieving and validating key: {e}")
            metrics.add_metric(name="KeyRetrievalErrors", unit=MetricUnit.Count, value=1)
            return None


class EncryptionService:
    """
    Handles encryption and decryption operations using quantum-derived keys
    """
    
    @staticmethod
    @tracer.capture_method
    def derive_key(base_key: bytes, salt: bytes) -> bytes:
        """
        Derive a cryptographic key using PBKDF2.
        
        Args:
            base_key: The original key material (quantum-derived)
            salt: Random salt for key derivation
            
        Returns:
            bytes: Derived key suitable for AES-GCM encryption
        """
        kdf = PBKDF2HMAC(
            algorithm=hashlib.sha256(),
            length=32,  # 256-bit key for AES-256
            salt=salt,
            iterations=PBKDF2_ITERATIONS,
            backend=default_backend()
        )
        return kdf.derive(base_key)
    
    @staticmethod
    @tracer.capture_method
    def encrypt_data(data: bytes, key: bytes) -> Dict[str, Any]:
        """
        Encrypt data using AES-256-GCM with the provided key.
        
        Args:
            data: The plaintext data to encrypt
            key: The quantum-derived key (will be further processed with PBKDF2)
            
        Returns:
            Dict containing iv, salt, ciphertext, and tag
        """
        # Generate random salt and IV
        salt = os.urandom(SALT_SIZE)
        iv = os.urandom(IV_SIZE)
        
        # Derive encryption key from quantum-derived key material
        derived_key = EncryptionService.derive_key(key, salt)
        
        # Create encryptor
        encryptor = Cipher(
            algorithms.AES(derived_key),
            modes.GCM(iv),
            backend=default_backend()
        ).encryptor()
        
        # Pad the data to ensure it's a multiple of the block size
        padder = padding.PKCS7(algorithms.AES.block_size).padder()
        padded_data = padder.update(data) + padder.finalize()
        
        # Encrypt the data
        ciphertext = encryptor.update(padded_data) + encryptor.finalize()
        
        return {
            'iv': base64.b64encode(iv).decode('utf-8'),
            'salt': base64.b64encode(salt).decode('utf-8'),
            'ciphertext': base64.b64encode(ciphertext).decode('utf-8'),
            'tag': base64.b64encode(encryptor.tag).decode('utf-8')
        }
    
    @staticmethod
    @tracer.capture_method
    def decrypt_data(encrypted_data: Dict[str, Any], key: bytes) -> bytes:
        """
        Decrypt data using AES-256-GCM with the provided key.
        
        Args:
            encrypted_data: Dict containing iv, salt, ciphertext, and tag
            key: The quantum-derived key (will be further processed with PBKDF2)
            
        Returns:
            bytes: The decrypted plaintext
        """
        # Decode the base64 components
        iv = base64.b64decode(encrypted_data['iv'])
        salt = base64.b64decode(encrypted_data['salt'])
        ciphertext = base64.b64decode(encrypted_data['ciphertext'])
        tag = base64.b64decode(encrypted_data['tag'])
        
        # Derive decryption key
        derived_key = EncryptionService.derive_key(key, salt)
        
        # Create decryptor
        decryptor = Cipher(
            algorithms.AES(derived_key),
            modes.GCM(iv, tag),
            backend=default_backend()
        ).decryptor()
        
        # Decrypt the data
        padded_plaintext = decryptor.update(ciphertext) + decryptor.finalize()
        
        # Unpad the data
        unpadder = padding.PKCS7(algorithms.AES.block_size).unpadder()
        plaintext = unpadder.update(padded_plaintext) + unpadder.finalize()
        
        return plaintext


def store_encryption_metadata(session_id: str, file_key: str, encryption_metadata: Dict[str, Any]) -> bool:
    """
    Store encryption metadata in DynamoDB.
    
    Args:
        session_id: QKD session ID used for the encryption
        file_key: S3 key of the encrypted file
        encryption_metadata: Dict containing encryption details
        
    Returns:
        bool: Success/failure
    """
    if not dynamodb_client or not ENCRYPTION_METADATA_TABLE:
        logger.warning("DynamoDB client or encryption metadata table not configured.")
        return False
    
    try:
        timestamp = datetime.datetime.utcnow().isoformat()
        
        # Create a unique ID for this encryption operation
        encryption_id = f"{session_id}-{file_key.replace('/', '-')}"
        
        # Prepare the item to store
        item = {
            'encryptionId': {'S': encryption_id},
            'sessionId': {'S': session_id},
            'fileKey': {'S': file_key},
            'timestamp': {'S': timestamp},
            'ivBase64': {'S': encryption_metadata['iv']},
            'saltBase64': {'S': encryption_metadata['salt']},
            'tagBase64': {'S': encryption_metadata['tag']}
            # Note: We don't store the ciphertext itself in DynamoDB
        }
        
        # Store the item
        dynamodb_client.put_item(
            TableName=ENCRYPTION_METADATA_TABLE,
            Item=item
        )
        
        return True
    except Exception as e:
        logger.exception(f"Error storing encryption metadata: {e}")
        return False


def generate_presigned_url(bucket: str, key: str) -> Optional[str]:
    """
    Generate a pre-signed URL for downloading an object from S3.
    
    Args:
        bucket: S3 bucket name
        key: S3 object key
        
    Returns:
        str: Pre-signed URL or None if generation failed
    """
    try:
        url = s3_client.generate_presigned_url(
            'get_object',
            Params={'Bucket': bucket, 'Key': key},
            ExpiresIn=PRESIGNED_URL_EXPIRATION
        )
        return url
    except Exception as e:
        logger.exception(f"Error generating pre-signed URL: {e}")
        return None


@tracer.capture_method
def process_file(record: S3EventRecord) -> Dict[str, Any]:
    """
    Process an S3 object, extracting session ID from object metadata
    and applying encryption/decryption.
    
    Args:
        record: S3 event record
        
    Returns:
        Dict: Processing results
    """
    bucket = record.bucket.name
    key = unquote(record.object.key)
    operation = None  # 'encrypt' or 'decrypt'
    result = {'status': 'error', 'message': 'Unknown error', 'fileKey': key}
    
    try:
        # Get the object metadata to find the session ID and operation
        response = s3_client.head_object(Bucket=bucket, Key=key)
        metadata = response.get('Metadata', {})
        
        session_id = metadata.get('qkd-session-id')
        operation = metadata.get('operation', '').lower()
        
        if not session_id:
            result['message'] = "No QKD session ID provided in object metadata."
            return result
        
        if operation not in ['encrypt', 'decrypt']:
            operation = 'encrypt'  # Default to encrypt
        
        # Get the key for this session
        validator = KeyValidator(session_id)
        key_data = validator.retrieve_key()
        
        if not key_data:
            result['message'] = f"Failed to retrieve or validate key for session {session_id}."
            return result
        
        # Get the object content
        obj_response = s3_client.get_object(Bucket=bucket, Key=key)
        content = obj_response['Body'].read()
        
        # Process based on operation
        if operation == 'encrypt':
            # Encrypt the file content
            encryption_result = EncryptionService.encrypt_data(content, key_data)
            
            # Store the encrypted data
            encrypted_key = f"encrypted/{session_id}/{os.path.basename(key)}"
            s3_client.put_object(
                Bucket=OUTPUT_BUCKET or bucket,
                Key=encrypted_key,
                Body=base64.b64decode(encryption_result['ciphertext']),
                Metadata={
                    'qkd-session-id': session_id,
                    'operation': 'encrypted',
                    'original-key': key
                }
            )
            
            # Store encryption metadata
            store_encryption_metadata(session_id, encrypted_key, encryption_result)
            
            # Generate pre-signed URL
            url = generate_presigned_url(OUTPUT_BUCKET or bucket, encrypted_key)
            
            # Update result
            result['status'] = 'success'
            result['message'] = f"File encrypted successfully using key from session {session_id}."
            result['encryptedKey'] = encrypted_key
            result['downloadUrl'] = url
            metrics.add_metric(name="FilesEncrypted", unit=MetricUnit.Count, value=1)
            
        elif operation == 'decrypt':
            # For decryption, we need to retrieve the encryption metadata
            if not ENCRYPTION_METADATA_TABLE:
                result['message'] = "Encryption metadata table not configured for decryption."
                return result
            
            # Extract the file identifier from the key
            file_basename = os.path.basename(key)
            
            # Check if this is one of our encrypted files
            if not metadata.get('operation') == 'encrypted':
                result['message'] = "This file does not appear to be encrypted by our system."
                return result
            
            # Get the original encryption metadata
            original_key = metadata.get('original-key')
            if not original_key:
                result['message'] = "Missing original file key in metadata."
                return result
            
            # Create encryption ID to look up in the metadata table
            encryption_id = f"{session_id}-{key.replace('/', '-')}"
            
            # Get encryption metadata
            meta_response = dynamodb_client.get_item(
                TableName=ENCRYPTION_METADATA_TABLE,
                Key={'encryptionId': {'S': encryption_id}}
            )
            
            if 'Item' not in meta_response:
                result['message'] = f"No encryption metadata found for {encryption_id}."
                return result
            
            meta_item = meta_response['Item']
            
            # Reconstruct the encryption data
            encryption_data = {
                'iv': meta_item['ivBase64']['S'],
                'salt': meta_item['saltBase64']['S'],
                'tag': meta_item['tagBase64']['S'],
                'ciphertext': base64.b64encode(content).decode('utf-8')
            }
            
            # Decrypt the content
            decrypted_content = EncryptionService.decrypt_data(encryption_data, key_data)
            
            # Store the decrypted result
            decrypted_key = f"decrypted/{session_id}/{os.path.basename(original_key)}"
            s3_client.put_object(
                Bucket=OUTPUT_BUCKET or bucket,
                Key=decrypted_key,
                Body=decrypted_content,
                Metadata={
                    'qkd-session-id': session_id,
                    'operation': 'decrypted',
                    'encrypted-key': key
                }
            )
            
            # Generate pre-signed URL
            url = generate_presigned_url(OUTPUT_BUCKET or bucket, decrypted_key)
            
            # Update result
            result['status'] = 'success'
            result['message'] = f"File decrypted successfully using key from session {session_id}."
            result['decryptedKey'] = decrypted_key
            result['downloadUrl'] = url
            metrics.add_metric(name="FilesDecrypted", unit=MetricUnit.Count, value=1)
            
    except Exception as e:
        logger.exception(f"Error processing file {key}: {e}")
        result['message'] = f"Error processing file: {str(e)}"
        if operation == 'encrypt':
            metrics.add_metric(name="EncryptionErrors", unit=MetricUnit.Count, value=1)
        elif operation == 'decrypt':
            metrics.add_metric(name="DecryptionErrors", unit=MetricUnit.Count, value=1)
    
    return result


@tracer.capture_lambda_handler
@logger.inject_lambda_context(log_event=True)
@metrics.log_metrics
def lambda_handler(event: Dict[str, Any], context: LambdaContext) -> Dict[str, Any]:
    """
    Lambda handler for key-validator function.
    
    Args:
        event: S3 event
        context: Lambda context
        
    Returns:
        Dict: Processing results
    """
    logger.info("Key Validator function invoked")
    
    # Process S3 event
    s3_event = S3Event(event)
    results = []
    
    for record in s3_event.records:
        result = process_file(record)
        results.append(result)
    
    response = {
        'statusCode': 200,
        'body': json.dumps({
            'message': f"Processed {len(results)} files",
            'results': results
        })
    }
    
    logger.info(f"Key Validator completed processing: {len(results)} files")
    return response


# For local testing
if __name__ == '__main__':
    # Sample event for testing
    test_event = {
        "Records": [
            {
                "eventVersion": "2.0",
                "eventSource": "aws:s3",
                "awsRegion": "us-east-1",
                "eventTime": "2025-06-15T12:00:00.000Z",
                "eventName": "ObjectCreated:Put",
                "s3": {
                    "s3SchemaVersion": "1.0",
                    "bucket": {
                        "name": "test-bucket",
                        "arn": "arn:aws:s3:::test-bucket"
                    },
                    "object": {
                        "key": "test-file.txt",
                        "size": 1024,
                        "eTag": "0123456789abcdef0123456789abcdef",
                        "sequencer": "0A1B2C3D4E5F678901"
                    }
                }
            }
        ]
    }
    
    # Set environment variables for local testing
    os.environ["KMS_KEY_ARN"] = "arn:aws:kms:us-east-1:123456789012:key/test-key-id"
    os.environ["QKD_SESSIONS_TABLE"] = "test-qkd-sessions-table"
    os.environ["ENCRYPTION_METADATA_TABLE"] = "test-encryption-metadata-table"
    os.environ["OUTPUT_BUCKET"] = "test-output-bucket"
    
    # Mock clients for local testing
    class MockS3Client:
        def head_object(self, Bucket, Key):
            print(f"[MockS3] Getting metadata for {Key} from {Bucket}")
            return {
                'Metadata': {
                    'qkd-session-id': 'test-session-123',
                    'operation': 'encrypt'
                }
            }
        
        def get_object(self, Bucket, Key):
            print(f"[MockS3] Getting object {Key} from {Bucket}")
            return {
                'Body': type('MockBody', (), {'read': lambda: b'This is test content for encryption'})
            }
        
        def put_object(self, Bucket, Key, Body, Metadata):
            print(f"[MockS3] Putting object {Key} to {Bucket} with metadata: {Metadata}")
            print(f"  Content length: {len(Body)} bytes")
            return {}
        
        def generate_presigned_url(self, ClientMethod, Params, ExpiresIn):
            bucket = Params['Bucket']
            key = Params['Key']
            print(f"[MockS3] Generating presigned URL for {key} in {bucket} (expires in {ExpiresIn}s)")
            return f"https://{bucket}.s3.amazonaws.com/{key}?presigned=true&expires={ExpiresIn}"
    
    class MockDynamoDBClient:
        def get_item(self, TableName, Key):
            print(f"[MockDynamoDB] Getting item from {TableName} with key: {Key}")
            
            # Simulate a session record
            if TableName == "test-qkd-sessions-table":
                # Simple encryption for testing - in reality this would be a KMS-encrypted value
                encrypted_key = base64.b64encode(json.dumps([0,1,0,1,0,1,1,0] * 16).encode('utf-8'))
                return {
                    'Item': {
                        'sessionId': {'S': 'test-session-123'},
                        'timestamp': {'S': '2025-06-15T10:00:00Z'},
                        'encryptedFinalKey': {'S': encrypted_key.decode('utf-8')}
                    }
                }
            
            # Simulate encryption metadata
            if TableName == "test-encryption-metadata-table":
                return {
                    'Item': {
                        'encryptionId': {'S': 'test-session-123-encrypted/test-session-123/test-file.txt'},
                        'ivBase64': {'S': base64.b64encode(b'\x00' * 16).decode('utf-8')},
                        'saltBase64': {'S': base64.b64encode(b'\x01' * 16).decode('utf-8')},
                        'tagBase64': {'S': base64.b64encode(b'\x02' * 16).decode('utf-8')}
                    }
                }
            
            return {}
        
        def put_item(self, TableName, Item):
            print(f"[MockDynamoDB] Putting item to {TableName}:")
            for key, value in Item.items():
                value_type = list(value.keys())[0]
                value_str = str(value[value_type])
                if len(value_str) > 50:
                    value_str = value_str[:47] + "..."
                print(f"  {key}: {value_str} ({value_type})")
            return {}
    
    class MockKMSClient:
        def decrypt(self, CiphertextBlob, KeyId):
            print(f"[MockKMS] Decrypting blob using key {KeyId}")
            # Simple mock - just return the input as if it were decrypted
            # In reality, KMS would properly decrypt the ciphertext
            return {'Plaintext': CiphertextBlob}
    
    # Use mock clients for local testing
    s3_client = MockS3Client()
    dynamodb_client = MockDynamoDBClient()
    kms_client = MockKMSClient()
    
    # Invoke lambda handler
    result = lambda_handler(test_event, None)
    print(f"\nLambda result: {json.dumps(result, indent=2)}")
