###############################################################################
# Development Environment Outputs
###############################################################################

output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "The CIDR block of the VPC"
  value       = module.vpc.vpc_cidr
}

output "availability_zones" {
  description = "List of availability zones used"
  value       = module.vpc.availability_zones
}

###############################################################################
# Subnet Outputs
###############################################################################

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "database_subnet_ids" {
  description = "List of database subnet IDs"
  value       = module.vpc.database_subnet_ids
}

output "database_subnet_group_name" {
  description = "Name of the database subnet group"
  value       = module.vpc.database_subnet_group_name
}

###############################################################################
# Gateway Outputs
###############################################################################

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = module.vpc.nat_gateway_ids
}

output "nat_gateway_public_ips" {
  description = "List of NAT Gateway public IPs"
  value       = module.vpc.nat_gateway_public_ips
}

###############################################################################
# VPC Endpoint Outputs
###############################################################################

output "vpc_endpoint_s3_id" {
  description = "ID of S3 VPC endpoint"
  value       = module.vpc.vpc_endpoint_s3_id
}

output "vpc_endpoints_security_group_id" {
  description = "Security group ID for VPC endpoints"
  value       = module.vpc.vpc_endpoints_security_group_id
}

###############################################################################
# Summary Output
###############################################################################

output "vpc_summary" {
  description = "Summary of VPC configuration"
  value = {
    vpc_id             = module.vpc.vpc_id
    vpc_cidr           = module.vpc.vpc_cidr
    availability_zones = module.vpc.availability_zones
    public_subnets     = length(module.vpc.public_subnet_ids)
    private_subnets    = length(module.vpc.private_subnet_ids)
    database_subnets   = length(module.vpc.database_subnet_ids)
    nat_gateways       = length(module.vpc.nat_gateway_ids)
    vpc_endpoints      = module.vpc.vpc_endpoint_s3_id != null ? "enabled" : "disabled"
    flow_logs          = module.vpc.flow_log_id != null ? "enabled" : "disabled"
  }
}
