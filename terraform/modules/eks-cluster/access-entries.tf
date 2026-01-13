###############################################################################
# EKS Access Entries
# API-based access management (replaces aws-auth ConfigMap)
#
# Benefits over aws-auth ConfigMap:
# - Centralized IAM-based access control
# - Infrastructure as Code friendly
# - CloudTrail audit logging
# - Recovery from misconfigurations via AWS API
# - No need for kubectl access to manage permissions
###############################################################################

###############################################################################
# Access Entries for IAM Principals
###############################################################################

resource "aws_eks_access_entry" "this" {
  for_each = var.access_entries

  cluster_name      = aws_eks_cluster.main.name
  principal_arn     = each.value.principal_arn
  type              = try(each.value.type, "STANDARD")
  kubernetes_groups = try(each.value.kubernetes_groups, null)
  user_name         = try(each.value.user_name, null)

  tags = merge(
    local.common_tags,
    {
      Name        = "${var.cluster_name}-access-entry-${each.key}"
      PrincipalId = each.key
    }
  )
}

###############################################################################
# Access Policy Associations
# Associates AWS-managed access policies with access entries
###############################################################################

resource "aws_eks_access_policy_association" "this" {
  for_each = {
    for item in local.access_policy_associations : "${item.entry_key}-${item.policy_name}" => item
  }

  cluster_name  = aws_eks_cluster.main.name
  principal_arn = each.value.principal_arn
  policy_arn    = each.value.policy_arn

  access_scope {
    type       = each.value.access_scope.type
    namespaces = try(each.value.access_scope.namespaces, null)
  }

  depends_on = [aws_eks_access_entry.this]
}

###############################################################################
# Locals for Policy Associations
###############################################################################

locals {
  # Flatten access entries with their policies for iteration
  access_policy_associations = flatten([
    for entry_key, entry in var.access_entries : [
      for policy in try(entry.access_policies, []) : {
        entry_key     = entry_key
        principal_arn = entry.principal_arn
        policy_name   = policy.policy_name
        policy_arn    = "arn:aws:eks::aws:cluster-access-policy/${policy.policy_name}"
        access_scope  = policy.access_scope
      }
    ]
  ])
}
