###############################################################################
# Development Environment - IAM Outputs
###############################################################################

###############################################################################
# EKS Cluster Role Outputs
###############################################################################

output "cluster_role_arn" {
  description = "ARN of the EKS cluster IAM role"
  value       = module.iam_eks.cluster_role_arn
}

output "cluster_role_name" {
  description = "Name of the EKS cluster IAM role"
  value       = module.iam_eks.cluster_role_name
}

###############################################################################
# EKS Node Role Outputs
###############################################################################

output "node_role_arn" {
  description = "ARN of the EKS node IAM role"
  value       = module.iam_eks.node_role_arn
}

output "node_role_name" {
  description = "Name of the EKS node IAM role"
  value       = module.iam_eks.node_role_name
}

output "node_instance_profile_name" {
  description = "Name of the EKS node instance profile"
  value       = module.iam_eks.node_instance_profile_name
}

###############################################################################
# OIDC Provider Outputs
###############################################################################

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider for IRSA"
  value       = module.iam_eks.oidc_provider_arn
}

output "oidc_provider_url" {
  description = "OIDC provider URL (without https://)"
  value       = module.iam_eks.oidc_provider_url
}

###############################################################################
# IRSA Policy Outputs
###############################################################################

output "ebs_csi_policy_arn" {
  description = "ARN of the EBS CSI Driver IAM policy"
  value       = module.iam_eks.ebs_csi_policy_arn
}

output "external_dns_policy_arn" {
  description = "ARN of the External DNS IAM policy"
  value       = module.iam_eks.external_dns_policy_arn
}

output "cluster_autoscaler_policy_arn" {
  description = "ARN of the Cluster Autoscaler IAM policy"
  value       = module.iam_eks.cluster_autoscaler_policy_arn
}

output "aws_load_balancer_controller_policy_arn" {
  description = "ARN of the AWS Load Balancer Controller IAM policy"
  value       = module.iam_eks.aws_load_balancer_controller_policy_arn
}

###############################################################################
# Summary Output
###############################################################################

output "iam_summary" {
  description = "Summary of IAM resources for EKS"
  value = {
    cluster_name          = "${var.project_name}-${var.environment}-eks"
    cluster_role          = module.iam_eks.cluster_role_arn
    node_role             = module.iam_eks.node_role_arn
    node_instance_profile = module.iam_eks.node_instance_profile_name
    oidc_configured       = var.create_oidc_provider
    ssm_enabled           = var.enable_ssm_access
    irsa_policies_created = {
      ebs_csi                      = var.create_ebs_csi_policy
      external_dns                 = var.create_external_dns_policy
      cluster_autoscaler           = var.create_cluster_autoscaler_policy
      aws_load_balancer_controller = var.create_aws_load_balancer_controller_policy
    }
  }
}
