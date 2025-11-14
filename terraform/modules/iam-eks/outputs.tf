###############################################################################
# IAM Module Outputs
###############################################################################

###############################################################################
# EKS Cluster Role Outputs
###############################################################################

output "cluster_role_arn" {
  description = "ARN of the EKS cluster IAM role"
  value       = aws_iam_role.cluster.arn
}

output "cluster_role_name" {
  description = "Name of the EKS cluster IAM role"
  value       = aws_iam_role.cluster.name
}

output "cluster_role_id" {
  description = "ID of the EKS cluster IAM role"
  value       = aws_iam_role.cluster.id
}

###############################################################################
# EKS Node Role Outputs
###############################################################################

output "node_role_arn" {
  description = "ARN of the EKS node IAM role"
  value       = aws_iam_role.node.arn
}

output "node_role_name" {
  description = "Name of the EKS node IAM role"
  value       = aws_iam_role.node.name
}

output "node_role_id" {
  description = "ID of the EKS node IAM role"
  value       = aws_iam_role.node.id
}

output "node_instance_profile_name" {
  description = "Name of the EKS node instance profile"
  value       = aws_iam_instance_profile.node.name
}

output "node_instance_profile_arn" {
  description = "ARN of the EKS node instance profile"
  value       = aws_iam_instance_profile.node.arn
}

###############################################################################
# OIDC Provider Outputs
###############################################################################

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider for IRSA"
  value       = local.oidc_provider_arn
}

output "oidc_provider_url" {
  description = "URL of the OIDC provider (without https://)"
  value       = local.oidc_provider_url
}

output "oidc_provider_issuer" {
  description = "Full OIDC provider URL with https://"
  value       = var.oidc_provider_url
}

###############################################################################
# IRSA Policy Outputs
###############################################################################

output "ebs_csi_policy_arn" {
  description = "ARN of the EBS CSI Driver IAM policy"
  value       = var.create_ebs_csi_policy ? aws_iam_policy.ebs_csi_driver[0].arn : null
}

output "ebs_csi_policy_name" {
  description = "Name of the EBS CSI Driver IAM policy"
  value       = var.create_ebs_csi_policy ? aws_iam_policy.ebs_csi_driver[0].name : null
}

output "external_dns_policy_arn" {
  description = "ARN of the External DNS IAM policy"
  value       = var.create_external_dns_policy ? aws_iam_policy.external_dns[0].arn : null
}

output "external_dns_policy_name" {
  description = "Name of the External DNS IAM policy"
  value       = var.create_external_dns_policy ? aws_iam_policy.external_dns[0].name : null
}

output "cluster_autoscaler_policy_arn" {
  description = "ARN of the Cluster Autoscaler IAM policy"
  value       = var.create_cluster_autoscaler_policy ? aws_iam_policy.cluster_autoscaler[0].arn : null
}

output "cluster_autoscaler_policy_name" {
  description = "Name of the Cluster Autoscaler IAM policy"
  value       = var.create_cluster_autoscaler_policy ? aws_iam_policy.cluster_autoscaler[0].name : null
}

output "aws_load_balancer_controller_policy_arn" {
  description = "ARN of the AWS Load Balancer Controller IAM policy"
  value       = var.create_aws_load_balancer_controller_policy ? aws_iam_policy.aws_load_balancer_controller[0].arn : null
}

output "aws_load_balancer_controller_policy_name" {
  description = "Name of the AWS Load Balancer Controller IAM policy"
  value       = var.create_aws_load_balancer_controller_policy ? aws_iam_policy.aws_load_balancer_controller[0].name : null
}

###############################################################################
# Summary Output
###############################################################################

output "iam_roles_summary" {
  description = "Summary of created IAM roles"
  value = {
    cluster_role             = aws_iam_role.cluster.arn
    node_role                = aws_iam_role.node.arn
    node_instance_profile    = aws_iam_instance_profile.node.name
    oidc_provider_configured = var.create_oidc_provider && var.oidc_provider_url != ""
    ssm_access_enabled       = var.enable_ssm_access
  }
}
