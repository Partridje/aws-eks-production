###############################################################################
# EKS Node Groups Module
###############################################################################

module "eks_node_groups" {
  source = "../../modules/eks-node-groups"

  cluster_name       = local.cluster_name
  node_role_arn      = module.iam_eks.node_role_arn
  private_subnet_ids = module.vpc.private_subnet_ids

  oidc_provider_url = module.iam_eks.oidc_provider_url

  # System Node Group
  system_instance_types = ["t3.medium"]
  system_desired_size   = 2
  system_min_size       = 2
  system_max_size       = 3

  # Use AL2 for compatibility as per module default, or switch to AL2023 if preferred
  system_ami_type = "AL2_x86_64"

  # Application Node Group
  # Using Spot instances for cost savings in Dev
  app_instance_types = ["t3.large"]
  app_capacity_type  = "SPOT"
  app_desired_size   = 2
  app_min_size       = 2
  app_max_size       = 5

  app_ami_type = "AL2_x86_64"

  tags = var.tags
}
