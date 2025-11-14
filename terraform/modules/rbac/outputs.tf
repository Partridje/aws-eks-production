output "admin_role_arn" {
  description = "ARN of the EKS admin IAM role"
  value       = aws_iam_role.eks_admin.arn
}

output "developer_role_arn" {
  description = "ARN of the EKS developer IAM role"
  value       = aws_iam_role.eks_developer.arn
}

output "viewer_role_arn" {
  description = "ARN of the EKS viewer IAM role"
  value       = aws_iam_role.eks_viewer.arn
}

output "admin_role_name" {
  description = "Name of the EKS admin IAM role"
  value       = aws_iam_role.eks_admin.name
}

output "developer_role_name" {
  description = "Name of the EKS developer IAM role"
  value       = aws_iam_role.eks_developer.name
}

output "viewer_role_name" {
  description = "Name of the EKS viewer IAM role"
  value       = aws_iam_role.eks_viewer.name
}
