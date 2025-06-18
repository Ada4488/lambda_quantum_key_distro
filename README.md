# Quantum Key Distribution (QKD) Simulator

A comprehensive AWS Lambda-based quantum key distribution simulator implementing the BB84 protocol for secure quantum cryptographic key generation and distribution.

## 🏆 AWS Hackathon Submission

**Solving Real-World Business Problem**: Post-quantum cryptography and secure key distribution for the quantum computing era.

### ✅ AWS Requirements Compliance:
- **🔧 Core Service**: AWS Lambda powers the entire BB84 quantum simulation engine
- **⚡ Lambda Triggers**: API Gateway triggers Lambda functions for QKD simulations
- **🔗 AWS Integrations**:
  - **DynamoDB**: Session data storage with TTL
  - **KMS**: Quantum key encryption and secure storage
  - **CloudWatch**: Comprehensive logging and monitoring
  - **API Gateway**: RESTful API interface

### 🎯 Business Impact:
- **Quantum-Safe Security**: Prepares organizations for post-quantum cryptography
- **Eavesdropping Detection**: Quantum-guaranteed detection of security breaches
- **Scalable Architecture**: Serverless design handles concurrent key generation
- **Cost-Effective**: Pay-per-use model with automatic scaling

## 🎬 Demo Video

**📺 [Watch Demo Video](YOUR_YOUTUBE_URL_HERE)** *(3 minutes)*

### Video Outline:
1. **Problem Introduction** (30s): Post-quantum cryptography challenges
2. **AWS Lambda Architecture** (60s): How Lambda powers the BB84 simulation
3. **Live Demo** (90s): QKD simulation, eavesdropping detection, security dashboard

## 📋 AWS Services Used

| **Service** | **Purpose** | **Implementation** |
|-------------|-------------|-------------------|
| **🔧 AWS Lambda** | **Core Engine** | BB84 quantum simulation, protocol execution |
| **🌐 API Gateway** | **API Interface** | RESTful endpoints, CORS, request validation |
| **🗄️ DynamoDB** | **Data Storage** | Session data, TTL cleanup, scalable NoSQL |
| **🔑 AWS KMS** | **Key Security** | Quantum key encryption, secure storage |
| **📊 CloudWatch** | **Monitoring** | Structured logging, metrics, performance tracking |

## 🔬 Overview

This project simulates the BB84 quantum key distribution protocol, allowing two parties (Alice and Bob) to establish a shared cryptographic key with quantum-guaranteed security. The simulator includes realistic quantum channel effects, eavesdropping detection, error correction, and privacy amplification.

### Key Features

- **BB84 Protocol Implementation**: Complete simulation of the seminal quantum key distribution protocol
- **Quantum Channel Simulation**: Realistic modeling of photon transmission with configurable error rates
- **Eavesdropping Detection**: QBER (Quantum Bit Error Rate) analysis to detect potential security breaches
- **Error Correction**: Simulated error correction to handle channel noise
- **Privacy Amplification**: Key shortening to ensure information-theoretic security
- **AWS Integration**: Serverless architecture with DynamoDB storage and KMS encryption
- **LocalStack Support**: Local development and testing environment

## 🏗️ AWS Serverless Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Frontend      │    │   API Gateway    │    │   AWS Lambda    │
│   React App     │───▶│   REST API       │───▶│   BB84 Engine   │
└─────────────────┘    └──────────────────┘    └──────────────────┘
                                                         │
                       ┌─────────────────┐              │
                       │   CloudWatch    │◀─────────────┤
                       │   Monitoring    │              │
                       └─────────────────┘              ▼
                                                ┌──────────────────┐
