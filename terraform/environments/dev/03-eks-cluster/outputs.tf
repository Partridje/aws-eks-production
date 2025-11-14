###############################################################################
# Development Environment - EKS Cluster Outputs
###############################################################################

###############################################################################
# Cluster Information
###############################################################################

output "cluster_id" {
  description = "The name/id of the EKS cluster"
  value       = module.eks_cluster.cluster_id
}

output "cluster_arn" {
  description = "The ARN of the EKS cluster"
  value       = module.eks_cluster.cluster_arn
}

output "cluster_endpoint" {
  description = "Endpoint for Kubernetes API server"
  value       = module.eks_cluster.cluster_endpoint
}

output "cluster_version" {
  description = "The Kubernetes version"
  value       = module.eks_cluster.cluster_version
}

output "cluster_platform_version" {
  description = "The platform version"
  value       = module.eks_cluster.cluster_platform_version
}

output "cluster_status" {
  description = "Status of the EKS cluster"
  value       = module.eks_cluster.cluster_status
}

###############################################################################
# Security
###############################################################################

output "cluster_security_group_id" {
  description = "Security group ID attached to the cluster"
  value       = module.eks_cluster.cluster_security_group_id
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data"
  value       = module.eks_cluster.cluster_certificate_authority_data
  sensitive   = true
}

###############################################################################
# OIDC Provider (for IRSA)
###############################################################################

output "cluster_oidc_issuer_url" {
  description = "The URL of the OpenID Connect identity provider"
  value       = module.eks_cluster.cluster_oidc_issuer_url
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider for IRSA"
  value       = module.eks_cluster.oidc_provider_arn
}

output "oidc_provider_url" {
  description = "OIDC provider URL without https:// (for IAM trust policies)"
  value       = module.eks_cluster.cluster_oidc_provider_url
}

###############################################################################
# KMS
###############################################################################

output "kms_key_id" {
  description = "The KMS key ID for secrets encryption"
  value       = module.eks_cluster.kms_key_id
}

output "kms_key_arn" {
  description = "The KMS key ARN for secrets encryption"
  value       = module.eks_cluster.kms_key_arn
}

###############################################################################
# Kubectl Configuration
###############################################################################

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks_cluster.cluster_id}"
}

###############################################################################
# Summary
###############################################################################

output "cluster_summary" {
  description = "Summary of EKS cluster configuration"
  value = {
    name              = module.eks_cluster.cluster_id
    version           = module.eks_cluster.cluster_version
    endpoint          = module.eks_cluster.cluster_endpoint
    status            = module.eks_cluster.cluster_status
    oidc_issuer       = module.eks_cluster.cluster_oidc_issuer_url
    oidc_provider_arn = module.eks_cluster.oidc_provider_arn
    private_access    = var.endpoint_private_access
    public_access     = var.endpoint_public_access
    irsa_ready        = true
  }
}
