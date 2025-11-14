## EKS Cluster Module

Production-ready Amazon EKS cluster control plane with integrated OIDC provider for IRSA (IAM Roles for Service Accounts).

## Features

- **EKS Control Plane**: Managed Kubernetes control plane (v1.28+)
- **OIDC Provider**: Automatically created for IRSA support
- **Secrets Encryption**: KMS encryption for Kubernetes secrets at rest
- **Control Plane Logging**: CloudWatch Logs for audit and troubleshooting
- **Network Security**: Configurable public/private API access
- **High Availability**: Multi-AZ deployment in private subnets

## Resources Created

| Resource | Description | Count |
|----------|-------------|-------|
| EKS Cluster | Managed Kubernetes control plane | 1 |
| KMS Key | For secrets encryption | 1 |
| KMS Alias | For easier key identification | 1 |
| OIDC Provider | For IRSA | 1 |
| CloudWatch Log Group | For control plane logs | 1 |
| Security Group (optional) | Additional cluster security | 0-1 |

**Total:** 5-6 resources (~10-15 minutes to create)

## Usage

### Basic Usage

```hcl
module "eks_cluster" {
  source = "../../modules/eks-cluster"

  cluster_name    = "my-eks-cluster"
  cluster_version = "1.31"

  # From IAM module
  cluster_role_arn = module.iam_eks.cluster_role_arn

  # From VPC module
  private_subnet_ids = module.vpc.private_subnet_ids

  # API endpoint configuration
  endpoint_private_access = true
  endpoint_public_access  = true
  public_access_cidrs     = ["0.0.0.0/0"]

  # Logging
  enabled_log_types  = ["api", "audit", "authenticator"]
  log_retention_days = 7

  tags = {
    Environment = "dev"
  }
}
```

### Production Configuration

```hcl
module "eks_cluster" {
  source = "../../modules/eks-cluster"

  cluster_name    = "prod-eks-cluster"
  cluster_version = "1.31"

  cluster_role_arn   = module.iam_eks.cluster_role_arn
  private_subnet_ids = module.vpc.private_subnet_ids

  # Restrict public access to office IPs
  endpoint_private_access = true
  endpoint_public_access  = true
  public_access_cidrs     = ["203.0.113.0/24"]  # Your office IP range

  # Enable all logs for compliance
  enabled_log_types  = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  log_retention_days = 90
  encrypt_logs       = true

  # Additional security group
  create_cluster_security_group = true

  tags = {
    Environment = "prod"
    Compliance  = "true"
  }
}
```

## OIDC Provider & IRSA

This module **automatically creates an OIDC provider** when the cluster is created. This enables IRSA (IAM Roles for Service Accounts) immediately.

### What is IRSA?

IRSA allows Kubernetes pods to assume IAM roles without using node instance credentials. This provides:
- **Least Privilege**: Each service account can have unique IAM permissions
- **Security**: No AWS credentials in pods or ConfigMaps
- **Auditability**: CloudTrail logs show which pod made which API call

### How it Works

1. EKS cluster creates OIDC endpoint
2. This module creates IAM OIDC provider pointing to that endpoint
3. Kubernetes service accounts can be annotated with IAM role ARNs
4. Pods using those service accounts get temporary AWS credentials

### Using IRSA

After cluster creation, you can immediately use IRSA:

```yaml
# Kubernetes Service Account
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app
  namespace: default
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT_ID:role/my-app-role
```

