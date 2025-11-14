variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "eks-gitops"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name (dev/prod)"
  type        = string
  default     = "shared"

  validation {
    condition     = contains(["dev", "prod", "shared"], var.environment)
    error_message = "Environment must be dev, prod, or shared."
  }
}

variable "region" {
  description = "AWS region for backend resources"
  type        = string
  default     = "us-east-1"
}

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default = {
    ManagedBy  = "Terraform"
    Purpose    = "TerraformBackend"
    Repository = "eks-infrastructure"
  }
}

variable "state_retention_days" {
  description = "Number of days to retain old state file versions"
  type        = number
  default     = 30
}

variable "enable_kms_encryption" {
  description = "Use KMS encryption instead of AES256 for S3 bucket"
  type        = bool
  default     = false
}
