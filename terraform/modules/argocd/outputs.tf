output "namespace" {
  description = "ArgoCD namespace"
  value       = kubernetes_namespace.argocd.metadata[0].name
}

output "release_name" {
  description = "Helm release name"
  value       = helm_release.argocd.name
}

output "admin_password_secret_arn" {
  description = "ARN of the AWS Secrets Manager secret containing ArgoCD admin password"
  value       = aws_secretsmanager_secret.argocd_admin.arn
}

output "admin_password" {
  description = "ArgoCD admin password (sensitive)"
  value       = random_password.argocd_admin.result
  sensitive   = true
}

output "argocd_server_url" {
  description = "ArgoCD server URL"
  value       = "https://argocd.${var.domain}"
}
