###############################################################################
# OIDC Provider for IRSA (IAM Roles for Service Accounts)
# Enables Kubernetes service accounts to assume IAM roles
###############################################################################

# Fetch TLS certificate from OIDC provider URL
data "tls_certificate" "cluster" {
  count = var.create_oidc_provider && var.oidc_provider_url != "" ? 1 : 0

  url = var.oidc_provider_url
}

# Create OIDC provider for EKS cluster
resource "aws_iam_openid_connect_provider" "cluster" {
  count = var.create_oidc_provider && var.oidc_provider_url != "" ? 1 : 0

  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster[0].certificates[0].sha1_fingerprint]
  url             = var.oidc_provider_url

  tags = merge(
    local.common_tags,
    {
      Name        = "${var.cluster_name}-oidc-provider"
      ClusterName = var.cluster_name
    }
  )
}

###############################################################################
# Data source for existing OIDC provider
###############################################################################

# Use this when OIDC provider already exists
data "aws_iam_openid_connect_provider" "cluster" {
  count = var.create_oidc_provider ? 0 : 1

  arn = var.oidc_provider_arn
}

###############################################################################
# Locals for OIDC provider ARN and URL
###############################################################################

locals {
  # Get OIDC provider ARN (either created or existing)
  oidc_provider_arn = var.create_oidc_provider && var.oidc_provider_url != "" ? aws_iam_openid_connect_provider.cluster[0].arn : var.oidc_provider_arn

  # Extract OIDC provider URL without https://
  oidc_provider_url = var.oidc_provider_url != "" ? replace(var.oidc_provider_url, "https://", "") : ""
}

###############################################################################
# VPC CNI IRSA Role
# Recommended: Use IRSA for VPC CNI instead of node role for better security
###############################################################################

resource "aws_iam_role" "vpc_cni" {
  count = var.use_vpc_cni_irsa && local.oidc_provider_url != "" ? 1 : 0

  name        = "${var.cluster_name}-vpc-cni-irsa-role"
  description = "IRSA role for VPC CNI add-on"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = local.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_provider_url}:aud" = "sts.amazonaws.com"
            "${local.oidc_provider_url}:sub" = "system:serviceaccount:kube-system:aws-node"
          }
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${var.cluster_name}-vpc-cni-irsa-role"
      Type = "irsa"
    }
  )
}

resource "aws_iam_role_policy_attachment" "vpc_cni" {
  count = var.use_vpc_cni_irsa && local.oidc_provider_url != "" ? 1 : 0

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.vpc_cni[0].name
}

###############################################################################
# EBS CSI Driver IRSA Role
###############################################################################

resource "aws_iam_role" "ebs_csi_driver" {
  count = var.create_ebs_csi_policy && local.oidc_provider_url != "" ? 1 : 0

  name        = "${var.cluster_name}-ebs-csi-driver-irsa-role"
  description = "IRSA role for EBS CSI Driver add-on"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = local.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_provider_url}:aud" = "sts.amazonaws.com"
            "${local.oidc_provider_url}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          }
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${var.cluster_name}-ebs-csi-driver-irsa-role"
      Type = "irsa"
    }
  )
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver_managed" {
  count = var.create_ebs_csi_policy && local.oidc_provider_url != "" ? 1 : 0

  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_driver[0].name
}
