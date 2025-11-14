# IAM Module for EKS

Production-ready IAM roles and policies for Amazon EKS clusters with support for IRSA (IAM Roles for Service Accounts).

## Features

- **EKS Cluster Role**: IAM role for EKS control plane
- **EKS Node Role**: IAM role for worker nodes with EC2 instance profile
- **OIDC Provider**: OpenID Connect provider for IRSA
- **IRSA Policies**: Pre-configured policies for common Kubernetes add-ons
- **SSM Access**: Optional Systems Manager access for node troubleshooting
- **Secure Defaults**: Follows AWS security best practices

## Resources Created

| Resource | Description | Count |
|----------|-------------|-------|
| IAM Role (Cluster) | EKS control plane role | 1 |
| IAM Role (Node) | EKS worker node role | 1 |
| IAM Instance Profile | EC2 instance profile for nodes | 1 |
| IAM Role Policy Attachments | AWS managed policies | 5-6 |
| OIDC Provider | For IRSA (optional) | 0-1 |
| IAM Policies | For add-ons (EBS CSI, External DNS, etc.) | 0-4 |

## Usage

### Basic Usage (Without OIDC)

```hcl
module "iam_eks" {
  source = "../../modules/iam-eks"

  project_name = "my-project"
  environment  = "dev"
  cluster_name = "my-eks-cluster"

  # OIDC not created yet (cluster doesn't exist)
  create_oidc_provider = false

  # Enable SSM for node access
  enable_ssm_access = true

  tags = {
    Terraform = "true"
  }
}
```

### With OIDC Provider (After EKS Cluster Created)

```hcl
module "iam_eks" {
  source = "../../modules/iam-eks"

  project_name = "my-project"
  environment  = "dev"
  cluster_name = "my-eks-cluster"

  # Create OIDC provider
  create_oidc_provider = true
  oidc_provider_url    = "https://oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE"

  # Create IRSA policies
  create_ebs_csi_policy                      = true
  create_external_dns_policy                 = true
  create_cluster_autoscaler_policy           = true
  create_aws_load_balancer_controller_policy = true

  tags = {
    Terraform = "true"
  }
}
```

## IRSA (IAM Roles for Service Accounts)

IRSA allows Kubernetes service accounts to assume IAM roles, eliminating the need to use node IAM credentials.

### How IRSA Works

1. EKS cluster has an OIDC provider
2. Kubernetes service account has an annotation with IAM role ARN
3. Pod uses projected service account token
4. AWS STS validates the token via OIDC
5. Pod receives temporary AWS credentials

### Example: Creating IRSA Role for EBS CSI Driver

```hcl
# After creating this module, create IRSA roles like this:

data "aws_iam_policy_document" "ebs_csi_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [module.iam_eks.oidc_provider_arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "${module.iam_eks.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

    condition {
      test     = "StringEquals"
      variable = "${module.iam_eks.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi_driver" {
  name               = "${var.cluster_name}-ebs-csi-driver"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  role       = aws_iam_role.ebs_csi_driver.name
  policy_arn = module.iam_eks.ebs_csi_policy_arn
}
```

