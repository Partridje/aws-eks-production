###############################################################################
# EKS Node Groups - Main Configuration
#
# Creates managed node groups for EKS with separation of concerns:
# - System Node Group: Runs critical cluster addons (CoreDNS, kube-proxy, etc.)
# - App Node Group: Runs application workloads
###############################################################################

terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

###############################################################################
# Data Sources
###############################################################################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

###############################################################################
# Local Variables
###############################################################################

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
  partition  = data.aws_partition.current.partition

  common_tags = merge(
    var.tags,
    {
      ManagedBy   = "Terraform"
      Module      = "eks-node-groups"
      ClusterName = var.cluster_name
    }
  )
}

###############################################################################
# System Node Group
# Purpose: Run critical cluster addons and system components
# Characteristics:
#   - On-Demand instances for reliability
#   - Tainted to prevent application pods
#   - Smaller scale (2-4 nodes typically)
###############################################################################

resource "aws_eks_node_group" "system" {
  cluster_name    = var.cluster_name
  node_group_name = "${var.cluster_name}-system"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.private_subnet_ids

  # Scaling Configuration
  scaling_config {
    desired_size = var.system_desired_size
    min_size     = var.system_min_size
    max_size     = var.system_max_size
  }

  # Update Configuration
  update_config {
    max_unavailable_percentage = 33 # Allow 1/3 nodes to be unavailable during updates
  }

  # Launch Template
  launch_template {
    id      = aws_launch_template.system.id
    version = "$Latest"
  }

  # Instance Configuration
  instance_types = var.system_instance_types
  capacity_type  = "ON_DEMAND" # Always use On-Demand for system nodes

  # Kubernetes Labels
  labels = {
    role         = "system"
    type         = "system"
    workload     = "critical-addons"
    "node-group" = "system"
  }

  # Taints: Prevent application pods from running on system nodes
  # Only pods with matching tolerations can be scheduled here
  taint {
    key    = "CriticalAddonsOnly"
    value  = "true"
    effect = "NO_SCHEDULE"
  }

  # Tags
  tags = merge(
    local.common_tags,
    {
      Name = "${var.cluster_name}-system-node-group"
      Type = "system"
    }
  )

  # Lifecycle
  lifecycle {
    create_before_destroy = true
    # Ignore desired_size changes made by Cluster Autoscaler
    ignore_changes = [scaling_config[0].desired_size]
  }

  # Ensure node role is ready before creating node group
  depends_on = []
}

###############################################################################
# Application Node Group
# Purpose: Run user application workloads
# Characteristics:
#   - Can use Spot instances for cost savings
#   - No taints - accepts all pods
#   - Larger scale (2-10+ nodes)
###############################################################################

resource "aws_eks_node_group" "app" {
  cluster_name    = var.cluster_name
  node_group_name = "${var.cluster_name}-app"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.private_subnet_ids

  # Scaling Configuration
  scaling_config {
    desired_size = var.app_desired_size
    min_size     = var.app_min_size
    max_size     = var.app_max_size
  }

  # Update Configuration
  update_config {
    max_unavailable_percentage = 33 # Allow 1/3 nodes to be unavailable during updates
  }

  # Launch Template
  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  # Instance Configuration
  instance_types = var.app_instance_types
  capacity_type  = var.app_capacity_type # ON_DEMAND or SPOT

  # Kubernetes Labels
  labels = {
    role         = "application"
    type         = "app"
    workload     = "user-workloads"
    "node-group" = "app"
  }

  # No taints - application nodes accept all pods

  # Tags
  tags = merge(
    local.common_tags,
    {
      Name = "${var.cluster_name}-app-node-group"
      Type = "application"
    }
  )

  # Lifecycle
  lifecycle {
    create_before_destroy = true
    # Ignore desired_size changes made by Cluster Autoscaler
    ignore_changes = [scaling_config[0].desired_size]
  }

  # Ensure node role is ready before creating node group
  depends_on = []
}
