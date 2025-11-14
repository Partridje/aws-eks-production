###############################################################################
# EKS Node Groups - Variables
###############################################################################

###############################################################################
# Required Variables
###############################################################################

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "node_role_arn" {
  description = "ARN of the IAM role for EKS nodes"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs where nodes will be launched"
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "At least 2 private subnets are required for high availability."
  }
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC provider for the EKS cluster (for IRSA)"
  type        = string
}

variable "oidc_provider_url" {
  description = "URL of the OIDC provider for the EKS cluster (for IRSA)"
  type        = string
}

###############################################################################
# System Node Group Configuration
###############################################################################

variable "system_instance_types" {
  description = "Instance types for system node group"
  type        = list(string)
  default     = ["t3.medium"]

  validation {
    condition     = length(var.system_instance_types) > 0
    error_message = "At least one instance type must be specified."
  }
}

variable "system_desired_size" {
  description = "Desired number of nodes in system node group"
  type        = number
  default     = 2

  validation {
    condition     = var.system_desired_size >= 2
    error_message = "System node group must have at least 2 nodes for high availability."
  }
}

variable "system_min_size" {
  description = "Minimum number of nodes in system node group"
  type        = number
  default     = 2

  validation {
    condition     = var.system_min_size >= 2
    error_message = "System node group must have at least 2 nodes for high availability."
  }
}

variable "system_max_size" {
  description = "Maximum number of nodes in system node group"
  type        = number
  default     = 4

  validation {
    condition     = var.system_max_size >= var.system_min_size
    error_message = "Maximum size must be greater than or equal to minimum size."
  }
}

variable "system_node_disk_size" {
  description = "Disk size in GB for system nodes"
  type        = number
  default     = 50

  validation {
    condition     = var.system_node_disk_size >= 20 && var.system_node_disk_size <= 500
    error_message = "Disk size must be between 20 and 500 GB."
  }
}

###############################################################################
# Application Node Group Configuration
###############################################################################

variable "app_instance_types" {
  description = "Instance types for application node group"
  type        = list(string)
  default     = ["t3.large"]

  validation {
    condition     = length(var.app_instance_types) > 0
    error_message = "At least one instance type must be specified."
  }
}

variable "app_capacity_type" {
  description = "Capacity type for application nodes (ON_DEMAND or SPOT)"
  type        = string
  default     = "ON_DEMAND"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.app_capacity_type)
    error_message = "Capacity type must be either ON_DEMAND or SPOT."
  }
}

variable "app_desired_size" {
  description = "Desired number of nodes in application node group"
  type        = number
  default     = 2

  validation {
    condition     = var.app_desired_size >= 1
    error_message = "Application node group must have at least 1 node."
  }
}

variable "app_min_size" {
  description = "Minimum number of nodes in application node group"
  type        = number
  default     = 2

  validation {
    condition     = var.app_min_size >= 1
    error_message = "Application node group must have at least 1 node."
  }
}

variable "app_max_size" {
  description = "Maximum number of nodes in application node group"
  type        = number
  default     = 10

  validation {
    condition     = var.app_max_size >= var.app_min_size
    error_message = "Maximum size must be greater than or equal to minimum size."
  }
}

variable "app_node_disk_size" {
  description = "Disk size in GB for application nodes"
  type        = number
  default     = 100

  validation {
    condition     = var.app_node_disk_size >= 20 && var.app_node_disk_size <= 1000
    error_message = "Disk size must be between 20 and 1000 GB."
  }
}

###############################################################################
# Optional Configuration
###############################################################################

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
