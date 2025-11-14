###############################################################################
# EKS Node Groups - IAM for IRSA
#
# Provides helper resources and data sources for creating IRSA
# (IAM Roles for Service Accounts) for Kubernetes add-ons.
#
# This file defines reusable trust policy templates that can be used
# when creating IAM roles for specific service accounts in future modules.
###############################################################################

###############################################################################
# IRSA Trust Policy Template
# This data source creates a trust policy that allows a Kubernetes service
# account to assume an IAM role via OIDC federation
###############################################################################

# Note: This is a template/helper. Actual IRSA roles for specific add-ons
# (like EBS CSI Driver, AWS Load Balancer Controller, etc.) will be created
# in separate modules or in the add-ons deployment.

# Example usage for creating an IRSA role (for reference):
#
# resource "aws_iam_role" "example_addon" {
#   name               = "${var.cluster_name}-example-addon"
#   assume_role_policy = data.aws_iam_policy_document.example_irsa_assume_role.json
# }
#
# data "aws_iam_policy_document" "example_irsa_assume_role" {
#   statement {
#     effect = "Allow"
#
#     principals {
#       type        = "Federated"
#       identifiers = [var.oidc_provider_arn]
#     }
#
#     actions = ["sts:AssumeRoleWithWebIdentity"]
#
#     condition {
#       test     = "StringEquals"
#       variable = "${var.oidc_provider_url}:aud"
#       values   = ["sts.amazonaws.com"]
#     }
#
#     condition {
#       test     = "StringEquals"
#       variable = "${var.oidc_provider_url}:sub"
#       values   = ["system:serviceaccount:kube-system:example-sa"]
#     }
#   }
# }

###############################################################################
# Helper Locals for IRSA
###############################################################################

locals {
  # Strip https:// from OIDC provider URL for use in IAM conditions
  oidc_provider_url_stripped = replace(var.oidc_provider_url, "https://", "")

  # Common IRSA condition for aud (audience)
  irsa_aud_condition = {
    test     = "StringEquals"
    variable = "${local.oidc_provider_url_stripped}:aud"
    values   = ["sts.amazonaws.com"]
  }
}

###############################################################################
# Data: Current Caller Identity
###############################################################################

# Already defined in main.tf, but included here for reference
# data "aws_caller_identity" "current" {}

###############################################################################
# Outputs for IRSA Helper
###############################################################################

# These outputs can be used by other modules to create IRSA roles
# Export the stripped OIDC URL for convenience
output "oidc_provider_url_for_irsa" {
  description = "OIDC provider URL without https:// prefix (for IAM trust policies)"
  value       = local.oidc_provider_url_stripped
}

# Note: Specific IRSA roles for add-ons (EBS CSI, ALB Controller, External DNS, etc.)
# will be created in future add-ons modules. This file provides the foundation
# and helper utilities for those roles.
