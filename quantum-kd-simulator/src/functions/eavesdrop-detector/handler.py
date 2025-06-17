import json
import os
import boto3
import datetime
from typing import Dict, List, Any, Optional
import math
from decimal import Decimal

from aws_lambda_powertools import Logger, Tracer, Metrics
from aws_lambda_powertools.metrics import MetricUnit
from aws_lambda_powertools.utilities.typing import LambdaContext
from aws_lambda_powertools.utilities.data_classes import DynamoDBStreamEvent

logger = Logger()
tracer = Tracer()
metrics = Metrics()

# Environment variables
DETECTIONS_TABLE_NAME = os.environ.get("EAVESDROP_DETECTIONS_TABLE")
SNS_TOPIC_ARN = os.environ.get("ALERTS_SNS_TOPIC_ARN")

# Constants
DEFAULT_QBER_THRESHOLD = 0.11  # 11% is a common theoretical threshold for BB84
STATISTICAL_SIGNIFICANCE_THRESHOLD = 0.05  # p-value threshold for statistical tests
CONFIDENCE_LEVEL_HIGH = 0.9
CONFIDENCE_LEVEL_MEDIUM = 0.7
CONFIDENCE_LEVEL_LOW = 0.5

# Initialize clients outside the handler for reuse
dynamodb_client = boto3.client('dynamodb') if DETECTIONS_TABLE_NAME else None
sns_client = boto3.client('sns') if SNS_TOPIC_ARN else None

