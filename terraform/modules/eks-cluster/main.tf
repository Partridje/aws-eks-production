###############################################################################
# EKS Cluster Control Plane
# Creates managed Kubernetes control plane
###############################################################################

###############################################################################
# CloudWatch Log Group for EKS Logs
###############################################################################

resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.log_retention_days

  # Optional: encrypt logs with KMS
  kms_key_id = var.encrypt_logs ? aws_kms_key.eks.arn : null

  tags = merge(
    local.common_tags,
    {
      Name = "${var.cluster_name}-eks-logs"
    }
  )
}

###############################################################################
# EKS Cluster
###############################################################################

resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = var.cluster_role_arn

  # VPC Configuration
  vpc_config {
    subnet_ids = var.private_subnet_ids

    # Endpoint access configuration
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.public_access_cidrs

    # Additional security groups
    security_group_ids = concat(
      var.create_cluster_security_group ? [aws_security_group.cluster[0].id] : [],
      var.additional_security_group_ids
    )
  }

  # Secrets Encryption
  encryption_config {
    provider {
      key_arn = aws_kms_key.eks.arn
    }
    resources = ["secrets"]
  }

  # Control Plane Logging
  enabled_cluster_log_types = var.enabled_log_types

  # Ensure CloudWatch log group is created first
  depends_on = [
    aws_cloudwatch_log_group.eks
  ]

  tags = merge(
    local.common_tags,
    {
      Name = var.cluster_name
    }
  )
}
