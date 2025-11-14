## EKS Node Groups Module

Production-ready EKS managed node groups with system/application separation for optimal workload isolation and resource management.

## Architecture

This module creates two distinct node groups:

### System Node Group
- **Purpose**: Runs critical cluster add-ons and system components
- **Instance Type**: `t3.medium` (default)
- **Capacity**: ON_DEMAND only (high reliability)
- **Scaling**: 2-4 nodes (min-max)
- **Taints**: `CriticalAddonsOnly=true:NoSchedule`
- **Use Cases**:
  - CoreDNS
  - kube-proxy
  - AWS VPC CNI
  - EBS CSI Driver
  - Cluster Autoscaler
  - Metrics Server

### Application Node Group
- **Purpose**: Runs user application workloads
- **Instance Type**: `t3.large` (default)
- **Capacity**: ON_DEMAND or SPOT (configurable)
- **Scaling**: 2-10 nodes (min-max)
- **Taints**: None (accepts all pods)
- **Use Cases**:
  - Application deployments
  - Batch jobs
  - Microservices
  - Stateless workloads

## Features

### Security
- ✅ **EBS Encryption**: All volumes encrypted at rest
- ✅ **IMDSv2**: Enforced for enhanced security
- ✅ **Private Subnets**: Nodes deployed in private subnets only
- ✅ **Detailed Monitoring**: CloudWatch detailed monitoring enabled
- ✅ **Cluster Autoscaler Ready**: Tags configured for auto-scaling

### High Availability
- ✅ **Multi-AZ**: Nodes distributed across multiple availability zones
- ✅ **Rolling Updates**: Max 33% unavailable during updates
- ✅ **Create Before Destroy**: Zero-downtime node group updates
- ✅ **Min 2 Nodes**: System nodes always have HA configuration

### Cost Optimization
- ✅ **GP3 Volumes**: Latest generation EBS with better price/performance
- ✅ **Spot Instances**: Optional for application nodes (dev environments)
- ✅ **Rightsizing**: Separate sizing for system vs app workloads
- ✅ **Auto Scaling**: Dynamic scaling based on demand

## Resources Created

| Resource | Description | Count |
|----------|-------------|-------|
| Launch Template (System) | System node configuration | 1 |
| Launch Template (App) | Application node configuration | 1 |
| EKS Node Group (System) | Managed system node group | 1 |
| EKS Node Group (App) | Managed application node group | 1 |
| Auto Scaling Groups | Created by EKS | 2 |

**Total:** 4 primary resources (~10 minutes to create)

## Usage

### Basic Usage

```hcl
module "node_groups" {
  source = "../../modules/eks-node-groups"

  cluster_name       = "my-eks-cluster"
  node_role_arn      = module.iam_eks.node_role_arn
  private_subnet_ids = module.vpc.private_subnet_ids
  oidc_provider_arn  = module.eks_cluster.oidc_provider_arn
  oidc_provider_url  = module.eks_cluster.oidc_provider_url

  tags = {
    Environment = "dev"
  }
}
```

### Production Configuration

```hcl
module "node_groups" {
  source = "../../modules/eks-node-groups"

  cluster_name       = "prod-eks-cluster"
  node_role_arn      = module.iam_eks.node_role_arn
  private_subnet_ids = module.vpc.private_subnet_ids
  oidc_provider_arn  = module.eks_cluster.oidc_provider_arn
  oidc_provider_url  = module.eks_cluster.oidc_provider_url

  # System nodes - critical addons
  system_instance_types = ["t3.medium"]
  system_desired_size   = 3
  system_min_size       = 3
  system_max_size       = 5
  system_node_disk_size = 50

  # App nodes - user workloads
  app_instance_types = ["t3.xlarge", "t3a.xlarge"]
  app_capacity_type  = "ON_DEMAND"
  app_desired_size   = 5
  app_min_size       = 3
  app_max_size       = 20
  app_node_disk_size = 200

  tags = {
    Environment = "prod"
    CostCenter  = "engineering"
  }
}
```

### Development with Spot Instances

