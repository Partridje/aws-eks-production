###############################################################################
# Terraform Backend Configuration
#
# ⚠️  WARNING: Deploy only via GitHub Actions after initial setup
#
# This configuration stores Terraform state in S3 with DynamoDB locking
# State file: s3://eks-gitops-terraform-state-851725636341/dev/vpc/terraform.tfstate
###############################################################################

terraform {
  backend "s3" {
    bucket         = "eks-gitops-terraform-state-851725636341"
    key            = "dev/vpc/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "eks-gitops-terraform-locks"
    encrypt        = true
  }
}