class EavesdropAnalyzer:
    """Class to analyze QKD session data for potential eavesdropping."""
    
    def __init__(self, qber_threshold: float = DEFAULT_QBER_THRESHOLD):
        """Initialize with QBER threshold."""
        self.qber_threshold = qber_threshold
    
    def calculate_confidence_level(self, qber: float, sample_size: int) -> float:
        """
        Calculate confidence level based on QBER and sample size.
        
        Args:
            qber: Quantum Bit Error Rate
            sample_size: Number of bits used to calculate QBER
            
        Returns:
            float: Confidence level between 0.0 and 1.0
        """
        if qber <= 0.0:
            return 0.0  # No errors means no confidence in eavesdropping
            
        # Basic confidence calculation - higher QBER and larger sample means higher confidence
        # This is a simplified model; in reality, statistical models would be more complex
        base_confidence = min(1.0, qber / self.qber_threshold)
        
        # Apply sample size factor (more samples = more confidence)
        # Using log scale to model diminishing returns of larger samples
        sample_factor = min(1.0, math.log10(max(1, sample_size)) / 3)  # Normalized to [0,1]
        
        # Combine factors - more weight to actual QBER
        confidence = base_confidence * 0.7 + sample_factor * 0.3
        
        return round(confidence, 2)
    
    def chi_square_test(self, observed_errors: int, expected_error_rate: float, total_bits: int) -> float:
        """
        Perform a simplified chi-square test to determine if the observed error rate
        is statistically different from the expected error rate.
        
        Args:
            observed_errors: Number of errors observed
            expected_error_rate: Expected error rate (between 0 and 1)
            total_bits: Total number of bits measured
            
        Returns:
            float: Chi-square value
        """
        expected_errors = total_bits * expected_error_rate
        expected_correct = total_bits - expected_errors
        observed_correct = total_bits - observed_errors
        
        if expected_errors == 0:
            expected_errors = 0.0001  # Avoid division by zero
        if expected_correct == 0:
            expected_correct = 0.0001  # Avoid division by zero
            
        chi_square = ((observed_errors - expected_errors) ** 2 / expected_errors + 
                     (observed_correct - expected_correct) ** 2 / expected_correct)
                     
        return chi_square
        
    def is_statistically_significant(self, chi_square: float) -> bool:
        """
        Determine if the chi-square value is statistically significant.
        For chi-square with df=1, the critical value at p=0.05 is ~3.84.
        
        Args:
            chi_square: Chi-square test result
            
        Returns:
            bool: True if statistically significant
        """
        # Critical value for df=1, p=0.05
        critical_value = 3.84
        return chi_square > critical_value
    
    def detect_eavesdropping(self, session_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Detect potential eavesdropping based on session data.
        
        Args:
            session_data: QKD session data including QBER
            
        Returns:
            Dict with detection results
        """
        # Get key values from session data
        session_id = session_data.get('sessionId', 'unknown')
        estimated_qber_str = session_data.get('estimatedQBER', '0.0')
        sifted_key_length = int(session_data.get('siftedKeyLength', 0))
        corrected_key_length = int(session_data.get('correctedKeyLength', 0))
        final_key_length = int(session_data.get('finalKeyLength', 0))
        
        # Convert QBER string to float
        try:
            estimated_qber = float(estimated_qber_str)
        except (ValueError, TypeError):
            logger.error(f"Invalid QBER value in session {session_id}: {estimated_qber_str}")
            estimated_qber = 0.0
            
        logger.info(f"Analyzing session {session_id} with QBER {estimated_qber}")
        
        # Calculate chi-square for statistical significance
        # Simplified: assuming expected error rate of pre-configured channel error rate or a nominal value
        expected_error_rate = 0.01  # This could be from the session data if available
        observed_errors = int(sifted_key_length * estimated_qber)
        
        chi_square_value = self.chi_square_test(
            observed_errors=observed_errors,
            expected_error_rate=expected_error_rate,
            total_bits=sifted_key_length
        )
        
        # Determine statistical significance
        is_significant = self.is_statistically_significant(chi_square_value)
        
        # Calculate confidence level
        confidence_level = self.calculate_confidence_level(estimated_qber, sifted_key_length)
        
        # Make detection decision
        is_compromised = (
            estimated_qber > self.qber_threshold and 
            is_significant and
            confidence_level >= CONFIDENCE_LEVEL_MEDIUM
        )
        
        detection_result = {
            'sessionId': session_id,
            'detectionTimestamp': int(datetime.datetime.utcnow().timestamp()),
            'qberCalculated': estimated_qber,
            'chiSquareValue': chi_square_value,
            'isCompromised': is_compromised,
            'confidenceLevel': confidence_level,
            'siftedKeyLength': sifted_key_length,
            'finalKeyLength': final_key_length,
            'isStatisticallySignificant': is_significant
        }
        
        # Emit metrics
        metrics.add_metric(name="QBERValue", unit=MetricUnit.Percent, value=estimated_qber * 100)
        metrics.add_metric(name="EavesdropConfidence", unit=MetricUnit.Percent, value=confidence_level * 100)
        if is_compromised:
            metrics.add_metric(name="EavesdropDetections", unit=MetricUnit.Count, value=1)
            
        return detection_result


def store_detection_result(detection_result: Dict[str, Any]) -> bool:
    """Store eavesdrop detection result in DynamoDB."""
    if not dynamodb_client or not DETECTIONS_TABLE_NAME:
        logger.error("DynamoDB client or table name not configured. Cannot store detection result.")
        return False
        
    # Convert Python types to DynamoDB types
    item = {
        'sessionId': {'S': detection_result['sessionId']},
        'detectionTimestamp': {'N': str(detection_result['detectionTimestamp'])},
        'qberCalculated': {'N': str(detection_result['qberCalculated'])},
        'chiSquareValue': {'N': str(detection_result['chiSquareValue'])},
        'isCompromised': {'BOOL': detection_result['isCompromised']},
        'confidenceLevel': {'N': str(detection_result['confidenceLevel'])},
        'siftedKeyLength': {'N': str(detection_result['siftedKeyLength'])},
        'finalKeyLength': {'N': str(detection_result['finalKeyLength'])},
        'isStatisticallySignificant': {'BOOL': detection_result['isStatisticallySignificant']}
    }
    
    try:
        dynamodb_client.put_item(
            TableName=DETECTIONS_TABLE_NAME,
            Item=item
        )
        logger.info(f"Detection result stored for session {detection_result['sessionId']}")
        return True
    except Exception as e:
        logger.exception(f"Failed to store detection result: {e}")
        return False


def send_alert(detection_result: Dict[str, Any]) -> bool:
    """Send SNS notification if eavesdropping is detected."""
    if not sns_client or not SNS_TOPIC_ARN or not detection_result.get('isCompromised', False):
        return False
        
    try:
        subject = f"SECURITY ALERT: Potential eavesdropping detected in QKD session {detection_result['sessionId']}"
        
        message = (
            f"QKD Security Alert\n\n"
            f"Potential eavesdropping has been detected in QKD session.\n"
            f"Session ID: {detection_result['sessionId']}\n"
            f"Detection Time: {datetime.datetime.fromtimestamp(detection_result['detectionTimestamp']).isoformat()}\n"
            f"QBER: {detection_result['qberCalculated']:.4f}\n"
            f"Confidence Level: {detection_result['confidenceLevel']*100:.1f}%\n"
            f"Chi-Square Value: {detection_result['chiSquareValue']:.2f}\n"
            f"Statistical Significance: {detection_result['isStatisticallySignificant']}\n\n"
            f"Please investigate this session immediately."
        )
        
        response = sns_client.publish(
            TopicArn=SNS_TOPIC_ARN,
            Message=message,
            Subject=subject
        )
        logger.info(f"Security alert sent for session {detection_result['sessionId']}")
        return True
    except Exception as e:
        logger.exception(f"Failed to send security alert: {e}")
        return False


def process_session_record(record: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    """Process a DynamoDB stream record containing QKD session data."""
    # Check if this is a new session record (INSERT)
    event_name = record.get('eventName')
    if event_name != 'INSERT':
        logger.debug(f"Skipping non-INSERT event: {event_name}")
        return None
    
    # Extract the session data from the DynamoDB record
    try:
        session_data = {}
        if 'NewImage' in record.get('dynamodb', {}):
            new_image = record['dynamodb']['NewImage']
            
            # Extract key fields from DynamoDB format
            if 'sessionId' in new_image and 'S' in new_image['sessionId']:
                session_data['sessionId'] = new_image['sessionId']['S']
            
            if 'estimatedQBER' in new_image and 'S' in new_image['estimatedQBER']:
                session_data['estimatedQBER'] = new_image['estimatedQBER']['S']
            
            if 'siftedKeyLength' in new_image and 'N' in new_image['siftedKeyLength']:
                session_data['siftedKeyLength'] = new_image['siftedKeyLength']['N']
            
            if 'correctedKeyLength' in new_image and 'N' in new_image['correctedKeyLength']:
                session_data['correctedKeyLength'] = new_image['correctedKeyLength']['N']
                
            if 'finalKeyLength' in new_image and 'N' in new_image['finalKeyLength']:
                session_data['finalKeyLength'] = new_image['finalKeyLength']['N']
                
            if 'status' in new_image and 'S' in new_image['status']:
                session_data['status'] = new_image['status']['S']
                
            return session_data
    except Exception as e:
        logger.exception(f"Error extracting session data from DynamoDB stream record: {e}")
    
    return None


@tracer.capture_lambda_handler
@logger.inject_lambda_context(log_event=True)
@metrics.log_metrics
def lambda_handler(event: Dict[str, Any], context: LambdaContext) -> Dict[str, Any]:
    """
    Lambda entry point for the eavesdrop-detector function.
    
    Args:
        event: DynamoDB Stream event
        context: Lambda context
        
    Returns:
        Dict with processing results
    """
    logger.info("Eavesdrop detector invoked")
    
    # Process as DynamoDB Stream event
    dynamo_event = DynamoDBStreamEvent(event)
    
    # Set up analyzer
    analyzer = EavesdropAnalyzer(qber_threshold=DEFAULT_QBER_THRESHOLD)
    
    # Process each record
    results = {
        'processedRecords': 0,
        'detectionsStored': 0,
        'alertsSent': 0,
        'errors': 0
    }
    
    for record in dynamo_event.records:
        try:
            # Extract and process the session data
            session_data = process_session_record(record.raw_event)
            if not session_data:
                continue
                
            results['processedRecords'] += 1
            
            # Analyze for eavesdropping
            detection_result = analyzer.detect_eavesdropping(session_data)
            
            # Store the detection result
            if store_detection_result(detection_result):
                results['detectionsStored'] += 1
            
            # Send alert if compromised
            if detection_result.get('isCompromised', False):
                if send_alert(detection_result):
                    results['alertsSent'] += 1
                    
        except Exception as e:
            logger.exception(f"Error processing record: {e}")
            results['errors'] += 1
    
    logger.info(f"Eavesdrop detection completed: {results}")
    return results


# For local testing
if __name__ == '__main__':
    # Sample event for testing
    test_event = {
        "Records": [
            {
                "eventID": "1",
                "eventName": "INSERT",
                "eventVersion": "1.0",
                "eventSource": "aws:dynamodb",
                "awsRegion": "us-east-1",
                "dynamodb": {
                    "Keys": {
                        "sessionId": {"S": "test123456789"}
                    },
                    "NewImage": {
                        "sessionId": {"S": "test123456789"},
                        "timestamp": {"S": "2025-06-15T10:00:00Z"},
                        "estimatedQBER": {"S": "0.12"},
                        "siftedKeyLength": {"N": "2048"},
                        "correctedKeyLength": {"N": "1024"},
                        "finalKeyLength": {"N": "128"},
                        "status": {"S": "QKD process simulated successfully."}
                    },
                    "SequenceNumber": "111",
                    "SizeBytes": 26,
                    "StreamViewType": "NEW_AND_OLD_IMAGES"
                },
                "eventSourceARN": "arn:aws:dynamodb:us-east-1:123456789012:table/qkd-sessions/stream/2025-06-15T00:00:00.000"
            }
        ]
    }
    
    os.environ["EAVESDROP_DETECTIONS_TABLE"] = "eavesdrop-detections-table"
    # os.environ["ALERTS_SNS_TOPIC_ARN"] = "arn:aws:sns:us-east-1:123456789012:qkd-security-alerts"
    
    # Mock DynamoDB and SNS clients for local testing
    class MockDynamoDBClient:
        def put_item(self, TableName, Item):
            print(f"[MockDynamoDB] Storing item to {TableName}:")
            for key, value in Item.items():
                value_type = list(value.keys())[0]
                print(f"  {key}: {value[value_type]} ({value_type})")
            return {}
    
    class MockSNSClient:
        def publish(self, TopicArn, Message, Subject):
            print(f"[MockSNS] Publishing to {TopicArn}:")
            print(f"Subject: {Subject}")
            print(f"Message: {Message}")
            return {"MessageId": "mock-message-id"}
    
    # Use mocks for local testing
    dynamodb_client = MockDynamoDBClient()
    sns_client = MockSNSClient()
    
    # Invoke lambda handler
    result = lambda_handler(test_event, None)
    print(f"Lambda result: {result}")
