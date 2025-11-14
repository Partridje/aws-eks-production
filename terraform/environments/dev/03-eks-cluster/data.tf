###############################################################################
# Remote State Data Sources
# Fetch outputs from previously deployed infrastructure
###############################################################################

# VPC outputs (01-vpc or just vpc/)
data "terraform_remote_state" "vpc" {
  backend = "s3"

  config = {
    bucket = "eks-gitops-terraform-state-851725636341"
    key    = "dev/vpc/terraform.tfstate"
    region = "us-east-1"
  }
}

# IAM outputs (02-iam/)
data "terraform_remote_state" "iam" {
  backend = "s3"

  config = {
    bucket = "eks-gitops-terraform-state-851725636341"
    key    = "dev/iam/terraform.tfstate"
    region = "us-east-1"
  }
}