```hcl
module "node_groups" {
  source = "../../modules/eks-node-groups"

  cluster_name       = "dev-eks-cluster"
  node_role_arn      = module.iam_eks.node_role_arn
  private_subnet_ids = module.vpc.private_subnet_ids
  oidc_provider_arn  = module.eks_cluster.oidc_provider_arn
  oidc_provider_url  = module.eks_cluster.oidc_provider_url

  # Use SPOT for cost savings in dev
  app_capacity_type  = "SPOT"
  app_instance_types = ["t3.large", "t3a.large", "t2.large"]
  app_desired_size   = 2
  app_min_size       = 2
  app_max_size       = 6

  tags = {
    Environment = "dev"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| cluster_name | EKS cluster name | `string` | n/a | yes |
| node_role_arn | IAM role ARN for nodes | `string` | n/a | yes |
| private_subnet_ids | Private subnet IDs (min 2) | `list(string)` | n/a | yes |
| oidc_provider_arn | OIDC provider ARN for IRSA | `string` | n/a | yes |
| oidc_provider_url | OIDC provider URL for IRSA | `string` | n/a | yes |
| **System Node Group** |
| system_instance_types | Instance types for system nodes | `list(string)` | `["t3.medium"]` | no |
| system_desired_size | Desired node count | `number` | `2` | no |
| system_min_size | Minimum node count | `number` | `2` | no |
| system_max_size | Maximum node count | `number` | `4` | no |
| system_node_disk_size | Disk size in GB | `number` | `50` | no |
| **Application Node Group** |
| app_instance_types | Instance types for app nodes | `list(string)` | `["t3.large"]` | no |
| app_capacity_type | ON_DEMAND or SPOT | `string` | `"ON_DEMAND"` | no |
| app_desired_size | Desired node count | `number` | `2` | no |
| app_min_size | Minimum node count | `number` | `2` | no |
| app_max_size | Maximum node count | `number` | `10` | no |
| app_node_disk_size | Disk size in GB | `number` | `100` | no |
| tags | Additional tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| system_node_group_id | System node group ID |
| system_node_group_arn | System node group ARN |
| system_node_group_status | System node group status |
| system_asg_name | System Auto Scaling Group name |
| app_node_group_id | App node group ID |
| app_node_group_arn | App node group ARN |
| app_node_group_status | App node group status |
| app_asg_name | App Auto Scaling Group name |
| node_groups_summary | Summary of all node groups |

## Post-Deployment

### 1. Configure kubectl

```bash
aws eks update-kubeconfig --region us-east-1 --name my-cluster-name
```

### 2. Verify Nodes

```bash
# Check all nodes
kubectl get nodes

# Check nodes with labels
kubectl get nodes -L node.kubernetes.io/type,workload-type

# Should see:
# NAME                          STATUS   ROLES    AGE   VERSION   TYPE     WORKLOAD-TYPE
# ip-10-0-1-100.ec2.internal    Ready    <none>   5m    v1.31.0   system   system
# ip-10-0-1-101.ec2.internal    Ready    <none>   5m    v1.31.0   system   system
# ip-10-0-2-200.ec2.internal    Ready    <none>   5m    v1.31.0   app      app
# ip-10-0-2-201.ec2.internal    Ready    <none>   5m    v1.31.0   app      app
```

### 3. Verify Taints

```bash
# Check node taints
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints

# System nodes should have: CriticalAddonsOnly=true:NoSchedule
# App nodes should have: <none>
```

### 4. Verify Node Group Status

```bash
# Via Terraform
terraform output node_groups_summary

# Via AWS CLI
aws eks describe-nodegroup \
  --cluster-name my-cluster-name \
  --nodegroup-name my-cluster-name-system

aws eks describe-nodegroup \
  --cluster-name my-cluster-name \
  --nodegroup-name my-cluster-name-app
```

### 5. Test Pod Scheduling

```bash
# This pod should land on app nodes (no toleration)
kubectl run test-app --image=nginx

# This pod should land on system nodes (has toleration)
kubectl run test-system --image=nginx --overrides='
{
  "spec": {
    "tolerations": [{
      "key": "CriticalAddonsOnly",
      "operator": "Equal",
      "value": "true",
      "effect": "NoSchedule"
    }]
  }
}'

# Check where pods landed
kubectl get pods -o wide
```

## Taints and Tolerations

### System Node Taint

System nodes have this taint:
```yaml
taints:
  - key: CriticalAddonsOnly
    value: "true"
    effect: NoSchedule
```

### Toleration for System Pods

To schedule on system nodes, pods need:
```yaml
tolerations:
  - key: CriticalAddonsOnly
    operator: Equal
    value: "true"
    effect: NoSchedule
```

### Critical Add-ons

These add-ons automatically tolerate the system node taint:
- CoreDNS
- kube-proxy
- AWS VPC CNI
- EBS CSI Driver (if configured)
- Cluster Autoscaler (if configured)

## Scaling Considerations

### Manual Scaling

```bash
# Scale system nodes
aws eks update-nodegroup-config \
  --cluster-name my-cluster \
  --nodegroup-name my-cluster-system \
  --scaling-config desiredSize=3

