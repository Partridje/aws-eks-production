###############################################################################
# Development Environment - EKS Cluster Configuration
#
# ⚠️  Deploy only via GitHub Actions
#
# This creates the EKS control plane with OIDC provider for IRSA
###############################################################################

terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
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
# EKS Cluster Module
###############################################################################

module "eks_cluster" {
  source = "../../../modules/eks-cluster"

  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version

  # IAM Role from remote state
  cluster_role_arn = data.terraform_remote_state.iam.outputs.cluster_role_arn

  # Network configuration from VPC remote state
  private_subnet_ids = data.terraform_remote_state.vpc.outputs.private_subnet_ids

  # API endpoint configuration
  endpoint_private_access = var.endpoint_private_access
  endpoint_public_access  = var.endpoint_public_access
  public_access_cidrs     = var.public_access_cidrs

  # Security
  create_cluster_security_group = var.create_cluster_security_group
  additional_security_group_ids = var.additional_security_group_ids

  # Logging
  enabled_log_types  = var.enabled_log_types
  log_retention_days = var.log_retention_days
  encrypt_logs       = var.encrypt_logs

  tags = var.tags
}