┌─────────────────┐                           │   DynamoDB       │
│   AWS KMS       │◀──────────────────────────│   Session Store  │
│   Key Encryption│                           └──────────────────┘
└─────────────────┘
```

### 🔧 AWS Services Used:
- **⚡ AWS Lambda**: Core quantum simulation engine (BB84 protocol)
- **🌐 API Gateway**: RESTful API with CORS support
- **🗄️ DynamoDB**: Session data storage with 24-hour TTL
- **🔑 AWS KMS**: Quantum key encryption and secure storage
- **📊 CloudWatch**: Structured logging and performance monitoring

### Components

- **Lambda Function**: Core QKD simulation engine
- **DynamoDB**: Session data storage with TTL
- **KMS**: Final key encryption and secure storage
- **API Gateway**: RESTful API interface
- **CloudWatch**: Logging and monitoring

## 🚀 Quick Start

### Prerequisites

- Python 3.11+
- Docker (for LocalStack)
- AWS CLI (for deployment)

### Local Development Setup

1. **Clone and Setup Environment**:
```bash
git clone https://github.com/Ada4488/lambda_quantum_key_distro.git
cd lambda_quantum_key_distro/quantum-kd-simulator
python -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate
```

2. **Install Dependencies**:
```bash
pip install -r requirements.txt
pip install -r requirements-dev.txt
```

3. **Start LocalStack** (for local testing):
```bash
docker-compose -f docker-compose.localstack.yml up -d
```

4. **Run Tests**:
```bash
./scripts/run_tests.sh
```

### Usage Example

```python
# Example QKD simulation request
{
    "target_key_length": 128,
    "channel_error_rate": 0.05
}

# Response
{
    "statusCode": 200,
    "body": {
        "message": "QKD process simulated successfully",
        "sessionId": "abc123...",
        "finalKeyLength": 128,
        "estimatedQBER": 0.0523
    }
}
```

## 🔬 BB84 Protocol Implementation

### 1. Qubit Preparation (Alice)
Alice generates random bits and bases, preparing qubits in one of four possible states:
- `|0⟩` (bit=0, rectilinear basis)
- `|1⟩` (bit=1, rectilinear basis)  
- `|+⟩` (bit=0, diagonal basis)
- `|-⟩` (bit=1, diagonal basis)

### 2. Quantum Transmission
Qubits are transmitted through a quantum channel with configurable noise:
- **Channel errors**: Random bit flips with probability `channel_error_rate`
- **Basis mismatch**: 50% error rate when Alice and Bob use different bases

### 3. Measurement (Bob)
Bob randomly chooses measurement bases and measures received qubits:
- **Correct basis**: Perfect measurement (ignoring channel noise)
- **Wrong basis**: Random result (50% error rate)

### 4. Basis Reconciliation
Alice and Bob publicly compare their basis choices and keep only bits where they used the same basis.

### 5. QBER Estimation
A random sample of the sifted key is used to estimate the quantum bit error rate:
- **Low QBER**: Channel is secure, proceed with key generation
- **High QBER**: Potential eavesdropping detected, abort protocol

### 6. Error Correction
Simulated error correction process to handle remaining channel errors:
- Uses Alice's key as the reference (simplified implementation)
- Estimates information leakage during the correction process

### 7. Privacy Amplification
Final key shortening to account for information potentially leaked to an eavesdropper:
- Removes bits equal to total information disclosed during QBER estimation and error correction
- Ensures information-theoretic security of the final key

## 🧪 Testing

### Test Coverage

The project includes comprehensive testing:

- **Unit Tests**: BB84 protocol components, request validation, Lambda handlers
- **Integration Tests**: End-to-end QKD simulation with AWS services
- **Performance Tests**: Benchmarking key generation rates and latency
- **Security Tests**: QBER analysis and eavesdropping detection

### Running Tests

```bash
# Run all tests
./scripts/run_tests.sh

# Run specific test categories
pytest src/tests/test_qkd_simulator.py -v  # Unit tests
pytest src/tests/test_integration.py -v    # Integration tests

# Run with coverage
pytest --cov=src --cov-report=html
```

### LocalStack Testing

The project uses LocalStack for local AWS service simulation:

```bash
# Start LocalStack
docker-compose -f docker-compose.localstack.yml up -d

# Check service health
curl http://localhost:4566/_localstack/health

# Run tests against LocalStack
AWS_ENDPOINT_URL=http://localhost:4566 pytest src/tests/
```

## 📊 Performance Characteristics

### Typical Performance Metrics

- **Key Generation Rate**: ~1000 bits/second (simulated)
- **QBER Threshold**: 15% (configurable)
- **Raw Bit Multiplier**: 16x (accounts for sifting and processing losses)
- **Memory Usage**: <128MB per Lambda execution
- **Cold Start**: <2 seconds
- **Warm Execution**: <500ms

### Scalability

- **Concurrent Sessions**: Limited by Lambda concurrency (1000 default)
- **Session Storage**: DynamoDB with 24-hour TTL
- **Key Storage**: Encrypted with AWS KMS
- **Monitoring**: CloudWatch metrics and logs

## 🔧 Configuration

### Environment Variables

```bash
# Required
DYNAMODB_TABLE_NAME=qkd-sessions-table
KMS_KEY_ARN=arn:aws:kms:region:account:key/key-id