# Scale app nodes
aws eks update-nodegroup-config \
  --cluster-name my-cluster \
  --nodegroup-name my-cluster-app \
  --scaling-config desiredSize=5
```

### Cluster Autoscaler

Node groups are tagged for Cluster Autoscaler:
- `k8s.io/cluster-autoscaler/enabled`
- `k8s.io/cluster-autoscaler/<cluster-name>`

Deploy Cluster Autoscaler to enable automatic scaling based on pod resource requests.

### Scaling Recommendations

| Environment | System Min/Max | App Min/Max |
|-------------|----------------|-------------|
| **Dev** | 2 / 3 | 2 / 6 |
| **Staging** | 2 / 4 | 3 / 10 |
| **Production** | 3 / 5 | 5 / 20 |

## Spot Instances

### When to Use Spot

✅ **Good for:**
- Development environments
- Non-critical batch jobs
- Stateless applications
- Fault-tolerant workloads

❌ **Avoid for:**
- Production critical workloads
- Stateful applications
- Long-running jobs
- Low interruption tolerance

### Spot Configuration

```hcl
app_capacity_type = "SPOT"
app_instance_types = [
  "t3.large",
  "t3a.large",  # Diversify for better availability
  "t2.large"
]
```

### Handling Spot Interruptions

1. Use multiple instance types for diversification
2. Deploy Pod Disruption Budgets (PDBs)
3. Implement graceful shutdown handlers
4. Use Cluster Autoscaler with mixed instances

## Instance Type Selection

### System Nodes

**Recommended:**
- `t3.medium` (2 vCPU, 4 GiB) - Small clusters
- `t3.large` (2 vCPU, 8 GiB) - Medium clusters
- `m5.large` (2 vCPU, 8 GiB) - Large clusters

**Requirements:**
- Minimum 2 vCPU
- Minimum 4 GiB memory
- Network performance: Up to 5 Gbps

### Application Nodes

**Recommended:**
- `t3.large` (2 vCPU, 8 GiB) - General purpose
- `t3.xlarge` (4 vCPU, 16 GiB) - Medium workloads
- `m5.xlarge` (4 vCPU, 16 GiB) - Production workloads
- `c5.xlarge` (4 vCPU, 8 GiB) - Compute-intensive

## Cost Optimization

### Development Environment

```hcl
# Minimal setup
system_desired_size = 2
app_desired_size = 2
app_capacity_type = "SPOT"
```

**Estimated cost:** ~$60-80/month (Spot) or ~$120-150/month (On-Demand)

### Production Environment

```hcl
# HA setup
system_desired_size = 3
app_desired_size = 5
app_capacity_type = "ON_DEMAND"
```

**Estimated cost:** ~$400-600/month (depending on instance types)

### Cost Savings Tips

1. **Use Spot for non-critical workloads**: 70-90% savings
2. **Rightsizing**: Monitor and adjust instance types
3. **Cluster Autoscaler**: Scale down when not needed
4. **Reserved Instances**: For predictable base capacity
5. **Savings Plans**: Commitment-based discounts

## Troubleshooting

### Nodes Not Joining Cluster

**Symptoms:** Nodes stuck in "NotReady" state

**Check:**
```bash
# Check node group status
aws eks describe-nodegroup \
  --cluster-name <cluster-name> \
  --nodegroup-name <node-group-name>

# Check kubelet logs on node
aws ssm start-session --target <instance-id>
sudo journalctl -u kubelet -n 50
```

**Common causes:**
- Incorrect IAM permissions
- Security group misconfiguration
- Subnet routing issues

### Pods Not Scheduling

**Symptoms:** Pods stuck in "Pending" state

**Check:**
```bash
kubectl describe pod <pod-name>
```

**Common causes:**
- Resource requests too high
- Missing tolerations for system nodes
- Node group at max capacity

### IMDSv2 Issues

**Symptoms:** Applications can't access instance metadata

**Solution:** Applications must use IMDSv2:
```bash
# IMDSv2 requires session token
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.6 |
| aws | ~> 5.0 |

## Dependencies

This module requires:
- VPC with private subnets
- IAM role for nodes (from IAM module)
- EKS cluster (from EKS cluster module)
- OIDC provider (from EKS cluster module)

## Examples

See `terraform/environments/dev/04-node-groups/` for a complete example.

## References

- [EKS Managed Node Groups](https://docs.aws.amazon.com/eks/latest/userguide/managed-node-groups.html)
- [EKS Best Practices - Scalability](https://aws.github.io/aws-eks-best-practices/scalability/)
- [Cluster Autoscaler](https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler)
- [EKS Optimized AMI](https://docs.aws.amazon.com/eks/latest/userguide/eks-optimized-ami.html)
