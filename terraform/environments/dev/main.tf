###############################################################################
# Development Environment - VPC Configuration
#
# ⚠️  Deploy only via GitHub Actions
###############################################################################

terraform {
  required_version = ">= 1.6"

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
# VPC Module
###############################################################################

module "vpc" {
  source = "../../modules/vpc"

  project_name = var.project_name
  environment  = var.environment
  cluster_name = local.cluster_name

  vpc_cidr = var.vpc_cidr

  # NAT Gateway Configuration
  # Dev: Use single NAT GW for cost savings (~$32/month vs ~$96/month)
  # Prod: Use one NAT GW per AZ for high availability
  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway

  # VPC Endpoints
  # Reduce NAT Gateway costs and improve security
  enable_vpc_endpoints = var.enable_vpc_endpoints

  # Flow Logs
  enable_flow_logs    = var.enable_flow_logs
  flow_logs_retention = var.flow_logs_retention

  tags = var.tags
}
