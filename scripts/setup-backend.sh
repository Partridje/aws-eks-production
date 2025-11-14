#!/bin/bash
# Setup S3 backend and DynamoDB table for Terraform state
# This script creates the infrastructure needed for Terraform remote state

set -e

# Configuration
AWS_REGION="${AWS_REGION:-eu-west-1}"
BUCKET_NAME="${BUCKET_NAME:-partridje-terraform-state-eu-west-1}"
DYNAMODB_TABLE="${DYNAMODB_TABLE:-terraform-state-lock}"
PROJECT_NAME="aws-eks-production"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🚀 Setting up Terraform backend infrastructure..."
echo ""
echo "Configuration:"
echo "  Region: $AWS_REGION"
echo "  S3 Bucket: $BUCKET_NAME"
echo "  DynamoDB Table: $DYNAMODB_TABLE"
echo ""

# Verify AWS credentials
echo "🔐 Verifying AWS credentials..."
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}❌ AWS credentials not configured${NC}"
    echo "Please configure AWS credentials first:"
    echo "  aws configure"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${GREEN}✅ Authenticated as Account: $ACCOUNT_ID${NC}"
echo ""

# Create S3 bucket
echo "📦 Creating S3 bucket: $BUCKET_NAME"
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo -e "${YELLOW}⚠️  Bucket already exists${NC}"
else
    aws s3api create-bucket \
      --bucket "$BUCKET_NAME" \
      --region "$AWS_REGION" \
      --create-bucket-configuration LocationConstraint="$AWS_REGION"
    echo -e "${GREEN}✅ Bucket created${NC}"
fi

# Enable versioning
echo ""
echo "🔄 Enabling versioning on S3 bucket..."
aws s3api put-bucket-versioning \
  --bucket "$BUCKET_NAME" \
  --versioning-configuration Status=Enabled
echo -e "${GREEN}✅ Versioning enabled${NC}"

# Enable encryption
echo ""
echo "🔒 Enabling encryption on S3 bucket..."
aws s3api put-bucket-encryption \
  --bucket "$BUCKET_NAME" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      },
      "BucketKeyEnabled": true
    }]
  }'
echo -e "${GREEN}✅ Encryption enabled${NC}"

# Block public access
echo ""
echo "🚫 Blocking public access to S3 bucket..."
aws s3api put-public-access-block \
  --bucket "$BUCKET_NAME" \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
echo -e "${GREEN}✅ Public access blocked${NC}"

# Enable bucket logging (optional but recommended)
echo ""
echo "📝 Configuring bucket logging..."
LOGS_BUCKET="${BUCKET_NAME}-logs"
if ! aws s3api head-bucket --bucket "$LOGS_BUCKET" 2>/dev/null; then
    echo "  Creating logs bucket: $LOGS_BUCKET"
    aws s3api create-bucket \
      --bucket "$LOGS_BUCKET" \
      --region "$AWS_REGION" \
      --create-bucket-configuration LocationConstraint="$AWS_REGION" || true

    aws s3api put-bucket-acl \
      --bucket "$LOGS_BUCKET" \
      --grant-write URI=http://acs.amazonaws.com/groups/s3/LogDelivery \
      --grant-read-acp URI=http://acs.amazonaws.com/groups/s3/LogDelivery || true
fi

aws s3api put-bucket-logging \
  --bucket "$BUCKET_NAME" \
  --bucket-logging-status "{
    \"LoggingEnabled\": {
      \"TargetBucket\": \"$LOGS_BUCKET\",
      \"TargetPrefix\": \"terraform-state-logs/\"
    }
  }" 2>/dev/null || echo -e "${YELLOW}⚠️  Bucket logging skipped${NC}"

# Apply lifecycle policy
echo ""
echo "♻️  Configuring lifecycle policy..."
aws s3api put-bucket-lifecycle-configuration \
  --bucket "$BUCKET_NAME" \
  --lifecycle-configuration '{
    "Rules": [
      {
        "Id": "DeleteOldVersions",
        "Status": "Enabled",
        "NoncurrentVersionExpiration": {
          "NoncurrentDays": 90
        }
      },
      {
        "Id": "AbortIncompleteMultipartUpload",
        "Status": "Enabled",
        "AbortIncompleteMultipartUpload": {
          "DaysAfterInitiation": 7
        }
      }
    ]
  }'
echo -e "${GREEN}✅ Lifecycle policy applied${NC}"

# Add tags to S3 bucket
echo ""
echo "🏷️  Adding tags to S3 bucket..."
aws s3api put-bucket-tagging \
  --bucket "$BUCKET_NAME" \
  --tagging "TagSet=[
    {Key=Project,Value=$PROJECT_NAME},
    {Key=ManagedBy,Value=Terraform},
    {Key=Purpose,Value=TerraformState},
    {Key=Environment,Value=all}
  ]"
echo -e "${GREEN}✅ Tags added${NC}"

# Create DynamoDB table
echo ""
echo "🗄️  Creating DynamoDB table: $DYNAMODB_TABLE"
if aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --region "$AWS_REGION" &>/dev/null; then
    echo -e "${YELLOW}⚠️  Table already exists${NC}"
else
    aws dynamodb create-table \
      --table-name "$DYNAMODB_TABLE" \
      --attribute-definitions AttributeName=LockID,AttributeType=S \
      --key-schema AttributeName=LockID,KeyType=HASH \
      --billing-mode PAY_PER_REQUEST \
      --region "$AWS_REGION" \
      --tags "Key=Project,Value=$PROJECT_NAME" \
            "Key=ManagedBy,Value=Terraform" \
            "Key=Purpose,Value=StateLocking"

    echo "  Waiting for table to be active..."
    aws dynamodb wait table-exists --table-name "$DYNAMODB_TABLE" --region "$AWS_REGION"
    echo -e "${GREEN}✅ Table created${NC}"
fi

# Enable Point-in-Time Recovery for DynamoDB
echo ""
echo "⏰ Enabling Point-in-Time Recovery for DynamoDB..."
aws dynamodb update-continuous-backups \
  --table-name "$DYNAMODB_TABLE" \
  --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true \
  --region "$AWS_REGION"
echo -e "${GREEN}✅ Point-in-Time Recovery enabled${NC}"

echo ""
echo -e "${GREEN}✅ Terraform backend setup complete!${NC}"
echo ""
echo "════════════════════════════════════════════════════════════"
echo "Backend Configuration:"
echo "════════════════════════════════════════════════════════════"
echo "  S3 Bucket:       $BUCKET_NAME"
echo "  DynamoDB Table:  $DYNAMODB_TABLE"
echo "  Region:          $AWS_REGION"
echo "  Account ID:      $ACCOUNT_ID"
echo ""
echo "Add this to your terraform backend configuration:"
echo ""
echo "terraform {"
echo "  backend \"s3\" {"
echo "    bucket         = \"$BUCKET_NAME\""
echo "    key            = \"path/to/terraform.tfstate\""
echo "    region         = \"$AWS_REGION\""
echo "    encrypt        = true"
echo "    dynamodb_table = \"$DYNAMODB_TABLE\""
echo "  }"
echo "}"
echo ""
echo "════════════════════════════════════════════════════════════"
