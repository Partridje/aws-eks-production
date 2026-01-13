###############################################################################
# EKS Add-ons Module - Variables
###############################################################################

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_dependencies" {
  description = "List of resources the add-ons depend on (e.g., cluster, node groups)"
  type        = list(any)
  default     = []
}

###############################################################################
# Add-on Versions
###############################################################################

variable "addon_versions" {
  description = "Versions for each EKS add-on. Set to null to use the default version for the cluster."
  type = object({
    vpc_cni            = optional(string)
    coredns            = optional(string)
    kube_proxy         = optional(string)
    ebs_csi            = optional(string)
    pod_identity_agent = optional(string)
  })
  default = {
    vpc_cni            = null
    coredns            = null
    kube_proxy         = null
    ebs_csi            = null
    pod_identity_agent = null
  }
}

###############################################################################
# VPC CNI Configuration
###############################################################################

variable "vpc_cni_role_arn" {
  description = "ARN of the IAM role for VPC CNI (IRSA). Required for prefix delegation and custom networking."
  type        = string
  default     = null
}

variable "enable_network_policy" {
  description = "Enable Kubernetes Network Policy support in VPC CNI"
  type        = bool
  default     = true
}

variable "enable_prefix_delegation" {
  description = "Enable prefix delegation for higher pod density per node"
  type        = bool
  default     = true
}

variable "warm_ip_target" {
  description = "Number of free IPs to keep available for pod assignment"
  type        = number
  default     = 5
}

variable "minimum_ip_target" {
  description = "Minimum number of IPs to keep available"
  type        = number
  default     = 2
}

###############################################################################
# CoreDNS Configuration
###############################################################################

variable "coredns_replicas" {
  description = "Number of CoreDNS replicas"
  type        = number
  default     = 2
}

variable "coredns_resources" {
  description = "Resource limits and requests for CoreDNS"
  type = object({
    limits = object({
      cpu    = string
      memory = string
    })
    requests = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    limits = {
      cpu    = "100m"
      memory = "150Mi"
    }
    requests = {
      cpu    = "100m"
      memory = "70Mi"
    }
  }
}

###############################################################################
# EBS CSI Driver Configuration
###############################################################################

variable "enable_ebs_csi_driver" {
  description = "Enable EBS CSI Driver add-on for persistent volume support"
  type        = bool
  default     = true
}

variable "ebs_csi_role_arn" {
  description = "ARN of the IAM role for EBS CSI Driver (IRSA)"
  type        = string
  default     = null
}

###############################################################################
# Pod Identity Agent Configuration
###############################################################################

variable "enable_pod_identity_agent" {
  description = "Enable EKS Pod Identity Agent add-on"
  type        = bool
  default     = true
}

###############################################################################
# Tags
###############################################################################

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
