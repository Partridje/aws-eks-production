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
