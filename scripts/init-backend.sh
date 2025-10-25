#!/bin/bash

set -e

# Initialize Terraform backend (S3 + DynamoDB)

ENVIRONMENT=$1
REGION=${2:-us-east-1}

if [ -z "$ENVIRONMENT" ]; then
    echo "Usage: $0  [region]"
    echo "Example: $0 dev us-east-1"
    exit 1
fi

BUCKET_NAME="my-company-terraform-state-psb-${ENVIRONMENT}"
DYNAMODB_TABLE="terraform-state-lock-${ENVIRONMENT}"

echo "Creating S3 bucket: ${BUCKET_NAME}"

# Create S3 bucket
aws s3api create-bucket \
    --bucket ${BUCKET_NAME} \
    --region ${REGION}

# Enable versioning
aws s3api put-bucket-versioning \
    --bucket ${BUCKET_NAME} \
    --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
    --bucket ${BUCKET_NAME} \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            }
        }]
    }'

# Block public access
aws s3api put-public-access-block \
    --bucket ${BUCKET_NAME} \
    --public-access-block-configuration \
        BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# Enable lifecycle policy
aws s3api put-bucket-lifecycle-configuration \
    --bucket ${BUCKET_NAME} \
    --lifecycle-configuration '{
        "Rules": [
            {
                "ID": "DeleteOldVersions",
                "Status": "Enabled",
                "Filter": {
                    "Prefix": ""
                },
                "NoncurrentVersionExpiration": {
                    "NoncurrentDays": 90
                }
            }
        ]
    }'

echo "Creating DynamoDB table: ${DYNAMODB_TABLE}"

# Create DynamoDB table for state locking
aws dynamodb create-table \
    --table-name ${DYNAMODB_TABLE} \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
    --region ${REGION} \
    --tags Key=Environment,Value=${ENVIRONMENT} Key=ManagedBy,Value=Terraform 2>/dev/null || echo "Table already exists"

echo "✅ Backend initialized successfully!"
echo ""
echo "Update your backend.tf with:"
echo "  bucket         = \"${BUCKET_NAME}\""
echo "  dynamodb_table = \"${DYNAMODB_TABLE}\""
echo "  region         = \"${REGION}\""