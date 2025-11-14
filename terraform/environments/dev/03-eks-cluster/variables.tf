###############################################################################
# Development Environment - EKS Cluster Variables
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
# EKS Cluster Configuration
###############################################################################

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.31"
}

###############################################################################
# Network Configuration
###############################################################################

variable "endpoint_private_access" {
  description = "Enable private API server endpoint"
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = <<-EOT
    Enable public API server endpoint.

    DEV ENVIRONMENT: Set to true for kubectl access from developer machines.
    PROD ENVIRONMENT: Should be false (use VPN/bastion for access).
  EOT
  type        = bool
  default     = true # Intentionally enabled for dev - change to false for prod
}

variable "public_access_cidrs" {
  description = <<-EOT
    List of CIDR blocks for public API access.

    DEV ENVIRONMENT: 0.0.0.0/0 allows access from anywhere (acceptable for dev/test).
    PROD ENVIRONMENT: Must specify office/VPN IP ranges, never use 0.0.0.0/0.
  EOT
  type        = list(string)
  default     = ["0.0.0.0/0"] # Intentionally permissive for dev - restrict for prod
}

###############################################################################
# Security Configuration
###############################################################################

variable "create_cluster_security_group" {
  description = "Create additional security group for the cluster"
  type        = bool
  default     = false
}

variable "additional_security_group_ids" {
  description = "Additional security group IDs to attach"
  type        = list(string)
  default     = []
}

###############################################################################
# Logging Configuration
###############################################################################

variable "enabled_log_types" {
  description = "List of control plane logging types to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator"]
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "encrypt_logs" {
  description = "Encrypt CloudWatch logs with KMS"
  type        = bool
  default     = false
}

###############################################################################
# Tags
###############################################################################

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}
