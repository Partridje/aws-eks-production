###############################################################################
# Remote State Data Sources
# Fetch outputs from previously deployed infrastructure
###############################################################################

# VPC outputs
data "terraform_remote_state" "vpc" {
  backend = "s3"

  config = {
    bucket = "eks-gitops-terraform-state-851725636341"
    key    = "dev/vpc/terraform.tfstate"
    region = "us-east-1"
  }
}

# IAM outputs
data "terraform_remote_state" "iam" {
  backend = "s3"

  config = {
    bucket = "eks-gitops-terraform-state-851725636341"
    key    = "dev/iam/terraform.tfstate"
    region = "us-east-1"
  }
}

# EKS Cluster outputs
data "terraform_remote_state" "eks" {
  backend = "s3"

  config = {
    bucket = "eks-gitops-terraform-state-851725636341"
    key    = "dev/eks-cluster/terraform.tfstate"
    region = "us-east-1"
  }
}
