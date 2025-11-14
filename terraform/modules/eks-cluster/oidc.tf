###############################################################################
# OIDC Provider for IRSA (IAM Roles for Service Accounts)
# Automatically created with the EKS cluster
###############################################################################

# Fetch TLS certificate from the EKS cluster OIDC endpoint
data "tls_certificate" "cluster" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# Create OIDC provider for the EKS cluster
resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = merge(
    local.common_tags,
    {
      Name        = "${var.cluster_name}-eks-oidc"
      ClusterName = var.cluster_name
      Purpose     = "IRSA"
    }
  )
}

###############################################################################
# Local Variables for OIDC
###############################################################################

locals {
  # OIDC provider ARN
  oidc_provider_arn = aws_iam_openid_connect_provider.cluster.arn

  # OIDC provider URL without https:// (for use in IAM trust policies)
  oidc_provider_url_stripped = replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")
}
