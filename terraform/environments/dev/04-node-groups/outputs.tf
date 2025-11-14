###############################################################################
# Development Environment - EKS Node Groups Outputs
###############################################################################

###############################################################################
# System Node Group Outputs
###############################################################################

output "system_node_group_id" {
  description = "ID of the system node group"
  value       = module.node_groups.system_node_group_id
}

output "system_node_group_arn" {
  description = "ARN of the system node group"
  value       = module.node_groups.system_node_group_arn
}

output "system_node_group_status" {
  description = "Status of the system node group"
  value       = module.node_groups.system_node_group_status
}

output "system_asg_name" {
  description = "Auto Scaling Group name for system nodes"
  value       = module.node_groups.system_asg_name
}

###############################################################################
# Application Node Group Outputs
###############################################################################

output "app_node_group_id" {
  description = "ID of the application node group"
  value       = module.node_groups.app_node_group_id
}

output "app_node_group_arn" {
  description = "ARN of the application node group"
  value       = module.node_groups.app_node_group_arn
}

output "app_node_group_status" {
  description = "Status of the application node group"
  value       = module.node_groups.app_node_group_status
}

output "app_asg_name" {
  description = "Auto Scaling Group name for application nodes"
  value       = module.node_groups.app_asg_name
}

###############################################################################
# Summary Output
###############################################################################

output "node_groups_summary" {
  description = "Summary of all node groups"
  value       = module.node_groups.node_groups_summary
}

###############################################################################
# Verification Commands
###############################################################################

output "verify_nodes" {
  description = "Command to verify nodes with labels"
  value       = "kubectl get nodes -L node.kubernetes.io/type,workload-type"
}

output "verify_taints" {
  description = "Command to verify node taints"
  value       = "kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints"
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${local.cluster_name}"
}
