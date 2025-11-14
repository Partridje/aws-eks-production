###############################################################################
# IAM Module Variables
###############################################################################

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name (dev/staging/prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]*$", var.cluster_name))
    error_message = "Cluster name must start with a letter and contain only alphanumeric characters and hyphens."
  }
}

###############################################################################
# OIDC Provider Configuration
###############################################################################

variable "create_oidc_provider" {
  description = "Whether to create OIDC provider (set to false until EKS cluster is created)"
  type        = bool
  default     = false
}

variable "oidc_provider_url" {
  description = "OIDC provider URL from EKS cluster (e.g., https://oidc.eks.region.amazonaws.com/id/EXAMPLE)"
  type        = string
  default     = ""
}

variable "oidc_provider_arn" {
  description = "ARN of existing OIDC provider (used when create_oidc_provider = false)"
  type        = string
  default     = ""
}

###############################################################################
# Node Configuration
###############################################################################

variable "enable_ssm_access" {
  description = "Enable AWS Systems Manager Session Manager access to nodes"
  type        = bool
  default     = true
}

###############################################################################
# IRSA Policy Creation Flags
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
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}
