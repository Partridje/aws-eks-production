# VPC Module for EKS

Production-ready VPC module designed specifically for Amazon EKS clusters with high availability, security, and cost optimization.

## Features

- **Multi-AZ Architecture**: Automatically distributes resources across 3 availability zones
- **EKS-Optimized**: Proper subnet tagging for EKS integration
- **High Availability**: NAT Gateway in each AZ (configurable)
- **Cost Optimization**: VPC endpoints to reduce NAT Gateway costs
- **Security**: VPC Flow Logs, private subnets, and security groups
- **Database Support**: Dedicated database subnet tier with subnet group

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              VPC (10.0.0.0/16)                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐        │
│  │   AZ-1 (us-e-1a)│  │   AZ-2 (us-e-1b)│  │   AZ-3 (us-e-1c)│        │
│  ├─────────────────┤  ├─────────────────┤  ├─────────────────┤        │
│  │                 │  │                 │  │                 │        │
│  │ Public Subnet   │  │ Public Subnet   │  │ Public Subnet   │        │
│  │ 10.0.0.0/20     │  │ 10.0.16.0/20    │  │ 10.0.32.0/20    │        │
│  │ • NAT GW        │  │ • NAT GW        │  │ • NAT GW        │        │
│  │ • ELB           │  │ • ELB           │  │ • ELB           │        │
│  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘        │
│           │                    │                    │                 │
│  ┌────────┴────────┐  ┌────────┴────────┐  ┌────────┴────────┐        │
│  │ Private Subnet  │  │ Private Subnet  │  │ Private Subnet  │        │
│  │ 10.0.48.0/20    │  │ 10.0.64.0/20    │  │ 10.0.80.0/20    │        │
│  │ • EKS Nodes     │  │ • EKS Nodes     │  │ • EKS Nodes     │        │
│  │ • App Pods      │  │ • App Pods      │  │ • App Pods      │        │
│  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘        │
│           │                    │                    │                 │
│  ┌────────┴────────┐  ┌────────┴────────┐  ┌────────┴────────┐        │
│  │ Database Subnet │  │ Database Subnet │  │ Database Subnet │        │
│  │ 10.0.96.0/24    │  │ 10.0.97.0/24    │  │ 10.0.98.0/24    │        │
│  │ • RDS           │  │ • RDS           │  │ • RDS           │        │
│  │ • ElastiCache   │  │ • ElastiCache   │  │ • ElastiCache   │        │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘        │
│                                                                         │
│  VPC Endpoints: S3 (Gateway), EC2, ECR, Logs, STS (Interface)         │
│  Flow Logs: CloudWatch Logs (ALL traffic)                              │
└─────────────────────────────────────────────────────────────────────────┘
```

## Usage

```hcl
module "vpc" {
  source = "../../modules/vpc"

  project_name = "my-project"
  environment  = "dev"
  cluster_name = "my-eks-cluster"

  vpc_cidr = "10.0.0.0/16"

  # High Availability (recommended for production)
  enable_nat_gateway = true
  single_nat_gateway = false  # NAT GW in each AZ

  # Cost Optimization
  enable_vpc_endpoints = true

  # Security & Monitoring
  enable_flow_logs      = true
  flow_logs_retention   = 7

  tags = {
    Terraform   = "true"
    CostCenter  = "engineering"
  }
}
```

### Cost Optimization Example (Development)

```hcl
module "vpc" {
  source = "../../modules/vpc"

  project_name = "my-project"
  environment  = "dev"
  cluster_name = "my-eks-cluster-dev"

  # Use single NAT Gateway to reduce costs
  enable_nat_gateway = true
  single_nat_gateway = true  # ~$32/month vs ~$96/month

  # Disable VPC endpoints in dev if not needed
  enable_vpc_endpoints = false

