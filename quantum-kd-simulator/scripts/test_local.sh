#!/bin/bash

# Test runner for local environment with LocalStack

set -e

echo "🧪 Running Local Tests with LocalStack"
echo "======================================"

# Load local environment variables
if [ -f .env.local ]; then
    export $(cat .env.local | xargs)
fi

# Activate virtual environment
source .venv/bin/activate

# Run tests against LocalStack
echo "Running unit tests..."
pytest src/tests/test_qkd_simulator.py -v

echo "Running integration tests against LocalStack..."
pytest src/tests/test_integration.py -v -m integration

echo "✅ Local tests completed!"
