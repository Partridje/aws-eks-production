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
    condition     = var.system_max_size >= 2
    error_message = "Maximum size must be at least 2 for high availability."
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
    condition     = var.app_max_size >= 1
    error_message = "Maximum size must be at least 1."
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
# Node Health and Repair Configuration
###############################################################################

variable "enable_node_repair" {
  description = <<-EOT
    Enable automatic node repair for unhealthy nodes.

    When enabled, EKS will automatically detect and replace unhealthy nodes.
    This is a new feature in AWS Provider 6.0+ that improves cluster reliability.

    **Recommended:** Enable for production environments
  EOT
  type        = bool
  default     = true
}

###############################################################################
# AMI Configuration
###############################################################################

variable "system_ami_type" {
  description = <<-EOT
    AMI type for system node group.

    Options:
    - AL2_x86_64: Amazon Linux 2 (default for compatibility)
    - AL2023_x86_64_STANDARD: Amazon Linux 2023 (recommended for new clusters)
    - AL2_x86_64_GPU: Amazon Linux 2 with GPU support
    - AL2023_x86_64_NVIDIA: Amazon Linux 2023 with NVIDIA GPU support
    - AL2_ARM_64: Amazon Linux 2 ARM64
    - AL2023_ARM_64_STANDARD: Amazon Linux 2023 ARM64

    **Migration Note:** Changing from AL2 to AL2023 will recreate nodes.
    Plan carefully for production environments.
  EOT
  type        = string
  default     = "AL2_x86_64" # Conservative default for compatibility

  validation {
    condition = contains([
      "AL2_x86_64",
      "AL2023_x86_64_STANDARD",
      "AL2_x86_64_GPU",
      "AL2023_x86_64_NVIDIA",
      "AL2_ARM_64",
      "AL2023_ARM_64_STANDARD"
    ], var.system_ami_type)
    error_message = "AMI type must be a valid EKS AMI type."
  }
}

variable "app_ami_type" {
  description = <<-EOT
    AMI type for application node group.

    Options:
    - AL2_x86_64: Amazon Linux 2 (default for compatibility)
    - AL2023_x86_64_STANDARD: Amazon Linux 2023 (recommended for new clusters)
    - AL2_x86_64_GPU: Amazon Linux 2 with GPU support
    - AL2023_x86_64_NVIDIA: Amazon Linux 2023 with NVIDIA GPU support
    - AL2_ARM_64: Amazon Linux 2 ARM64
    - AL2023_ARM_64_STANDARD: Amazon Linux 2023 ARM64

    **Migration Note:** Changing from AL2 to AL2023 will recreate nodes.
    Plan carefully for production environments.
  EOT
  type        = string
  default     = "AL2_x86_64" # Conservative default for compatibility

  validation {
    condition = contains([
      "AL2_x86_64",
      "AL2023_x86_64_STANDARD",
      "AL2_x86_64_GPU",
      "AL2023_x86_64_NVIDIA",
      "AL2_ARM_64",
      "AL2023_ARM_64_STANDARD"
    ], var.app_ami_type)
    error_message = "AMI type must be a valid EKS AMI type."
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
