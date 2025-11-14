###############################################################################
# Development Environment - EKS Node Groups Configuration
#
# ⚠️  Deploy only via GitHub Actions
#
# This creates managed node groups for the EKS cluster with separation:
# - System nodes: Critical cluster addons
# - App nodes: Application workloads
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
# EKS Node Groups Module
###############################################################################

module "node_groups" {
  source = "../../../modules/eks-node-groups"

  cluster_name       = local.cluster_name
  node_role_arn      = data.terraform_remote_state.iam.outputs.node_role_arn
  private_subnet_ids = data.terraform_remote_state.vpc.outputs.private_subnet_ids
  oidc_provider_arn  = data.terraform_remote_state.eks.outputs.oidc_provider_arn
  oidc_provider_url  = data.terraform_remote_state.eks.outputs.oidc_provider_url

  # System Node Group Configuration
  system_instance_types = var.system_instance_types
  system_desired_size   = var.system_desired_size
  system_min_size       = var.system_min_size
  system_max_size       = var.system_max_size
  system_node_disk_size = var.system_node_disk_size

  # Application Node Group Configuration
  app_instance_types = var.app_instance_types
  app_capacity_type  = var.app_capacity_type
  app_desired_size   = var.app_desired_size
  app_min_size       = var.app_min_size
  app_max_size       = var.app_max_size
  app_node_disk_size = var.app_node_disk_size

  tags = var.tags
}
