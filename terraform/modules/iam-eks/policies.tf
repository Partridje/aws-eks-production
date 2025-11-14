###############################################################################
# IRSA Helper Policies
# Reusable IAM policies for common Kubernetes add-ons
###############################################################################

###############################################################################
# Helper: IRSA Trust Policy Document
# Use this data source to create trust relationships for IRSA roles
###############################################################################

# This is a template - actual IRSA roles will be created in specific modules
# Example usage shown in README.md

###############################################################################
# EBS CSI Driver Policy
###############################################################################

# IAM policy for EBS CSI Driver
resource "aws_iam_policy" "ebs_csi_driver" {
  count = var.create_ebs_csi_policy ? 1 : 0

  name        = "${var.cluster_name}-ebs-csi-driver-policy"
  description = "Policy for EBS CSI Driver to manage EBS volumes"
  policy      = data.aws_iam_policy_document.ebs_csi_driver.json

  tags = merge(
    local.common_tags,
    {
      Name = "${var.cluster_name}-ebs-csi-driver-policy"
      Type = "irsa-policy"
    }
  )
}

data "aws_iam_policy_document" "ebs_csi_driver" {
  statement {
    sid    = "EBSCSICreateVolume"
    effect = "Allow"

    actions = [
      "ec2:CreateVolume",
      "ec2:AttachVolume",
      "ec2:DetachVolume",
      "ec2:DeleteVolume",
      "ec2:CreateSnapshot",
      "ec2:DeleteSnapshot",
      "ec2:DescribeVolumes",
      "ec2:DescribeSnapshots",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInstances",
      "ec2:DescribeVolumeAttribute",
      "ec2:DescribeVolumeStatus",
      "ec2:DescribeSnapshotAttribute",
      "ec2:DescribeTags",
      "ec2:ModifyVolume"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "EBSCSICreateTags"
    effect = "Allow"

    actions = [
      "ec2:CreateTags"
    ]

    resources = [
      "arn:aws:ec2:*:*:volume/*",
      "arn:aws:ec2:*:*:snapshot/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "ec2:CreateAction"
      values = [
        "CreateVolume",
        "CreateSnapshot"
      ]
    }
  }

  statement {
    sid    = "EBSCSIDeleteTags"
    effect = "Allow"

    actions = [
      "ec2:DeleteTags"
    ]

    resources = [
      "arn:aws:ec2:*:*:volume/*",
      "arn:aws:ec2:*:*:snapshot/*"
    ]
  }
}

###############################################################################
# External DNS Policy
###############################################################################

# IAM policy for External DNS
resource "aws_iam_policy" "external_dns" {
  count = var.create_external_dns_policy ? 1 : 0

  name        = "${var.cluster_name}-external-dns-policy"
  description = "Policy for External DNS to manage Route53 records"
  policy      = data.aws_iam_policy_document.external_dns.json

  tags = merge(
    local.common_tags,
    {
      Name = "${var.cluster_name}-external-dns-policy"
      Type = "irsa-policy"
    }
  )
}

data "aws_iam_policy_document" "external_dns" {
  statement {
    sid    = "ExternalDNSRoute53"
    effect = "Allow"

    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:ListResourceRecordSets"
    ]

    resources = ["arn:aws:route53:::hostedzone/*"]
  }

  statement {
    sid    = "ExternalDNSListHostedZones"
    effect = "Allow"

    actions = [
      "route53:ListHostedZones",
      "route53:ListHostedZonesByName"
    ]

    resources = ["*"]
  }
}

###############################################################################
# Cluster Autoscaler Policy
###############################################################################

# IAM policy for Cluster Autoscaler
resource "aws_iam_policy" "cluster_autoscaler" {
  count = var.create_cluster_autoscaler_policy ? 1 : 0

  name        = "${var.cluster_name}-cluster-autoscaler-policy"
  description = "Policy for Cluster Autoscaler to manage ASG scaling"
  policy      = data.aws_iam_policy_document.cluster_autoscaler.json

  tags = merge(
    local.common_tags,
    {
      Name = "${var.cluster_name}-cluster-autoscaler-policy"
      Type = "irsa-policy"
    }
  )
}

data "aws_iam_policy_document" "cluster_autoscaler" {
  statement {
    sid    = "ClusterAutoscalerAll"
    effect = "Allow"

    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeScalingActivities",
      "autoscaling:DescribeTags",
      "ec2:DescribeImages",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeLaunchTemplateVersions",
      "ec2:GetInstanceTypesFromInstanceRequirements",
      "eks:DescribeNodegroup"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "ClusterAutoscalerOwn"
    effect = "Allow"

    actions = [
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "autoscaling:ResourceTag/k8s.io/cluster-autoscaler/${var.cluster_name}"
      values   = ["owned"]
    }
  }
}

###############################################################################
# AWS Load Balancer Controller Policy (Skeleton)
###############################################################################

# Note: This is a simplified skeleton
# Full AWS Load Balancer Controller policy is complex (2000+ lines)
# Will be implemented in later steps when deploying the controller

resource "aws_iam_policy" "aws_load_balancer_controller" {
  count = var.create_aws_load_balancer_controller_policy ? 1 : 0

  name        = "${var.cluster_name}-aws-load-balancer-controller-policy"
  description = "Policy for AWS Load Balancer Controller (skeleton - to be expanded)"
  policy      = data.aws_iam_policy_document.aws_load_balancer_controller.json

  tags = merge(
    local.common_tags,
    {
      Name = "${var.cluster_name}-aws-load-balancer-controller-policy"
      Type = "irsa-policy"
    }
  )
}

data "aws_iam_policy_document" "aws_load_balancer_controller" {
  # Skeleton - basic ELB/ALB permissions
  # Full policy: https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

  statement {
    sid    = "LoadBalancerControllerBasic"
    effect = "Allow"

    actions = [
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:DescribeTags",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeVpcs"
    ]

    resources = ["*"]
  }

  # Note: Full policy will be added when deploying AWS LBC
}
