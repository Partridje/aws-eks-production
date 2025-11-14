# EKS RBAC Configuration
# Creates IAM roles and maps them to Kubernetes RBAC roles

################################################################################
# IAM Roles for EKS Access
################################################################################

# Admin Role - Full cluster access
resource "aws_iam_role" "eks_admin" {
  name = "${var.cluster_name}-admin-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "${var.cluster_name}-admin"
          }
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-admin-role"
      Role = "EKS Admin"
    }
  )
}

# Developer Role - Namespace-scoped access
resource "aws_iam_role" "eks_developer" {
  name = "${var.cluster_name}-developer-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "${var.cluster_name}-developer"
          }
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-developer-role"
      Role = "EKS Developer"
    }
  )
}

# Viewer Role - Read-only access
resource "aws_iam_role" "eks_viewer" {
  name = "${var.cluster_name}-viewer-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "${var.cluster_name}-viewer"
          }
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-viewer-role"
      Role = "EKS Viewer"
    }
  )
}

################################################################################
# IAM Policies for EKS Access
################################################################################

# Policy to describe EKS cluster
resource "aws_iam_policy" "eks_access" {
  name        = "${var.cluster_name}-access-policy"
  description = "Policy to allow EKS cluster access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Resource = var.cluster_arn
      }
    ]
  })

  tags = var.tags
}

# Attach policy to all roles
resource "aws_iam_role_policy_attachment" "eks_admin_access" {
  role       = aws_iam_role.eks_admin.name
  policy_arn = aws_iam_policy.eks_access.arn
}

resource "aws_iam_role_policy_attachment" "eks_developer_access" {
  role       = aws_iam_role.eks_developer.name
  policy_arn = aws_iam_policy.eks_access.arn
}

resource "aws_iam_role_policy_attachment" "eks_viewer_access" {
  role       = aws_iam_role.eks_viewer.name
  policy_arn = aws_iam_policy.eks_access.arn
}

################################################################################
# AWS Auth ConfigMap
################################################################################

# Note: This is managed via kubectl, not Terraform
# See kubernetes/infrastructure/aws-auth-configmap.yaml

################################################################################
# Data Sources
################################################################################

data "aws_caller_identity" "current" {}
