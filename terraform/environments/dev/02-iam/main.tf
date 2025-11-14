###############################################################################
# Development Environment - IAM Configuration for EKS
#
# ⚠️  Deploy only via GitHub Actions
###############################################################################

terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

###############################################################################
# Provider Configuration
###############################################################################

provider "aws" {
  region = var.region

  default_tags {
    tags = local.common_tags
  }
}

###############################################################################
# Data Sources
###############################################################################

data "aws_caller_identity" "current" {}

###############################################################################
# Local Variables
###############################################################################

locals {
  account_id   = data.aws_caller_identity.current.account_id
  cluster_name = "${var.project_name}-${var.environment}-eks"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Repository  = "aws-eks-production"
    CostCenter  = var.cost_center
  }
}

###############################################################################
# IAM Module for EKS
###############################################################################

module "iam_eks" {
  source = "../../../modules/iam-eks"

  project_name = var.project_name
  environment  = var.environment
  cluster_name = local.cluster_name

  # OIDC Provider Configuration
  # Set to false initially (EKS cluster doesn't exist yet)
  # After EKS cluster is created, update this to true and provide oidc_provider_url
  create_oidc_provider = var.create_oidc_provider
  oidc_provider_url    = var.oidc_provider_url

  # Node Configuration
  enable_ssm_access = var.enable_ssm_access

  # IRSA Policy Creation
  create_ebs_csi_policy                      = var.create_ebs_csi_policy
  create_external_dns_policy                 = var.create_external_dns_policy
  create_cluster_autoscaler_policy           = var.create_cluster_autoscaler_policy
  create_aws_load_balancer_controller_policy = var.create_aws_load_balancer_controller_policy

  tags = var.tags
}
