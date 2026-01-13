###############################################################################
# EKS Add-ons Module - Outputs
###############################################################################

output "vpc_cni" {
  description = "VPC CNI add-on details"
  value = {
    addon_name    = aws_eks_addon.vpc_cni.addon_name
    addon_version = aws_eks_addon.vpc_cni.addon_version
    arn           = aws_eks_addon.vpc_cni.arn
  }
}

output "coredns" {
  description = "CoreDNS add-on details"
  value = {
    addon_name    = aws_eks_addon.coredns.addon_name
    addon_version = aws_eks_addon.coredns.addon_version
    arn           = aws_eks_addon.coredns.arn
  }
}

output "kube_proxy" {
  description = "kube-proxy add-on details"
  value = {
    addon_name    = aws_eks_addon.kube_proxy.addon_name
    addon_version = aws_eks_addon.kube_proxy.addon_version
    arn           = aws_eks_addon.kube_proxy.arn
  }
}

output "ebs_csi_driver" {
  description = "EBS CSI Driver add-on details"
  value = var.enable_ebs_csi_driver ? {
    addon_name    = aws_eks_addon.ebs_csi_driver[0].addon_name
    addon_version = aws_eks_addon.ebs_csi_driver[0].addon_version
    arn           = aws_eks_addon.ebs_csi_driver[0].arn
  } : null
}

output "pod_identity_agent" {
  description = "Pod Identity Agent add-on details"
  value = var.enable_pod_identity_agent ? {
    addon_name    = aws_eks_addon.pod_identity_agent[0].addon_name
    addon_version = aws_eks_addon.pod_identity_agent[0].addon_version
    arn           = aws_eks_addon.pod_identity_agent[0].arn
  } : null
}

output "addon_arns" {
  description = "Map of all add-on ARNs"
  value = {
    vpc_cni            = aws_eks_addon.vpc_cni.arn
    coredns            = aws_eks_addon.coredns.arn
    kube_proxy         = aws_eks_addon.kube_proxy.arn
    ebs_csi_driver     = var.enable_ebs_csi_driver ? aws_eks_addon.ebs_csi_driver[0].arn : null
    pod_identity_agent = var.enable_pod_identity_agent ? aws_eks_addon.pod_identity_agent[0].arn : null
  }
}
