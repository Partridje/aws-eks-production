###############################################################################
# IAM EKS Module
###############################################################################

module "iam_eks" {
  source = "../../modules/iam-eks"

  project_name = var.project_name
  environment  = var.environment
  cluster_name = local.cluster_name

  # OIDC Configuration
  # We pass true here, but the URL comes from the cluster module
  # which depends on the role created by this module.
  # Terraform handles this dependency graph.
  create_oidc_provider = true
  oidc_provider_url    = module.eks_cluster.cluster_oidc_issuer_url

  tags = var.tags
}

###############################################################################
# EKS Cluster Module
###############################################################################

module "eks_cluster" {
  source = "../../modules/eks-cluster"

  cluster_name     = local.cluster_name
  cluster_version  = "1.31" # Pinning version
  cluster_role_arn = module.iam_eks.cluster_role_arn

  # Network Configuration
  private_subnet_ids = module.vpc.private_subnet_ids
  # We don't expose vpc.default_security_group_id, let the module create its own SG

  # Logging
  # Enable all logs for dev as well to debug issues, or restrict if cost is a concern
  enabled_log_types  = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  log_retention_days = 7

  # Access Entries
  authentication_mode = "API_AND_CONFIG_MAP"



  tags = var.tags
}
