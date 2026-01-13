###############################################################################
# EKS Add-ons Module
#
# Manages EKS managed add-ons for consistent versioning and lifecycle management
# Add-ons: VPC CNI, CoreDNS, kube-proxy, EBS CSI Driver, Pod Identity Agent
###############################################################################

terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

###############################################################################
# Data Sources
###############################################################################



###############################################################################
# Local Variables
###############################################################################

locals {
  common_tags = merge(
    var.tags,
    {
      Module      = "eks-addons"
      ClusterName = var.cluster_name
      ManagedBy   = "Terraform"
    }
  )
}

###############################################################################
# VPC CNI Add-on
# Provides pod networking using AWS VPC native networking
###############################################################################

resource "aws_eks_addon" "vpc_cni" {
  cluster_name = var.cluster_name
  addon_name   = "vpc-cni"

  # Version management
  addon_version = var.addon_versions.vpc_cni

  # Use IRSA for VPC CNI (recommended over node role)
  service_account_role_arn = var.vpc_cni_role_arn

  # How to handle conflicts during updates
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  # Preserve settings not managed by Terraform
  preserve = true

  # Configuration for VPC CNI
  configuration_values = jsonencode({
    enableNetworkPolicy = tostring(var.enable_network_policy)
    env = {
      # Enable prefix delegation for more IPs per node
      ENABLE_PREFIX_DELEGATION = tostring(var.enable_prefix_delegation)
      # Warm IP target for faster pod startup
      WARM_IP_TARGET = tostring(var.warm_ip_target)
      # Minimum IPs to keep warm
      MINIMUM_IP_TARGET = tostring(var.minimum_ip_target)
    }
  })

  tags = local.common_tags

  # Ensure cluster is ready before adding add-ons
  depends_on = [var.cluster_dependencies]
}

###############################################################################
# CoreDNS Add-on
# Provides DNS resolution for pods in the cluster
###############################################################################

resource "aws_eks_addon" "coredns" {
  cluster_name = var.cluster_name
  addon_name   = "coredns"

  addon_version = var.addon_versions.coredns

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  preserve = true

  # CoreDNS configuration
  configuration_values = jsonencode({
    replicaCount = var.coredns_replicas
    resources = {
      limits = {
        cpu    = var.coredns_resources.limits.cpu
        memory = var.coredns_resources.limits.memory
      }
      requests = {
        cpu    = var.coredns_resources.requests.cpu
        memory = var.coredns_resources.requests.memory
      }
    }
    # Tolerate system node taint
    tolerations = [
      {
        key      = "CriticalAddonsOnly"
        operator = "Exists"
      }
    ]
  })

  tags = local.common_tags

  # CoreDNS needs VPC CNI to be ready
  depends_on = [aws_eks_addon.vpc_cni]
}

###############################################################################
# kube-proxy Add-on
# Provides network proxy running on each node
###############################################################################

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = var.cluster_name
  addon_name   = "kube-proxy"

  addon_version = var.addon_versions.kube_proxy

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  preserve = true

  tags = local.common_tags

  depends_on = [var.cluster_dependencies]
}

###############################################################################
# EBS CSI Driver Add-on
# Provides persistent block storage for pods
###############################################################################

resource "aws_eks_addon" "ebs_csi_driver" {
  count = var.enable_ebs_csi_driver ? 1 : 0

  cluster_name = var.cluster_name
  addon_name   = "aws-ebs-csi-driver"

  addon_version = var.addon_versions.ebs_csi

  # Use IRSA for EBS CSI Driver
  service_account_role_arn = var.ebs_csi_role_arn

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  preserve = true

  # EBS CSI configuration
  configuration_values = jsonencode({
    controller = {
      # Tolerate system node taint
      tolerations = [
        {
          key      = "CriticalAddonsOnly"
          operator = "Exists"
        }
      ]
    }
  })

  tags = local.common_tags

  depends_on = [aws_eks_addon.vpc_cni]
}

###############################################################################
# EKS Pod Identity Agent Add-on
# Required for Pod Identity associations (simpler alternative to IRSA)
###############################################################################

resource "aws_eks_addon" "pod_identity_agent" {
  count = var.enable_pod_identity_agent ? 1 : 0

  cluster_name = var.cluster_name
  addon_name   = "eks-pod-identity-agent"

  addon_version = var.addon_versions.pod_identity_agent

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  preserve = true

  tags = local.common_tags

  depends_on = [var.cluster_dependencies]
}
