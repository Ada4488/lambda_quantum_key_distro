# Testing Guide for Quantum KD Simulator

This guide provides comprehensive instructions for testing your quantum key distribution simulator before deployment.

## 🎯 Testing Strategy Overview

Our testing strategy includes multiple layers to ensure code quality and reliability:

1. **Unit Tests** - Test individual components and functions
2. **Integration Tests** - Test component interactions and AWS services
3. **Security Tests** - Scan for vulnerabilities and security issues
4. **Performance Tests** - Validate performance benchmarks
5. **Infrastructure Tests** - Validate Terraform configurations
6. **End-to-End Tests** - Test complete workflows in deployed environments

## 🚀 Quick Start

### Prerequisites

1. **Python 3.11+** with virtual environment
2. **Docker** (for LocalStack testing)
3. **AWS CLI** configured with appropriate credentials
4. **Terraform** installed

### Setup Testing Environment

```bash
# 1. Create and activate virtual environment
python -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate

# 2. Install development dependencies
pip install -r requirements-dev.txt

# 3. Set up local testing environment
./scripts/setup_local_testing.sh

# 4. Start LocalStack (for local AWS simulation)
docker-compose -f docker-compose.localstack.yml up -d

# 5. Initialize LocalStack
./scripts/init_localstack.sh
```

## 🧪 Running Tests

### Complete Test Suite

Run all tests with a single command:

```bash
./scripts/run_tests.sh
```

This script runs:
- Code formatting checks (Black)
- Linting (Flake8)
- Type checking (MyPy)
- Security scanning (Bandit, Safety)
- Unit tests with coverage
- Integration tests
- Performance benchmarks
- Infrastructure validation

### Individual Test Categories

#### Unit Tests
```bash
# Run all unit tests
pytest src/tests/test_qkd_simulator.py -v

# Run specific test class
pytest src/tests/test_qkd_simulator.py::TestBB84Protocol -v

# Run with coverage
pytest src/tests/test_qkd_simulator.py --cov=src/functions --cov-report=html
```

#### Integration Tests
```bash
# Run integration tests (requires LocalStack)
pytest src/tests/test_integration.py -v -m integration

# Run specific integration test
pytest src/tests/test_integration.py::TestQKDSimulatorIntegration::test_end_to_end_qkd_simulation -v
```

#### Security Tests
```bash
# Security vulnerability scan
bandit -r src/functions/ -f json -o bandit-report.json

# Check for known vulnerabilities
safety check --json --output safety-report.json
```

#### Performance Tests
```bash
# Run performance benchmarks
pytest src/tests/test_integration.py::TestQKDSimulatorIntegration::test_performance_benchmarks -v -s
```

### Local Testing with LocalStack

```bash
# Test against local AWS services
./scripts/test_local.sh

# Manual testing
python scripts/manual_test.py
```

## 🏗️ Infrastructure Testing

### Terraform Validation

```bash
cd terraform

# Format check
terraform fmt -check

# Validate configuration
terraform validate

# Plan (dry run)
terraform plan

# Security scan (if you have tfsec installed)
tfsec .
```

### Infrastructure as Code Tests

```bash
# Test Terraform modules
pytest terraform/tests/ -v  # (if you create Terraform tests)
```

## 🚀 Deployment Validation

### Pre-Deployment Checklist

Before deploying to any environment, ensure:

- [ ] All unit tests pass
- [ ] Integration tests pass
- [ ] Security scans show no critical issues
- [ ] Code coverage is above 80%
- [ ] Terraform configuration is valid
- [ ] Performance benchmarks meet requirements

### Post-Deployment Validation

After deploying to staging/production:

```bash
# Validate deployment
./scripts/validate_deployment.sh <environment>

# Examples:
./scripts/validate_deployment.sh dev
./scripts/validate_deployment.sh staging
./scripts/validate_deployment.sh prod
```

This script validates:
- Lambda functions are deployed and working
- DynamoDB tables are created and accessible
- KMS keys are available
- API Gateway endpoints are responding
- CloudWatch logging is configured
- End-to-end workflows function correctly

## 📊 Test Coverage and Reports

### Coverage Reports

After running tests with coverage:

```bash
# View HTML coverage report
open htmlcov/index.html

# View terminal coverage report
pytest --cov=src/functions --cov-report=term-missing
```

### Security Reports

- **Bandit Report**: `bandit-report.json`
- **Safety Report**: `safety-report.json`

### Test Reports

A comprehensive test report is generated at `test-report.md` after running the full test suite.

## 🔧 Debugging and Troubleshooting

### Common Issues

1. **Import Errors**: Ensure virtual environment is activated and dependencies are installed
2. **AWS Credential Issues**: Check AWS CLI configuration or LocalStack setup
3. **Docker Issues**: Ensure Docker is running for LocalStack tests
4. **Permission Issues**: Check IAM permissions for AWS resources

### Debug Mode

```bash
# Run tests with verbose output
pytest -v -s

# Run with debugging
pytest --pdb

# Run specific test with print statements
pytest src/tests/test_qkd_simulator.py::test_specific_function -v -s
```

### LocalStack Debugging

```bash
# Check LocalStack logs
docker logs qkd-localstack

# Check LocalStack health
curl http://localhost:4566/health

# List LocalStack services
curl http://localhost:4566/_localstack/health
```

## 🎯 Performance Benchmarks

Expected performance targets:

| Key Length | Max Execution Time | Min Key Rate |
|------------|-------------------|--------------|
| 32 bits    | 5 seconds        | 6 bits/sec   |
| 64 bits    | 10 seconds       | 6 bits/sec   |
| 128 bits   | 20 seconds       | 6 bits/sec   |

## 🔒 Security Testing

### Security Checklist

- [ ] No hardcoded secrets or credentials
- [ ] Input validation for all parameters
- [ ] Proper error handling without information leakage
- [ ] Secure random number generation
- [ ] Encrypted storage of sensitive data
- [ ] Proper IAM permissions (least privilege)

### Security Tools

- **Bandit**: Python security linter
- **Safety**: Checks for known vulnerabilities
- **AWS Config**: Infrastructure compliance (in AWS)
- **AWS Security Hub**: Centralized security findings

## 📈 Continuous Integration

For CI/CD pipelines, use:

```yaml
# Example GitHub Actions workflow
- name: Run Tests
  run: |
    pip install -r requirements-dev.txt
    ./scripts/run_tests.sh

- name: Validate Infrastructure
  run: |
    cd terraform
    terraform fmt -check
    terraform validate
```

## 🆘 Getting Help

If tests fail:

1. Check the test output for specific error messages
2. Review the generated reports (`test-report.md`, coverage reports)
3. Check CloudWatch logs for deployed functions
4. Use the manual testing script for debugging: `python scripts/manual_test.py`

## 📚 Additional Resources

- [AWS Lambda Testing Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/testing-guide.html)
- [Pytest Documentation](https://docs.pytest.org/)
- [LocalStack Documentation](https://docs.localstack.cloud/)
- [Terraform Testing](https://www.terraform.io/docs/language/modules/testing.html)
