###############################################################################
# Terraform Backend Configuration
###############################################################################

# Prerequisite:
# 1. Go to `terraform/backend-setup`
# 2. Run `terraform init` and `terraform apply` to create the S3 bucket and DynamoDB table.
# 3. Get the bucket name from the output (e.g., eks-gitops-terraform-state-123456789012).

# Usage:
# Uncomment the block below and replace <ACCOUNT_ID> with your AWS Account ID.
# Or run `terraform init` with backend-config arguments.

# terraform {
#   backend "s3" {
#     bucket         = "eks-gitops-terraform-state-<ACCOUNT_ID>"
#     key            = "dev/terraform.tfstate"
#     region         = "us-east-1"
#     dynamodb_table = "eks-gitops-terraform-locks"
#     encrypt        = true
#   }
# }