```hcl
# IAM Role with IRSA Trust Policy
data "aws_iam_policy_document" "my_app_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [module.eks_cluster.oidc_provider_arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "${module.eks_cluster.cluster_oidc_provider_url}:sub"
      values   = ["system:serviceaccount:default:my-app"]
    }

    condition {
      test     = "StringEquals"
      variable = "${module.eks_cluster.cluster_oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "my_app" {
  name               = "my-app-role"
  assume_role_policy = data.aws_iam_policy_document.my_app_assume_role.json
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| cluster_name | EKS cluster name | `string` | n/a | yes |
| cluster_version | Kubernetes version (1.28-1.31) | `string` | `"1.31"` | no |
| cluster_role_arn | IAM role ARN for cluster | `string` | n/a | yes |
| private_subnet_ids | Private subnet IDs (min 2) | `list(string)` | n/a | yes |
| endpoint_private_access | Enable private API endpoint | `bool` | `true` | no |
| endpoint_public_access | Enable public API endpoint | `bool` | `true` | no |
| public_access_cidrs | CIDRs for public API access | `list(string)` | `["0.0.0.0/0"]` | no |
| create_cluster_security_group | Create additional security group | `bool` | `false` | no |
| additional_security_group_ids | Additional security group IDs | `list(string)` | `[]` | no |
| enabled_log_types | Control plane log types | `list(string)` | `["api","audit","authenticator"]` | no |
| log_retention_days | Log retention in days | `number` | `7` | no |
| encrypt_logs | Encrypt logs with KMS | `bool` | `false` | no |
| tags | Additional tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster_id | EKS cluster name |
| cluster_arn | EKS cluster ARN |
| cluster_endpoint | Kubernetes API server endpoint |
| cluster_version | Kubernetes version |
| cluster_security_group_id | Cluster security group ID |
| cluster_certificate_authority_data | Base64 encoded CA cert |
| cluster_oidc_issuer_url | Full OIDC issuer URL |
| oidc_provider_arn | OIDC provider ARN (for IRSA) |
| cluster_oidc_provider_url | OIDC URL without https:// |
| kms_key_id | KMS key ID for secrets |
| kms_key_arn | KMS key ARN |

## Post-Deployment

### 1. Configure kubectl

```bash
aws eks update-kubeconfig --region us-east-1 --name my-cluster-name
```

### 2. Verify Cluster

```bash
kubectl cluster-info
kubectl get nodes  # Will be empty until node groups are added
kubectl get pods -A
```

### 3. Verify OIDC Provider

```bash
# Get OIDC provider ARN
terraform output oidc_provider_arn

# List OIDC providers
aws iam list-open-id-connect-providers

# Describe OIDC provider
aws iam get-open-id-connect-provider --open-id-connect-provider-arn <ARN>
```

### 4. Test IRSA (After Deploying a Pod)

```bash
# Check service account annotation
kubectl describe sa my-app -n default

# Check pod environment variables
kubectl exec -it my-pod -- env | grep AWS

# Verify IAM role assumption
kubectl exec -it my-pod -- aws sts get-caller-identity
```

## Control Plane Logging

The module enables cluster logging to CloudWatch Logs. Available log types:

| Log Type | Description | Production |
|----------|-------------|------------|
| **api** | API server logs | ✅ Required |
| **audit** | Kubernetes audit logs | ✅ Required |
| **authenticator** | Authentication logs | ✅ Required |
| controllerManager | Controller manager logs | Optional |
| scheduler | Scheduler logs | Optional |

**Recommendation:** Enable `api`, `audit`, and `authenticator` for development. Enable all for production.

### Viewing Logs

```bash
# List log streams
aws logs describe-log-streams \
  --log-group-name /aws/eks/my-cluster/cluster

# Tail logs
aws logs tail /aws/eks/my-cluster/cluster --follow

# Query logs (CloudWatch Insights)
aws logs start-query \
  --log-group-name /aws/eks/my-cluster/cluster \
  --start-time $(date -u -d '1 hour ago' +%s) \
  --end-time $(date -u +%s) \
  --query-string 'fields @timestamp, @message | sort @timestamp desc'
