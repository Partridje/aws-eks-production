###############################################################################
# EKS Node Groups - Outputs
###############################################################################

###############################################################################
# System Node Group Outputs
###############################################################################

output "system_node_group_id" {
  description = "ID of the system node group"
  value       = aws_eks_node_group.system.id
}

output "system_node_group_arn" {
  description = "ARN of the system node group"
  value       = aws_eks_node_group.system.arn
}

output "system_node_group_status" {
  description = "Status of the system node group"
  value       = aws_eks_node_group.system.status
}

output "system_node_group_resources" {
  description = "Resources associated with the system node group (ASG, etc.)"
  value       = aws_eks_node_group.system.resources
}

output "system_asg_name" {
  description = "Name of the Auto Scaling Group for system nodes"
  value       = try(aws_eks_node_group.system.resources[0].autoscaling_groups[0].name, "")
}

output "system_node_group_launch_template_id" {
  description = "ID of the launch template used by system node group"
  value       = aws_launch_template.system.id
}

output "system_node_group_launch_template_latest_version" {
  description = "Latest version of the system node group launch template"
  value       = aws_launch_template.system.latest_version
}

###############################################################################
# Application Node Group Outputs
###############################################################################

output "app_node_group_id" {
  description = "ID of the application node group"
  value       = aws_eks_node_group.app.id
}

output "app_node_group_arn" {
  description = "ARN of the application node group"
  value       = aws_eks_node_group.app.arn
}

output "app_node_group_status" {
  description = "Status of the application node group"
  value       = aws_eks_node_group.app.status
}

output "app_node_group_resources" {
  description = "Resources associated with the application node group (ASG, etc.)"
  value       = aws_eks_node_group.app.resources
}

output "app_asg_name" {
  description = "Name of the Auto Scaling Group for application nodes"
  value       = try(aws_eks_node_group.app.resources[0].autoscaling_groups[0].name, "")
}

output "app_node_group_launch_template_id" {
  description = "ID of the launch template used by application node group"
  value       = aws_launch_template.app.id
}

output "app_node_group_launch_template_latest_version" {
  description = "Latest version of the application node group launch template"
  value       = aws_launch_template.app.latest_version
}

###############################################################################
# Summary Outputs
###############################################################################

output "node_groups_summary" {
  description = "Summary of all node groups"
  value = {
    system = {
      id             = aws_eks_node_group.system.id
      status         = aws_eks_node_group.system.status
      desired_size   = aws_eks_node_group.system.scaling_config[0].desired_size
      min_size       = aws_eks_node_group.system.scaling_config[0].min_size
      max_size       = aws_eks_node_group.system.scaling_config[0].max_size
      instance_types = aws_eks_node_group.system.instance_types
      capacity_type  = aws_eks_node_group.system.capacity_type
    }
    app = {
      id             = aws_eks_node_group.app.id
      status         = aws_eks_node_group.app.status
      desired_size   = aws_eks_node_group.app.scaling_config[0].desired_size
      min_size       = aws_eks_node_group.app.scaling_config[0].min_size
      max_size       = aws_eks_node_group.app.scaling_config[0].max_size
      instance_types = aws_eks_node_group.app.instance_types
      capacity_type  = aws_eks_node_group.app.capacity_type
    }
  }
}

###############################################################################
# Cluster Information
###############################################################################

output "cluster_name" {
  description = "Name of the EKS cluster these node groups belong to"
  value       = var.cluster_name
}
