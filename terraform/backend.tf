# Backend configuration for Terraform state
#
# IMPORTANT: Before using this backend, you need to:
# 1. Create an S3 bucket for state storage
# 2. Create a DynamoDB table for state locking
#
# Run these AWS CLI commands:
#
# aws s3api create-bucket \
#   --bucket partridje-terraform-state-eu-west-1 \
#   --region eu-west-1 \
#   --create-bucket-configuration LocationConstraint=eu-west-1
#
# aws s3api put-bucket-versioning \
#   --bucket partridje-terraform-state-eu-west-1 \
#   --versioning-configuration Status=Enabled
#
# aws s3api put-bucket-encryption \
#   --bucket partridje-terraform-state-eu-west-1 \
#   --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
#
# aws dynamodb create-table \
#   --table-name terraform-state-lock \
#   --attribute-definitions AttributeName=LockID,AttributeType=S \
#   --key-schema AttributeName=LockID,KeyType=HASH \
#   --billing-mode PAY_PER_REQUEST \
#   --region eu-west-1

terraform {
  backend "s3" {
    bucket         = "partridje-terraform-state-eu-west-1"
    key            = "eks-production/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