```

## Security Features

### Secrets Encryption

All Kubernetes secrets are encrypted at rest using AWS KMS:
- Automatic key rotation enabled
- CloudWatch Logs can also use KMS (opt-in)
- Keys are account-specific
- 7-day deletion window for recovery

### API Endpoint Access

**Private Access (endpoint_private_access=true):**
- API calls from within VPC use private endpoint
- No internet gateway required
- Lower latency
- Always enabled for security

**Public Access (endpoint_public_access=true):**
- API accessible from internet
- Restrict with `public_access_cidrs`
- Can be disabled after VPN/bastion setup
- Useful for CI/CD systems

**Recommendation:**
- Dev: Public enabled with CIDR restrictions
- Prod: Public enabled initially, disabled after VPN setup

### Network Security

- Control plane runs in AWS-managed VPC
- ENIs placed in your private subnets
- Security groups control API access
- Supports additional security groups

## Troubleshooting

### Issue: Cluster creation stuck

**Symptoms:** `terraform apply` running for 20+ minutes

**Solution:** EKS clusters take 10-15 minutes to create. This is normal.

```bash
# Check cluster status
aws eks describe-cluster --name my-cluster --query 'cluster.status'
```

### Issue: kubectl can't connect

**Error:** `Unable to connect to the server`

**Solutions:**
1. Configure kubectl:
   ```bash
   aws eks update-kubeconfig --region us-east-1 --name my-cluster
   ```

2. Verify API endpoint access:
   ```bash
   aws eks describe-cluster --name my-cluster --query 'cluster.resourcesVpcConfig'
   ```

3. Check your IP is in `public_access_cidrs`:
   ```bash
   curl -s https://checkip.amazonaws.com
   ```

4. Verify IAM permissions:
   ```bash
   aws sts get-caller-identity
   ```

### Issue: IRSA not working

**Error:** Pod can't assume IAM role

**Checklist:**
1. ✅ OIDC provider created
2. ✅ Service account has correct annotation
3. ✅ IAM role trust policy matches
4. ✅ IAM role has required permissions
5. ✅ Pod is using correct service account

**Debug:**
```bash
# Check OIDC provider
terraform output oidc_provider_arn

# Check service account
kubectl describe sa my-app -n namespace

# Check pod service account
kubectl get pod my-pod -o jsonpath='{.spec.serviceAccountName}'

# Check AWS_WEB_IDENTITY_TOKEN_FILE
kubectl exec my-pod -- env | grep AWS
```

### Issue: High CloudWatch Logs costs

**Solution:** Reduce log types or retention:

```hcl
# Minimal logging
enabled_log_types  = ["audit"]
log_retention_days = 1

# Or disable less critical logs
enabled_log_types = ["api", "audit"]  # Exclude authenticator
```

## Cost Optimization

### Control Plane
- **Fixed cost:** $0.10/hour = ~$73/month
- Cannot be reduced
- Same cost regardless of cluster size

### CloudWatch Logs
- **Ingestion:** ~$0.50/GB
- **Storage:** ~$0.03/GB/month
- **Retention:** Higher retention = higher storage costs

**Optimization:**
```hcl
# Development
enabled_log_types  = ["api"]  # Minimal
log_retention_days = 1        # 1 day

# Production
enabled_log_types  = ["api", "audit"]  # Essential only
log_retention_days = 30                 # Compliance minimum
```

### KMS
- **Key:** $1/month
- **Requests:** $0.03 per 10,000
- Total: ~$1-2/month

## Upgrade Strategy

### Kubernetes Version Upgrades

EKS supports in-place cluster upgrades:

```hcl
# Before
cluster_version = "1.30"

# After
cluster_version = "1.31"
```

**Process:**
1. Review [version release notes](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/)
2. Test in dev environment first
3. Upgrade control plane (this module)
4. Update node groups (separate module)
5. Update add-ons and applications

**Important:** Can only upgrade one minor version at a time (1.29 → 1.30, not 1.29 → 1.31).

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.6 |
| aws | ~> 5.0 |
| tls | ~> 4.0 |

## Dependencies

This module requires:
- VPC with private subnets (from VPC module)
- IAM role for cluster (from IAM module)

## Examples

See `terraform/environments/dev/03-eks-cluster/` for a complete example.

## References

- [EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [IRSA Documentation](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
- [EKS Versions](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html)
