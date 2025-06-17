#!/bin/bash

# Wait for LocalStack to be ready
if curl -s http://localhost:4566/health | grep -q '"status": "running"'; then
    echo "✅ LocalStack is running"
else
    echo "❌ LocalStack is NOT ready"
fi


# Set dummy AWS credentials and default region for AWS CLI
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1

# Create DynamoDB table
echo "Creating DynamoDB table..."
aws dynamodb create-table \
    --table-name qkd-sessions-table \
    --attribute-definitions \
        AttributeName=session_id,AttributeType=S \
    --key-schema \
        AttributeName=session_id,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --endpoint-url http://localhost:4566

# Create KMS key
echo "Creating KMS key..."
KMS_KEY=$(aws kms create-key \
    --description "QKD Simulator Test Key" \
    --endpoint-url http://localhost:4566 \
    --query 'KeyMetadata.KeyId' \
    --output text)

echo "KMS Key ID: $KMS_KEY"

# Create S3 bucket for Terraform state
echo "Creating S3 bucket for Terraform state..."
aws s3 mb s3://quantum-kd-terraform-state \
    --endpoint-url http://localhost:4566

# Save environment variables for local testing
echo "Saving environment variables to .env.local..."
cat > .env.local <<EOL
AWS_ACCESS_KEY_ID=test
AWS_SECRET_ACCESS_KEY=test
AWS_DEFAULT_REGION=us-east-1
AWS_ENDPOINT_URL=http://localhost:4566
DYNAMODB_TABLE_NAME=qkd-sessions-table
KMS_KEY_ARN=arn:aws:kms:us-east-1:000000000000:key/$KMS_KEY
EOL

echo "✅ LocalStack setup complete!"
echo "➡️  Environment variables saved to .env.local"