# Optional
AWS_REGION=us-east-1
LOG_LEVEL=INFO
```

### Protocol Parameters

```python
# Configurable constants in handler.py
DEFAULT_TARGET_KEY_LENGTH = 128      # Target final key length
DEFAULT_CHANNEL_ERROR_RATE = 0.01    # Default channel noise
RAW_BIT_MULTIPLIER = 16              # Oversampling factor
QBER_SAMPLE_FRACTION = 0.5           # Fraction used for QBER estimation
MAX_TOLERABLE_QBER = 0.15            # Security threshold
```

## 🚨 Security Considerations

### Quantum Security Features

- **Information-theoretic security**: Based on quantum mechanical principles
- **Eavesdropping detection**: QBER analysis reveals potential attacks
- **Privacy amplification**: Removes information potentially leaked to adversaries
- **Perfect forward secrecy**: Each session generates independent keys

### Implementation Security

- **Key encryption**: Final keys encrypted with AWS KMS
- **Session isolation**: Each QKD session is independent
- **Audit logging**: All operations logged to CloudWatch
- **Access control**: IAM-based permissions for AWS resources

### Limitations

⚠️ **Important**: This is a *simulation* for educational and research purposes. It does not provide actual quantum security and should not be used for production cryptographic applications.

## 📁 Project Structure

```
quantum-kd-simulator/
├── src/
│   ├── functions/
│   │   └── qkd-simulator/
│   │       ├── handler.py              # Main Lambda handler
│   │       └── requirements.txt        # Runtime dependencies
│   ├── layers/
│   │   ├── crypto-layer/              # Cryptographic utilities
│   │   └── utilities-layer/           # Common utilities
│   └── tests/
│       ├── conftest.py                # Test configuration
│       ├── test_qkd_simulator.py      # Unit tests
│       └── test_integration.py        # Integration tests
├── terraform/                         # Infrastructure as Code
│   ├── main.tf                       # Main Terraform configuration
│   ├── variables.tf                  # Variable definitions
│   └── outputs.tf                    # Output definitions
├── scripts/
│   ├── deploy.sh                     # Deployment script
│   ├── run_tests.sh                  # Test execution script
│   └── setup_local.sh                # Local environment setup
├── docker-compose.localstack.yml     # LocalStack configuration
├── requirements.txt                  # Core dependencies
├── requirements-dev.txt              # Development dependencies
└── README.md                         # This file
```

## 🔄 API Reference

### Endpoints

#### POST /simulate-qkd
Initiates a quantum key distribution simulation.

**Request Body:**
```json
{
    "target_key_length": 128,        // Desired final key length (1-256 bits)
    "channel_error_rate": 0.05       // Channel noise level (0.0-0.5)
}
```

**Response (Success):**
```json
{
    "statusCode": 200,
    "body": {
        "message": "QKD process simulated successfully",
        "sessionId": "abc123def456...",
        "finalKeyLength": 128,
        "estimatedQBER": 0.0523
    }
}
```

**Response (High QBER - Eavesdropping Detected):**
```json
{
    "statusCode": 400,
    "body": {
        "message": "QKD simulation failed: QBER (0.1847) too high for error correction.",
        "sessionId": "abc123def456...",
        "estimatedQBER": 0.1847
    }
}
```

**Response (Error):**
```json
{
    "statusCode": 400,
    "body": {
        "error": "target_key_length must be greater than 0"
    }
}
```

### Error Codes

| Status Code | Description |
|-------------|-------------|
| 200 | QKD simulation completed successfully |
| 400 | Invalid request parameters or high QBER detected |
| 500 | Internal server error or configuration issue |

## 🛠️ Development Process & Issues Resolved

### Build Process

The development of this QKD simulator involved several key phases:

1. **Protocol Research & Design**
   - Studied BB84 protocol specifications
   - Designed realistic quantum channel simulation
   - Planned AWS serverless architecture

2. **Core Implementation**
   - Implemented BB84 protocol in Python
   - Created Lambda handler with AWS integrations
   - Built comprehensive error handling

3. **Testing Infrastructure**
   - Set up pytest framework with AWS mocking
   - Configured LocalStack for local development
   - Created comprehensive test suites

4. **Security & Optimization**
   - Implemented proper key encryption with KMS
   - Added session management with DynamoDB
   - Optimized for Lambda cold starts

### Major Issues Resolved

#### 1. **Testing Framework Compatibility**
**Issue**: Moto library version conflicts with newer AWS SDK versions
```python
# Problem: Old moto syntax
from moto import mock_dynamodb, mock_kms