### Kubernetes Service Account Configuration

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ebs-csi-controller-sa
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT_ID:role/my-cluster-ebs-csi-driver
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_name | Project name for resource naming | `string` | n/a | yes |
| environment | Environment (dev/staging/prod) | `string` | n/a | yes |
| cluster_name | EKS cluster name | `string` | n/a | yes |
| create_oidc_provider | Create OIDC provider (false until cluster exists) | `bool` | `false` | no |
| oidc_provider_url | OIDC provider URL from EKS cluster | `string` | `""` | no |
| oidc_provider_arn | ARN of existing OIDC provider | `string` | `""` | no |
| enable_ssm_access | Enable SSM Session Manager access | `bool` | `true` | no |
| create_ebs_csi_policy | Create EBS CSI Driver policy | `bool` | `true` | no |
| create_external_dns_policy | Create External DNS policy | `bool` | `true` | no |
| create_cluster_autoscaler_policy | Create Cluster Autoscaler policy | `bool` | `true` | no |
| create_aws_load_balancer_controller_policy | Create AWS LBC policy | `bool` | `true` | no |
| tags | Additional tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster_role_arn | ARN of the EKS cluster IAM role |
| cluster_role_name | Name of the EKS cluster IAM role |
| node_role_arn | ARN of the EKS node IAM role |
| node_role_name | Name of the EKS node IAM role |
| node_instance_profile_name | Name of the EC2 instance profile |
| oidc_provider_arn | ARN of the OIDC provider |
| oidc_provider_url | OIDC provider URL (without https://) |
| ebs_csi_policy_arn | ARN of EBS CSI Driver policy |
| external_dns_policy_arn | ARN of External DNS policy |
| cluster_autoscaler_policy_arn | ARN of Cluster Autoscaler policy |
| aws_load_balancer_controller_policy_arn | ARN of AWS LBC policy |

## IAM Policies Included

### 1. EBS CSI Driver
Allows the EBS CSI driver to:
- Create and delete EBS volumes
- Attach and detach volumes
- Create and delete snapshots
- Manage volume tags

### 2. External DNS
Allows External DNS to:
- Manage Route53 records
- List hosted zones
- Update DNS records

### 3. Cluster Autoscaler
Allows Cluster Autoscaler to:
- Describe Auto Scaling Groups
- Set desired capacity
- Terminate instances in ASG

### 4. AWS Load Balancer Controller
Allows AWS LBC to:
- Create and manage ALB/NLB
- Manage target groups
- Configure listeners and rules
- (Skeleton - full policy added later)

## Security Considerations

### EKS Cluster Role
- Used by EKS control plane only
- Cannot be assumed by users or applications
- Has minimal permissions for cluster management

### EKS Node Role
- Used by EC2 instances in node groups
- Has permissions for:
  - Joining the cluster
  - ECR image pulling
  - CNI networking
  - Optional SSM access

### OIDC Provider
- Enables fine-grained IAM permissions for pods
- Each service account can have unique IAM role
- Tokens are short-lived and automatically rotated
- Conditions enforce namespace and service account matching

### Best Practices
1. **Least Privilege**: Only grant permissions needed
2. **IRSA Over Node Roles**: Use IRSA for application permissions
3. **Separate Policies**: Don't attach application policies to node role
4. **Audit Regularly**: Review IAM roles and policies
5. **Enable CloudTrail**: Log all IAM API calls

## SSM Session Manager Access

When `enable_ssm_access = true`, nodes can be accessed via AWS Systems Manager:

```bash
# List nodes
aws ssm describe-instance-information --filters "Key=tag:eks:cluster-name,Values=my-cluster"

# Start session
aws ssm start-session --target i-1234567890abcdef0
```

Benefits:
- No SSH keys required
- Centralized access logging
- Session history in CloudWatch
- No need for bastion hosts

## Two-Phase Deployment

### Phase 1: Before EKS Cluster
```hcl
create_oidc_provider = false
```
Creates cluster and node roles only.

### Phase 2: After EKS Cluster
```hcl
create_oidc_provider = true
oidc_provider_url    = module.eks.cluster_oidc_issuer_url
```
Creates OIDC provider and IRSA policies.

## Troubleshooting

### Issue: OIDC provider creation fails

**Error**: `Error creating IAM OpenID Connect Provider: InvalidInput`

**Solution**: Ensure `oidc_provider_url` is correctly formatted:
```
https://oidc.eks.REGION.amazonaws.com/id/CLUSTER_ID
```

### Issue: Pods can't assume IAM role

**Checklist**:
1. OIDC provider created
2. Service account has correct annotation
3. Trust policy conditions match
4. IAM role has correct policy attached

**Debug**:
```bash
# Check service account
kubectl describe sa SERVICE_ACCOUNT -n NAMESPACE

# Check pod environment
kubectl exec POD -n NAMESPACE -- env | grep AWS
```

### Issue: Node can't join cluster

**Solution**: Verify node role has `AmazonEKSWorkerNodePolicy` attached:
```bash
aws iam list-attached-role-policies --role-name ROLE_NAME
```

## Examples

See `terraform/environments/dev/02-iam/` for a complete example.

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.6 |
| aws | ~> 5.0 |

## License

This module is part of the EKS GitOps infrastructure project.

## References

- [EKS IAM Roles](https://docs.aws.amazon.com/eks/latest/userguide/service_IAM_role.html)
- [IRSA](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
- [EBS CSI Driver](https://github.com/kubernetes-sigs/aws-ebs-csi-driver)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