  # Reduce flow logs retention
  flow_logs_retention = 1
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_name | Project name used for resource naming | `string` | n/a | yes |
| environment | Environment name (dev/staging/prod) | `string` | n/a | yes |
| cluster_name | EKS cluster name for resource tagging | `string` | n/a | yes |
| vpc_cidr | CIDR block for VPC | `string` | `"10.0.0.0/16"` | no |
| azs | List of availability zones (auto-detect if empty) | `list(string)` | `[]` | no |
| enable_nat_gateway | Enable NAT Gateway for private subnets | `bool` | `true` | no |
| single_nat_gateway | Use single NAT Gateway (cost savings, reduced HA) | `bool` | `false` | no |
| enable_vpc_endpoints | Enable VPC endpoints for AWS services | `bool` | `true` | no |
| enable_flow_logs | Enable VPC Flow Logs | `bool` | `true` | no |
| flow_logs_retention | Number of days to retain VPC Flow Logs | `number` | `7` | no |
| tags | Additional tags for all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | The ID of the VPC |
| vpc_arn | The ARN of the VPC |
| vpc_cidr | The CIDR block of the VPC |
| availability_zones | List of availability zones used |
| public_subnet_ids | List of IDs of public subnets |
| private_subnet_ids | List of IDs of private subnets |
| database_subnet_ids | List of IDs of database subnets |
| database_subnet_group_name | Name of database subnet group |
| nat_gateway_ids | List of NAT Gateway IDs |
| nat_gateway_public_ips | List of public IPs for NAT Gateways |
| vpc_endpoint_s3_id | ID of S3 VPC endpoint |
| vpc_endpoint_ec2_id | ID of EC2 VPC endpoint |
| vpc_endpoint_ecr_api_id | ID of ECR API VPC endpoint |
| vpc_endpoint_ecr_dkr_id | ID of ECR DKR VPC endpoint |
| vpc_endpoint_logs_id | ID of CloudWatch Logs VPC endpoint |
| vpc_endpoint_sts_id | ID of STS VPC endpoint |
| flow_log_id | ID of the VPC Flow Log |
| flow_log_cloudwatch_log_group_name | CloudWatch Log Group for Flow Logs |

## Subnet CIDR Allocation

For default VPC CIDR `10.0.0.0/16`:

| Subnet Type | AZ | CIDR | IP Range | Available IPs |
|------------|-----|------|----------|---------------|
| Public | us-east-1a | 10.0.0.0/20 | 10.0.0.0 - 10.0.15.255 | 4,091 |
| Public | us-east-1b | 10.0.16.0/20 | 10.0.16.0 - 10.0.31.255 | 4,091 |
| Public | us-east-1c | 10.0.32.0/20 | 10.0.32.0 - 10.0.47.255 | 4,091 |
| Private | us-east-1a | 10.0.48.0/20 | 10.0.48.0 - 10.0.63.255 | 4,091 |
| Private | us-east-1b | 10.0.64.0/20 | 10.0.64.0 - 10.0.79.255 | 4,091 |
| Private | us-east-1c | 10.0.80.0/20 | 10.0.80.0 - 10.0.95.255 | 4,091 |
| Database | us-east-1a | 10.0.96.0/24 | 10.0.96.0 - 10.0.96.255 | 251 |
| Database | us-east-1b | 10.0.97.0/24 | 10.0.97.0 - 10.0.97.255 | 251 |
| Database | us-east-1c | 10.0.98.0/24 | 10.0.98.0 - 10.0.98.255 | 251 |

## EKS Integration

This module automatically tags subnets for EKS integration:

**All Subnets:**
```hcl
"kubernetes.io/cluster/${var.cluster_name}" = "shared"
```

**Public Subnets (for External Load Balancers):**
```hcl
"kubernetes.io/role/elb" = "1"
```

**Private Subnets (for Internal Load Balancers):**
```hcl
"kubernetes.io/role/internal-elb" = "1"
```

These tags enable EKS to:
- Automatically discover subnets for load balancer provisioning
- Place external ALB/NLB in public subnets
- Place internal ALB/NLB in private subnets

## VPC Endpoints

The module creates the following VPC endpoints to reduce NAT Gateway costs and improve security:

**Gateway Endpoint:**
- S3 (no additional cost)

**Interface Endpoints** (~$7.20/month each):
- EC2 (for EKS node management)
- ECR API (for pulling container images)
- ECR DKR (for pulling container layers)
- CloudWatch Logs (for logging)
- STS (for IAM authentication)

**Cost Savings:** VPC endpoints can significantly reduce data transfer costs through NAT Gateways, especially for ECR image pulls.

## Cost Breakdown

### Production Configuration (default settings)

| Resource | Quantity | Monthly Cost (us-east-1) |
|----------|----------|--------------------------|
| NAT Gateway | 3 | ~$97.92 |
| NAT Gateway Data Transfer | Variable | ~$0.045/GB |
| VPC Endpoints (Interface) | 5 | ~$36.00 |
| CloudWatch Logs (Flow Logs) | 1 | Variable |
| **Total (Fixed)** | | **~$133.92** |

### Development Configuration (optimized)

```hcl
single_nat_gateway   = true   # 1 NAT GW instead of 3
enable_vpc_endpoints = false  # Disable endpoints
flow_logs_retention  = 1      # Minimal retention
```

| Resource | Quantity | Monthly Cost (us-east-1) |
|----------|----------|--------------------------|
| NAT Gateway | 1 | ~$32.64 |
| **Total (Fixed)** | | **~$32.64** |

## Security Features

1. **VPC Flow Logs**: Monitor all network traffic for security analysis
2. **Private Subnets**: EKS nodes run in private subnets with no direct internet access
3. **Security Groups**: VPC endpoints have dedicated security group
4. **Encryption**: Flow logs stored in CloudWatch with encryption
5. **IAM Roles**: Least privilege IAM role for Flow Logs

## High Availability

- **Multi-AZ**: Resources distributed across 3 availability zones
- **NAT Gateway HA**: One NAT Gateway per AZ (when `single_nat_gateway = false`)
- **Route Table Isolation**: Each AZ has its own route table for fault isolation
- **Subnet Distribution**: Equal distribution of IP space across AZs

## Best Practices

1. **Production**: Use `single_nat_gateway = false` for high availability
2. **Development**: Use `single_nat_gateway = true` for cost savings
3. **VPC Endpoints**: Enable for production to reduce NAT costs
4. **Flow Logs**: Enable for security and troubleshooting
5. **CIDR Planning**: Ensure VPC CIDR doesn't overlap with other networks
6. **Tagging**: Add cost allocation tags via `tags` variable

## Troubleshooting

### Issue: EKS can't create load balancers

**Solution:** Verify subnets have the correct tags:
```bash
aws ec2 describe-subnets --subnet-ids <subnet-id> --query 'Subnets[].Tags'
```

Required tags should include:
- `kubernetes.io/cluster/<cluster-name> = shared`
- Public subnets: `kubernetes.io/role/elb = 1`
- Private subnets: `kubernetes.io/role/internal-elb = 1`

### Issue: High NAT Gateway costs

**Solutions:**
1. Enable VPC endpoints to reduce data transfer through NAT
2. For development, use `single_nat_gateway = true`
3. Review CloudWatch metrics to identify high-traffic sources

### Issue: Unable to pull ECR images

**Solution:** Verify VPC endpoints are configured:
- `ecr.api` endpoint exists
- `ecr.dkr` endpoint exists
- `s3` gateway endpoint exists (ECR uses S3 for layers)
- Security group allows HTTPS (443) from VPC CIDR

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.6 |
| aws | ~> 5.0 |

## Resources Created

This module creates approximately **35-40 resources**:

- 1 VPC
- 1 Internet Gateway
- 9 Subnets (3 public, 3 private, 3 database)
- 1 DB Subnet Group
- 4 Route Tables (1 public, 3 private, 1 database)
- 12 Route Table Associations
- 3-6 Routes (depending on NAT configuration)
- 3 NAT Gateways (or 1 if single_nat_gateway)
- 3 Elastic IPs (or 1 if single_nat_gateway)
- 1 Security Group (for VPC endpoints)
- 6 VPC Endpoints (1 gateway, 5 interface)
- 1 CloudWatch Log Group
- 1 IAM Role
- 1 IAM Policy
- 1 VPC Flow Log

## License

This module is part of the EKS GitOps infrastructure project.

## Authors

Created and maintained by the Platform Engineering team.

## References

- [AWS VPC Documentation](https://docs.aws.amazon.com/vpc/)
- [EKS VPC Requirements](https://docs.aws.amazon.com/eks/latest/userguide/network_reqs.html)
- [VPC Endpoints](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints.html)
- [VPC Flow Logs](https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs.html)