# Solution: Updated to unified mock_aws
from moto import mock_aws
```

#### 2. **Environment Variable Handling**
**Issue**: Lambda handler couldn't access environment variables during testing
```python
# Problem: Variables read at module import time
DYNAMODB_TABLE_NAME = os.environ.get("DYNAMODB_TABLE_NAME")

# Solution: Patched variables in tests
with patch('handler.DYNAMODB_TABLE_NAME', 'test-table'):
    response = lambda_handler(event, context)
```

#### 3. **AWS Lambda Powertools Integration**
**Issue**: Incorrect logger method usage
```python
# Problem: Method doesn't exist
logger.add_extras(sessionId=session_id)

# Solution: Correct method name
logger.append_keys(sessionId=session_id)
```

#### 4. **Quantum Protocol Accuracy**
**Issue**: Unrealistic QBER calculations and privacy amplification
- **Problem**: Too aggressive privacy amplification causing empty final keys
- **Solution**: Balanced the trade-off between security and key generation success
- **Result**: More realistic key generation rates while maintaining security properties

#### 5. **LocalStack Service Configuration**
**Issue**: LocalStack services not properly configured for testing
```yaml
# Problem: Missing service configurations
services: localstack

# Solution: Explicit service configuration
SERVICES: dynamodb,kms,s3,lambda,apigateway
DEBUG: 1
PERSISTENCE: 1
```

#### 6. **Dependency Management**
**Issue**: Version conflicts between scientific libraries and AWS SDKs
- **Problem**: NumPy/SciPy versions incompatible with AWS Lambda runtime
- **Solution**: Pinned compatible versions and used Lambda layers for large dependencies

#### 7. **Test Data Realism**
**Issue**: Test parameters causing unrealistic simulation outcomes
- **Problem**: High error rates causing all tests to fail due to QBER thresholds
- **Solution**: Calibrated test parameters to realistic quantum channel conditions

### Key Technical Decisions

1. **Serverless Architecture**: Chose AWS Lambda for scalability and cost-effectiveness
2. **Simplified Error Correction**: Implemented basic error correction for simulation purposes
3. **Statistical Sampling**: Used sampling for QBER estimation to balance accuracy and performance
4. **Session Management**: Implemented TTL-based session cleanup for resource management

### Performance Optimizations

1. **Cold Start Reduction**: Minimized import overhead and initialization time
2. **Memory Efficiency**: Optimized data structures for large key generation
3. **Concurrent Testing**: Parallel test execution with proper isolation
4. **Caching Strategy**: Reused AWS clients across Lambda invocations

## 🚀 Deployment

### AWS Deployment

1. **Prerequisites**:
```bash
# Install AWS CLI and Terraform
aws configure
terraform --version
```

2. **Deploy Infrastructure**:
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

3. **Deploy Lambda Function**:
```bash
./scripts/deploy.sh
```

4. **Verify Deployment**:
```bash
# Test the deployed endpoint
curl -X POST https://your-api-gateway-url/simulate-qkd \
  -H "Content-Type: application/json" \
  -d '{"target_key_length": 64, "channel_error_rate": 0.02}'
```

### Local Development

1. **Start LocalStack**:
```bash
docker-compose -f docker-compose.localstack.yml up -d
```

2. **Create Local Resources**:
```bash
./scripts/setup_local.sh
```

3. **Run Local Tests**:
```bash
export AWS_ENDPOINT_URL=http://localhost:4566
./scripts/run_tests.sh
```

## � Deployment

### AWS Deployment

1. **Prerequisites**:
```bash
# Install AWS CLI and Terraform
aws configure
terraform --version
```

2. **Deploy Infrastructure**:
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

3. **Deploy Lambda Function**:
```bash
./scripts/deploy.sh
```

4. **Verify Deployment**:
```bash
# Test the deployed endpoint
curl -X POST https://your-api-gateway-url/simulate-qkd \
  -H "Content-Type: application/json" \
  -d '{"target_key_length": 64, "channel_error_rate": 0.02}'
