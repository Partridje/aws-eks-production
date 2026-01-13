###############################################################################
# EKS Cluster Module Variables
###############################################################################

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]*$", var.cluster_name)) && length(var.cluster_name) <= 100
    error_message = "Cluster name must start with a letter, contain only alphanumeric characters and hyphens, and be max 100 characters."
  }
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.31"

  validation {
    condition     = can(regex("^1\\.(2[89]|3[0-9])$", var.cluster_version))
    error_message = "Cluster version must be 1.28 or higher."
  }
}

variable "upgrade_policy_support_type" {
  description = <<-EOT
    Support type for the EKS cluster upgrade policy.

    Options:
    - STANDARD: Standard support (default)
    - EXTENDED: Extended support for older Kubernetes versions (additional cost)

    See: https://docs.aws.amazon.com/eks/latest/userguide/extended-support.html
  EOT
  type        = string
  default     = "STANDARD"

  validation {
    condition     = contains(["STANDARD", "EXTENDED"], var.upgrade_policy_support_type)
    error_message = "Support type must be either STANDARD or EXTENDED."
  }
}

variable "cluster_role_arn" {
  description = "ARN of the IAM role for the EKS cluster"
  type        = string

  validation {
    condition     = can(regex("^arn:aws:iam::[0-9]{12}:role/", var.cluster_role_arn))
    error_message = "Cluster role ARN must be a valid IAM role ARN."
  }
}

###############################################################################
# Network Configuration
###############################################################################

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the EKS cluster control plane"
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "At least 2 private subnets are required for high availability."
  }
}

variable "endpoint_private_access" {
  description = "Enable private API server endpoint"
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = <<-EOT
    Enable public API server endpoint.

    Security considerations:
    - Production: Set to false and use VPN/bastion
    - Development: Can be true with specific CIDR restrictions
    - If true, you MUST specify public_access_cidrs with your office/VPN IPs
  EOT
  type        = bool
  default     = false # Secure by default - enable explicitly if needed
}

variable "public_access_cidrs" {
  description = <<-EOT
    List of CIDR blocks that can access the public API server endpoint.

    **Security Best Practices:**
    - Development: Use your office/VPN IP ranges, or 0.0.0.0/0 only if necessary
    - Production: **NEVER use 0.0.0.0/0** - use specific IP ranges or disable public access
    - Example: ["203.0.113.0/24", "198.51.100.0/24"]

    When endpoint_public_access is false, this setting is ignored.
  EOT
  type        = list(string)
  default     = [] # Empty by default - must be explicitly set if public access is enabled

  validation {
    condition     = length(var.public_access_cidrs) == 0 || length(var.public_access_cidrs) > 0
    error_message = "If specified, at least one CIDR block must be provided."
  }
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
  description = "Additional security group IDs to attach to the cluster"
  type        = list(string)
  default     = []
}

###############################################################################
# Logging Configuration
###############################################################################

variable "enabled_log_types" {
  description = <<-EOT
    List of control plane logging types to enable.

    AWS Best Practice: Enable all 5 log types for production clusters:
    - api: Kubernetes API server logs
    - audit: Kubernetes audit logs (who did what, when)
    - authenticator: AWS IAM authenticator logs
    - controllerManager: Controller manager logs
    - scheduler: Scheduler logs

    Minimum recommended for development: ["api", "audit", "authenticator"]
  EOT
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  validation {
    condition = alltrue([
      for log_type in var.enabled_log_types :
      contains(["api", "audit", "authenticator", "controllerManager", "scheduler"], log_type)
    ])
    error_message = "Log types must be one of: api, audit, authenticator, controllerManager, scheduler."
  }
}

variable "log_retention_days" {
  description = <<-EOT
    Number of days to retain EKS cluster logs in CloudWatch.

    AWS Best Practice for production: 90 days minimum for compliance.
    Consider longer retention (365+ days) for audit requirements.
  EOT
  type        = number
  default     = 90

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch Logs retention period."
  }
}

variable "encrypt_logs" {
  description = <<-EOT
    Encrypt CloudWatch logs with KMS.

    AWS Best Practice: Enable for production clusters to protect sensitive
    data in logs (API calls, authentication events, etc.)
  EOT
  type        = bool
  default     = true
}

###############################################################################
# Access Entries Configuration
# API-based access management (replaces aws-auth ConfigMap)
###############################################################################

variable "authentication_mode" {
  description = <<-EOT
    Cluster authentication mode.

    Options:
    - API: Uses only EKS access entries for authentication (recommended for new clusters)
    - API_AND_CONFIG_MAP: Uses both access entries and aws-auth ConfigMap (migration mode)
    - CONFIG_MAP: Uses only aws-auth ConfigMap (legacy, not recommended)

    AWS Best Practice: Use API mode for new clusters, API_AND_CONFIG_MAP during migration.
  EOT
  type        = string
  default     = "API_AND_CONFIG_MAP"

  validation {
    condition     = contains(["API", "API_AND_CONFIG_MAP", "CONFIG_MAP"], var.authentication_mode)
    error_message = "Authentication mode must be API, API_AND_CONFIG_MAP, or CONFIG_MAP."
  }
}

variable "access_entries" {
  description = <<-EOT
    Map of access entries to create for the cluster.

    Each entry associates an IAM principal with Kubernetes permissions.

    Example:
    ```
    access_entries = {
      admin = {
        principal_arn = "arn:aws:iam::123456789012:role/AdminRole"
        type          = "STANDARD"  # STANDARD, FARGATE_LINUX, or EC2_LINUX
        access_policies = [
          {
            policy_name = "AmazonEKSClusterAdminPolicy"
            access_scope = {
              type = "cluster"  # cluster or namespace
            }
          }
        ]
      }
      developer = {
        principal_arn = "arn:aws:iam::123456789012:role/DevRole"
        access_policies = [
          {
            policy_name = "AmazonEKSViewPolicy"
            access_scope = {
              type       = "namespace"
              namespaces = ["dev", "staging"]
            }
          }
        ]
      }
    }
    ```

    Available access policies:
    - AmazonEKSClusterAdminPolicy: Full cluster admin access
    - AmazonEKSAdminPolicy: Admin access to most resources
    - AmazonEKSEditPolicy: Create/edit most resources
    - AmazonEKSViewPolicy: Read-only access
  EOT
  type = map(object({
    principal_arn     = string
    type              = optional(string, "STANDARD")
    kubernetes_groups = optional(list(string))
    user_name         = optional(string)
    access_policies = optional(list(object({
      policy_name = string
      access_scope = object({
        type       = string
        namespaces = optional(list(string))
      })
    })), [])
  }))
  default = {}
}

###############################################################################
# Tags
###############################################################################

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}
