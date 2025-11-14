###############################################################################
# Development Environment - EKS Node Groups Variables
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
# System Node Group Configuration
###############################################################################

variable "system_instance_types" {
  description = "Instance types for system node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "system_desired_size" {
  description = "Desired number of nodes in system node group"
  type        = number
  default     = 2
}

variable "system_min_size" {
  description = "Minimum number of nodes in system node group"
  type        = number
  default     = 2
}

variable "system_max_size" {
  description = "Maximum number of nodes in system node group"
  type        = number
  default     = 4
}

variable "system_node_disk_size" {
  description = "Disk size in GB for system nodes"
  type        = number
  default     = 50
}

###############################################################################
# Application Node Group Configuration
###############################################################################

variable "app_instance_types" {
  description = "Instance types for application node group"
  type        = list(string)
  default     = ["t3.large"]
}

variable "app_capacity_type" {
  description = "Capacity type for application nodes (ON_DEMAND or SPOT)"
  type        = string
  default     = "ON_DEMAND"
}

variable "app_desired_size" {
  description = "Desired number of nodes in application node group"
  type        = number
  default     = 2
}

variable "app_min_size" {
  description = "Minimum number of nodes in application node group"
  type        = number
  default     = 2
}

variable "app_max_size" {
  description = "Maximum number of nodes in application node group"
  type        = number
  default     = 10
}

variable "app_node_disk_size" {
  description = "Disk size in GB for application nodes"
  type        = number
  default     = 100
}

###############################################################################
# Tags
###############################################################################

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}
