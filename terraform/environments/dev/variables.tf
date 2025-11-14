variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.30"
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDR blocks that can access the public API endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Restrict this in production!
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for devseatit.com"
  type        = string
  # Get this with: aws route53 list-hosted-zones
}

variable "alert_email" {
  description = "Email for CloudWatch alarms"
  type        = string
  default     = "tcytcerov@gmail.com"
}

variable "domain" {
  description = "Domain name for services (e.g., ArgoCD, Grafana)"
  type        = string
  default     = "devseatit.com"
}
