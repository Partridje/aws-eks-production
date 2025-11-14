###############################################################################
# Development Environment - Node Groups Backend Configuration
###############################################################################

terraform {
  backend "s3" {
    bucket         = "eks-gitops-terraform-state-851725636341"
    key            = "dev/node-groups/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "eks-gitops-terraform-locks"
    encrypt        = true
  }
}
