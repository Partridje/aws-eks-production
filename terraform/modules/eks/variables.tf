variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version to use for the EKS cluster"
  type        = string
  default     = "1.30"
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "List of CIDR blocks that can access the public API server endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "cluster_log_retention_days" {
  description = "Number of days to retain cluster logs"
  type        = number
  default     = 7
}

# Node Group - On-Demand
variable "on_demand_instance_types" {
  description = "Instance types for on-demand node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "on_demand_desired_size" {
  description = "Desired number of on-demand nodes"
  type        = number
  default     = 2
}

variable "on_demand_min_size" {
  description = "Minimum number of on-demand nodes"
  type        = number
  default     = 1
}

variable "on_demand_max_size" {
  description = "Maximum number of on-demand nodes"
  type        = number
  default     = 3
}

# Node Group - Spot
variable "spot_instance_types" {
  description = "Instance types for spot node group"
  type        = list(string)
  default     = ["t3.medium", "t3a.medium"]
}

variable "spot_desired_size" {
  description = "Desired number of spot nodes"
  type        = number
  default     = 2
}

variable "spot_min_size" {
  description = "Minimum number of spot nodes"
  type        = number
  default     = 0
}

variable "spot_max_size" {
  description = "Maximum number of spot nodes"
  type        = number
  default     = 6
}

# EKS Add-ons versions
variable "vpc_cni_version" {
  description = "Version of vpc-cni addon"
  type        = string
  default     = null # Use latest
}

variable "coredns_version" {
  description = "Version of coredns addon"
  type        = string
  default     = null # Use latest
}

variable "kube_proxy_version" {
  description = "Version of kube-proxy addon"
  type        = string
  default     = null # Use latest
}

variable "ebs_csi_version" {
  description = "Version of EBS CSI driver addon"
  type        = string
  default     = null # Use latest
}

variable "cloudwatch_observability_version" {
  description = "Version of CloudWatch observability addon"
  type        = string
  default     = null # Use latest
}

# IAM Role ARNs from IAM module
variable "ebs_csi_controller_role_arn" {
  description = "ARN of the EBS CSI controller IAM role"
  type        = string
}

variable "cloudwatch_agent_role_arn" {
  description = "ARN of the CloudWatch agent IAM role"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
