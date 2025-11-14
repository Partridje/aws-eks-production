# Dev Environment Main Configuration

terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket         = "partridje-terraform-state-eu-west-1"
    key            = "eks-production/dev/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "dev"
      Project     = "aws-eks-production"
      ManagedBy   = "Terraform"
      Owner       = "partridje"
    }
  }
}

locals {
  cluster_name = "eks-prod-dev"

  tags = {
    Environment = "dev"
    Project     = "aws-eks-production"
    ManagedBy   = "Terraform"
  }
}

################################################################################
# VPC Module
################################################################################

module "vpc" {
  source = "../../modules/vpc"

  cluster_name             = local.cluster_name
  vpc_cidr                 = var.vpc_cidr
  aws_region               = var.aws_region
  flow_logs_retention_days = 7

  tags = local.tags
}

################################################################################
# EKS Module
################################################################################

module "eks" {
  source = "../../modules/eks"

  cluster_name                         = local.cluster_name
  cluster_version                      = var.cluster_version
  vpc_id                               = module.vpc.vpc_id
  private_subnet_ids                   = module.vpc.private_subnet_ids
  public_subnet_ids                    = module.vpc.public_subnet_ids
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  # On-Demand Node Group
  on_demand_instance_types = ["t3.medium"]
  on_demand_desired_size   = 2
  on_demand_min_size       = 1
  on_demand_max_size       = 3

  # Spot Node Group
  spot_instance_types = ["t3.medium", "t3a.medium"]
  spot_desired_size   = 2
  spot_min_size       = 0
  spot_max_size       = 6

  tags = local.tags
}

################################################################################
# IAM Module (IRSA)
################################################################################

module "iam" {
  source = "../../modules/iam"

  cluster_name            = local.cluster_name
  cluster_oidc_issuer_url = module.eks.cluster_oidc_issuer_url
  aws_region              = var.aws_region
  route53_zone_id         = var.route53_zone_id

  tags = local.tags

  depends_on = [module.eks]
}

################################################################################
# RDS Module
################################################################################

module "rds" {
  source = "../../modules/rds"

  cluster_name               = local.cluster_name
  vpc_id                     = module.vpc.vpc_id
  db_subnet_group_name       = module.vpc.database_subnet_group_name
  eks_node_security_group_id = module.eks.node_security_group_id

  db_name     = "appdb"
  db_username = "dbadmin"

  instance_class      = "db.t3.medium"
  allocated_storage   = 20
  multi_az            = true
  deletion_protection = false # Set to true in production
  skip_final_snapshot = true  # Set to false in production

  tags = local.tags
}

################################################################################
# Observability Module
################################################################################

module "observability" {
  source = "../../modules/observability"

  cluster_name       = local.cluster_name
  aws_region         = var.aws_region
  alert_email        = var.alert_email
  log_retention_days = 7
  rds_instance_id    = "${local.cluster_name}-postgres"

  tags = local.tags

  depends_on = [module.eks, module.rds]
}

################################################################################
# RBAC Module
################################################################################

module "rbac" {
  source = "../../modules/rbac"

  cluster_name = local.cluster_name
  cluster_arn  = module.eks.cluster_arn
  tags         = local.tags

  depends_on = [module.eks]
}

################################################################################
# Outputs
################################################################################

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_id
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL"
  value       = module.eks.cluster_oidc_issuer_url
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${local.cluster_name}"
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = module.rds.db_instance_endpoint
  sensitive   = true
}

output "rds_secret_arn" {
  description = "ARN of RDS credentials secret"
  value       = module.rds.db_secret_arn
}

output "cloudwatch_dashboard_url" {
  description = "CloudWatch Dashboard URL"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${module.observability.dashboard_name}"
}

# IAM Role ARNs for Kubernetes ServiceAccounts
output "iam_role_arns" {
  description = "IAM Role ARNs for IRSA"
  value = {
    cluster_autoscaler           = module.iam.cluster_autoscaler_role_arn
    aws_load_balancer_controller = module.iam.aws_load_balancer_controller_role_arn
    external_secrets             = module.iam.external_secrets_role_arn
    cert_manager                 = module.iam.cert_manager_role_arn
    external_dns                 = module.iam.external_dns_role_arn
    fluent_bit                   = module.iam.fluent_bit_role_arn
    grafana                      = module.iam.grafana_role_arn
    xray_daemon                  = module.iam.xray_daemon_role_arn
  }
}

# RBAC IAM Role ARNs for kubectl access
output "rbac_role_arns" {
  description = "IAM Role ARNs for EKS RBAC access"
  value = {
    admin     = module.rbac.admin_role_arn
    developer = module.rbac.developer_role_arn
    viewer    = module.rbac.viewer_role_arn
  }
}

output "rbac_role_names" {
  description = "IAM Role Names for EKS RBAC access"
  value = {
    admin     = module.rbac.admin_role_name
    developer = module.rbac.developer_role_name
    viewer    = module.rbac.viewer_role_name
  }
}
