# EKS Add-ons IRSA Update
# This updates EKS add-ons with service account IAM roles after IAM module is created
# Run this after initial cluster deployment to enable IRSA for add-ons

# Note: These are null_resource with local-exec to avoid circular dependencies
# Alternative: Use kubectl provider or apply manually via AWS CLI

resource "null_resource" "update_ebs_csi_addon" {
  triggers = {
    role_arn = module.iam.ebs_csi_controller_role_arn
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws eks update-addon \
        --cluster-name ${module.eks.cluster_id} \
        --addon-name aws-ebs-csi-driver \
        --service-account-role-arn ${module.iam.ebs_csi_controller_role_arn} \
        --region ${var.aws_region} \
        --resolve-conflicts PRESERVE || true
    EOT
  }

  depends_on = [
    module.eks,
    module.iam
  ]
}

resource "null_resource" "update_cloudwatch_addon" {
  triggers = {
    role_arn = module.iam.cloudwatch_agent_role_arn
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws eks update-addon \
        --cluster-name ${module.eks.cluster_id} \
        --addon-name amazon-cloudwatch-observability \
        --service-account-role-arn ${module.iam.cloudwatch_agent_role_arn} \
        --region ${var.aws_region} \
        --resolve-conflicts PRESERVE || true
    EOT
  }

  depends_on = [
    module.eks,
    module.iam
  ]
}