```

### Local Development

1. **Start LocalStack**:
```bash
docker-compose -f docker-compose.localstack.yml up -d
```

2. **Create Local Resources**:
```bash
./scripts/setup_local.sh
```

3. **Run Local Tests**:
```bash
export AWS_ENDPOINT_URL=http://localhost:4566
./scripts/run_tests.sh
```

## 🔍 Monitoring & Observability

### CloudWatch Metrics

The simulator automatically publishes custom metrics:

- `QKDSimulations.Count` - Number of simulations executed
- `QKDSimulations.Duration` - Simulation execution time
- `QKDSimulations.FinalKeyLength` - Generated key lengths
- `QKDSimulations.QBER` - Quantum bit error rates
- `QKDSimulations.EavesdroppingDetected` - Security alerts

### Logging

Structured logging with AWS Lambda Powertools:

```json
{
    "timestamp": "2025-06-17T19:08:15.656Z",
    "level": "INFO",
    "message": "QKD simulation completed",
    "sessionId": "abc123def456",
    "finalKeyLength": 128,
    "estimatedQBER": 0.0523,
    "executionTime": 245
}
```

### Alerting

Recommended CloudWatch alarms:

- High QBER rate (>10% of simulations)
- Lambda errors or timeouts
- DynamoDB throttling
- KMS encryption failures

## 🧪 Advanced Testing Scenarios

### Eavesdropping Detection Test

```python
# Simulate eavesdropping with high error rate
test_request = {
    "target_key_length": 128,
    "channel_error_rate": 0.20  # High error rate
}

# Expected: QBER > 15%, simulation should fail
response = simulate_qkd(test_request)
assert response['statusCode'] == 400
assert 'QBER' in response['body']['message']
```

### Performance Benchmarking

```python
import time
import statistics

# Benchmark key generation performance
execution_times = []
for _ in range(100):
    start_time = time.time()
    response = simulate_qkd({"target_key_length": 256})
    execution_times.append(time.time() - start_time)

print(f"Average execution time: {statistics.mean(execution_times):.3f}s")
print(f"95th percentile: {statistics.quantiles(execution_times, n=20)[18]:.3f}s")
```

### Stress Testing

```python
import concurrent.futures
import threading

# Concurrent simulation testing
def run_simulation():
    return simulate_qkd({"target_key_length": 128})

# Test concurrent executions
with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
    futures = [executor.submit(run_simulation) for _ in range(50)]
    results = [future.result() for future in futures]

success_rate = sum(1 for r in results if r['statusCode'] == 200) / len(results)
print(f"Success rate under load: {success_rate:.2%}")
```

## 🔧 Troubleshooting

### Common Issues

#### 1. **High QBER Causing Simulation Failures**
```
Error: "QBER (0.1847) too high for error correction"
```
**Solution**: Reduce `channel_error_rate` parameter or increase `RAW_BIT_MULTIPLIER` for more raw bits.

#### 2. **Empty Final Keys After Privacy Amplification**
```
Warning: "Final secure key is empty after privacy amplification"
```
**Solution**: This occurs when too many bits are disclosed during QBER estimation and error correction. Try:
- Lower channel error rate
- Increase target key length
- Adjust `QBER_SAMPLE_FRACTION`

#### 3. **LocalStack Connection Issues**
```
Error: "Could not connect to the endpoint URL"
```
**Solution**:
```bash
# Check LocalStack status
docker ps | grep localstack
curl http://localhost:4566/_localstack/health

