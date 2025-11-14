###############################################################################
# EKS Cluster IAM Role
# Role assumed by EKS control plane to manage AWS resources
###############################################################################

# Local variables
locals {
  common_tags = merge(
    var.tags,
    {
      Module      = "iam-eks"
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}

###############################################################################
# EKS Cluster Role
###############################################################################

# IAM role for EKS cluster
resource "aws_iam_role" "cluster" {
  name               = "${var.cluster_name}-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.cluster_assume_role.json

  tags = merge(
    local.common_tags,
    {
      Name = "${var.cluster_name}-cluster-role"
      Type = "eks-cluster"
    }
  )
}

# Trust relationship for EKS service
data "aws_iam_policy_document" "cluster_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# Attach AWS managed policy for EKS cluster
resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

# Optional: VPC Resource Controller policy (for security groups for pods)
resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.cluster.name
}
