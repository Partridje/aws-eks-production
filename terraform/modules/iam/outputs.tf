output "oidc_provider_arn" {
  description = "ARN of the OIDC provider"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "cluster_autoscaler_role_arn" {
  description = "ARN of the Cluster Autoscaler IAM role"
  value       = module.cluster_autoscaler_role.role_arn
}

output "aws_load_balancer_controller_role_arn" {
  description = "ARN of the AWS Load Balancer Controller IAM role"
  value       = module.aws_load_balancer_controller_role.role_arn
}

output "external_secrets_role_arn" {
  description = "ARN of the External Secrets IAM role"
  value       = module.external_secrets_role.role_arn
}

output "cert_manager_role_arn" {
  description = "ARN of the Cert Manager IAM role"
  value       = module.cert_manager_role.role_arn
}

output "external_dns_role_arn" {
  description = "ARN of the External DNS IAM role"
  value       = module.external_dns_role.role_arn
}

output "ebs_csi_controller_role_arn" {
  description = "ARN of the EBS CSI Controller IAM role"
  value       = module.ebs_csi_controller_role.role_arn
}

output "fluent_bit_role_arn" {
  description = "ARN of the Fluent Bit IAM role"
  value       = module.fluent_bit_role.role_arn
}

output "grafana_role_arn" {
  description = "ARN of the Grafana IAM role"
  value       = module.grafana_role.role_arn
}

output "xray_daemon_role_arn" {
  description = "ARN of the X-Ray Daemon IAM role"
  value       = module.xray_daemon_role.role_arn
}

output "cloudwatch_agent_role_arn" {
  description = "ARN of the CloudWatch Agent IAM role"
  value       = module.cloudwatch_agent_role.role_arn
}

output "argocd_role_arn" {
  description = "ARN of the ArgoCD IAM role"
  value       = module.argocd_role.role_arn
}
