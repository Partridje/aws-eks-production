###############################################################################
# EKS Cluster Module Outputs
###############################################################################

###############################################################################
# Cluster Information
###############################################################################

output "cluster_id" {
  description = "The name/id of the EKS cluster"
  value       = aws_eks_cluster.main.id
}

output "cluster_arn" {
  description = "The Amazon Resource Name (ARN) of the cluster"
  value       = aws_eks_cluster.main.arn
}

output "cluster_endpoint" {
  description = "Endpoint for your Kubernetes API server"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_version" {
  description = "The Kubernetes server version for the cluster"
  value       = aws_eks_cluster.main.version
}

output "cluster_platform_version" {
  description = "The platform version for the cluster"
  value       = aws_eks_cluster.main.platform_version
}

###############################################################################
# Security
###############################################################################

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

###############################################################################
# OIDC Provider
###############################################################################

output "cluster_oidc_issuer_url" {
  description = "The URL of the OpenID Connect identity provider"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

output "cluster_oidc_provider_url" {
  description = "OIDC provider URL without https:// (for IRSA configuration)"
  value       = local.oidc_provider_url_stripped
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider for IRSA"
  value       = aws_iam_openid_connect_provider.cluster.arn
}

###############################################################################
# KMS
###############################################################################

output "kms_key_id" {
  description = "The globally unique identifier for the KMS key"
  value       = aws_kms_key.eks.id
}

output "kms_key_arn" {
  description = "The Amazon Resource Name (ARN) of the KMS key"
  value       = aws_kms_key.eks.arn
}

output "kms_key_alias" {
  description = "The alias of the KMS key"
  value       = aws_kms_alias.eks.name
}

###############################################################################
# Logging
###############################################################################

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch Log Group for EKS cluster logs"
  value       = aws_cloudwatch_log_group.eks.name
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch Log Group for EKS cluster logs"
  value       = aws_cloudwatch_log_group.eks.arn
}

###############################################################################
# Status
###############################################################################

output "cluster_status" {
  description = "Status of the EKS cluster (CREATING, ACTIVE, DELETING, FAILED)"
  value       = aws_eks_cluster.main.status
}

###############################################################################
# Summary
###############################################################################

output "cluster_summary" {
  description = "Summary of EKS cluster configuration"
  value = {
    name               = aws_eks_cluster.main.id
    version            = aws_eks_cluster.main.version
    endpoint           = aws_eks_cluster.main.endpoint
    status             = aws_eks_cluster.main.status
    oidc_issuer        = aws_eks_cluster.main.identity[0].oidc[0].issuer
    private_access     = aws_eks_cluster.main.vpc_config[0].endpoint_private_access
    public_access      = aws_eks_cluster.main.vpc_config[0].endpoint_public_access
    encryption_enabled = true
    logging_enabled    = length(var.enabled_log_types) > 0
    kms_key            = aws_kms_key.eks.arn
  }
}
