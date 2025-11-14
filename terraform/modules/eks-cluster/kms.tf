###############################################################################
# KMS Key for EKS Secrets Encryption
# Encrypts Kubernetes secrets at rest in etcd
###############################################################################

# Local variables
locals {
  common_tags = merge(
    var.tags,
    {
      Module      = "eks-cluster"
      ClusterName = var.cluster_name
      ManagedBy   = "Terraform"
    }
  )
}

# Data source for current account
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

###############################################################################
# KMS Key
###############################################################################

resource "aws_kms_key" "eks" {
  description             = "KMS key for EKS cluster ${var.cluster_name} secrets encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = data.aws_iam_policy_document.kms_key_policy.json

  tags = merge(
    local.common_tags,
    {
      Name = "${var.cluster_name}-eks-secrets"
    }
  )
}

# KMS key alias for easier identification
resource "aws_kms_alias" "eks" {
  name          = "alias/${var.cluster_name}-eks"
  target_key_id = aws_kms_key.eks.key_id
}

###############################################################################
# KMS Key Policy
###############################################################################

data "aws_iam_policy_document" "kms_key_policy" {
  # Allow root account full access
  statement {
    sid    = "Enable IAM User Permissions"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }

  # Allow EKS service to use the key
  statement {
    sid    = "Allow EKS to use the key"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }

    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:CreateGrant"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["eks.${data.aws_region.current.name}.amazonaws.com"]
    }
  }

  # Allow CloudWatch Logs to use the key (if encrypting logs)
  statement {
    sid    = "Allow CloudWatch Logs"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.name}.amazonaws.com"]
    }

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:CreateGrant",
      "kms:DescribeKey"
    ]

    resources = ["*"]

    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/eks/${var.cluster_name}/*"]
    }
  }
}

# Data source for current region
data "aws_region" "current" {}