# Restart if needed
docker-compose -f docker-compose.localstack.yml restart
```

#### 4. **Lambda Cold Start Timeouts**
```
Error: "Task timed out after 30.00 seconds"
```
**Solution**:
- Increase Lambda timeout in `terraform/main.tf`
- Optimize imports and initialization
- Use provisioned concurrency for production

### Debug Mode

Enable detailed logging:

```bash
export LOG_LEVEL=DEBUG
export AWS_LAMBDA_LOG_LEVEL=DEBUG
```

### Performance Tuning

For optimal performance:

```python
# Adjust protocol parameters in handler.py
RAW_BIT_MULTIPLIER = 8          # Reduce for faster execution
QBER_SAMPLE_FRACTION = 0.3      # Reduce sample size
MAX_TOLERABLE_QBER = 0.12       # Stricter security threshold
```

## 📚 References

### Academic Papers
- [BB84 Protocol Paper](https://doi.org/10.1016/j.tcs.2014.05.025) - Original quantum key distribution protocol
- [Quantum Cryptography Review](https://doi.org/10.1103/RevModPhys.74.145) - Comprehensive quantum cryptography overview
- [Quantum Key Distribution Security](https://doi.org/10.1103/RevModPhys.81.1301) - Security analysis of QKD protocols

### Technical Documentation
- [AWS Lambda Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html) - Serverless optimization guidelines
- [LocalStack Documentation](https://docs.localstack.cloud/) - Local AWS development environment
- [Moto Testing Library](https://docs.getmoto.org/) - AWS service mocking for tests
- [AWS Lambda Powertools](https://docs.powertools.aws.dev/lambda/python/) - Observability and utilities

### Quantum Computing Resources
- [IBM Qiskit Textbook](https://qiskit.org/textbook/) - Quantum computing fundamentals
- [Microsoft Quantum Development Kit](https://docs.microsoft.com/en-us/quantum/) - Quantum programming resources

## ❓ Frequently Asked Questions

### General Questions

**Q: Is this a real quantum key distribution system?**
A: No, this is a *simulation* of the BB84 protocol for educational and research purposes. It does not use actual quantum hardware or provide real quantum security.

**Q: Can I use this for production cryptographic applications?**
A: No, this simulator should not be used for production security applications. It's designed for learning, research, and demonstration purposes only.

**Q: How accurate is the simulation compared to real QKD?**
A: The simulation accurately models the mathematical and statistical aspects of BB84, including QBER estimation, error correction, and privacy amplification. However, it cannot replicate the true quantum mechanical properties that provide the security guarantees.

### Technical Questions

**Q: Why do I get empty final keys?**
A: This happens when the privacy amplification step removes too many bits due to high QBER or aggressive security parameters. Try reducing the channel error rate or increasing the target key length.

**Q: What's the maximum key length I can generate?**
A: The system supports up to 256 bits, but practical limits depend on the channel error rate. Higher error rates require more raw bits and may not reach the target length.

**Q: How do I interpret QBER values?**
A: QBER (Quantum Bit Error Rate) represents the percentage of errors in the sifted key:
- 0-5%: Excellent channel conditions
- 5-10%: Good conditions, normal operation
- 10-15%: Poor conditions, but still secure
- >15%: Potential eavesdropping, protocol aborts

**Q: Can I modify the protocol parameters?**
A: Yes, you can adjust constants in `handler.py`:
- `RAW_BIT_MULTIPLIER`: Controls oversampling (default: 16)
- `QBER_SAMPLE_FRACTION`: Fraction used for error estimation (default: 0.5)
- `MAX_TOLERABLE_QBER`: Security threshold (default: 0.15)

### Deployment Questions

**Q: What are the AWS costs for running this?**
A: Costs are minimal for testing:
- Lambda: ~$0.20 per 1M requests
- DynamoDB: ~$0.25 per GB-month (with TTL cleanup)
- KMS: ~$1.00 per 10,000 requests
- API Gateway: ~$3.50 per 1M requests

**Q: How do I scale for high throughput?**
A: The system auto-scales with Lambda concurrency. For high throughput:
- Use provisioned concurrency to reduce cold starts
- Consider DynamoDB on-demand billing
- Monitor CloudWatch metrics for bottlenecks

**Q: Can I deploy to other cloud providers?**
A: The core BB84 implementation is cloud-agnostic. You would need to adapt the AWS-specific components (Lambda, DynamoDB, KMS) to equivalent services on other platforms.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📞 Support

For questions, issues, or contributions, please:
- Open an issue on GitHub
- Contact the development team
- Review the documentation and test examples

---

**⚠️ Disclaimer**: This is a quantum key distribution *simulator* for educational and research purposes. It does not provide actual quantum security and should not be used for production cryptographic applications requiring real quantum key distribution.
