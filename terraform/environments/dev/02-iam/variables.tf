###############################################################################
# Development Environment - IAM Variables
###############################################################################

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "eks-gitops"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "cost_center" {
  description = "Cost center for billing tracking"
  type        = string
  default     = "engineering"
}

###############################################################################
# OIDC Provider Configuration
###############################################################################

variable "create_oidc_provider" {
  description = "Create OIDC provider (set to true after EKS cluster is created)"
  type        = bool
  default     = false
}

variable "oidc_provider_url" {
  description = "OIDC provider URL from EKS cluster (set after EKS cluster creation)"
  type        = string
  default     = ""
}

###############################################################################
# Node Configuration
###############################################################################

variable "enable_ssm_access" {
  description = "Enable SSM Session Manager access to nodes"
  type        = bool
  default     = true
}

###############################################################################
# IRSA Policy Configuration
###############################################################################

variable "create_ebs_csi_policy" {
  description = "Create IAM policy for EBS CSI Driver"
  type        = bool
  default     = true
}

variable "create_external_dns_policy" {
  description = "Create IAM policy for External DNS"
  type        = bool
  default     = true
}

variable "create_cluster_autoscaler_policy" {
  description = "Create IAM policy for Cluster Autoscaler"
  type        = bool
  default     = true
}

variable "create_aws_load_balancer_controller_policy" {
  description = "Create IAM policy for AWS Load Balancer Controller"
  type        = bool
  default     = true
}

###############################################################################
# Tags
###############################################################################

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}
