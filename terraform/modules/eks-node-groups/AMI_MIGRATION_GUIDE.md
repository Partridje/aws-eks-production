# Amazon Linux 2023 Migration Guide

## Overview

This guide explains how to migrate EKS node groups from Amazon Linux 2 (AL2) to Amazon Linux 2023 (AL2023).

## Why Migrate to AL2023?

Amazon Linux 2023 provides:
- ✅ **Extended support**: AL2023 has support until 2028 (vs AL2 until June 2025)
- ✅ **Modern kernel**: Linux kernel 6.1 with better performance and security
- ✅ **SELinux enabled**: Enhanced security by default
- ✅ **Deterministic updates**: Lockstep releases every 2 years
- ✅ **Better package management**: DNF instead of YUM
- ✅ **Improved performance**: 10-20% better performance in many workloads

## Important Considerations

⚠️ **Breaking Change**: Migrating from AL2 to AL2023 will **recreate all nodes** in the node group.

### Prerequisites

1. **Backup your workloads** - ensure critical data is backed up
2. **Test in dev/staging** - validate your applications work on AL2023
3. **Check pod disruption budgets** - ensure PDBs are configured
4. **Review application compatibility** - some older apps may need updates

### Differences Between AL2 and AL2023

| Feature | AL2 | AL2023 |
|---------|-----|--------|
| Kernel | 5.10 | 6.1 |
| Package Manager | YUM | DNF |
| SELinux | Disabled by default | Enabled by default |
| Support End | June 2025 | 2028 |
| Python Default | 2.7 / 3.7 | 3.9 |
| systemd | 219 | 252 |

## Migration Steps

### Step 1: Test in Development Environment

Update your dev environment variables in `terraform/environments/dev/04-node-groups/terraform.tfvars`:

```hcl
# System nodes - migrate first (lower risk)
system_ami_type = "AL2023_x86_64_STANDARD"

# App nodes - migrate after system nodes are stable
app_ami_type = "AL2023_x86_64_STANDARD"
```

### Step 2: Plan and Review

```bash
cd terraform/environments/dev/04-node-groups
terraform plan
```

Look for:
- `# aws_eks_node_group.system will be replaced`
- `# aws_eks_node_group.app will be replaced`

### Step 3: Apply with Rolling Update

**Option A: Manual Rolling Update (Recommended for Production)**

```bash
# Step 1: Increase max_size temporarily to allow new nodes
# Edit terraform.tfvars:
system_max_size = 4  # If currently 2, double it
app_max_size = 20    # If currently 10, double it

terraform apply

# Step 2: Change AMI type for system nodes only
system_ami_type = "AL2023_x86_64_STANDARD"

terraform apply

# Wait for new nodes to join and old nodes to drain
kubectl get nodes -w

# Step 3: Once system nodes are stable, update app nodes
app_ami_type = "AL2023_x86_64_STANDARD"

terraform apply

# Step 4: Restore original max_size
system_max_size = 2
app_max_size = 10

terraform apply
```

**Option B: Direct Update (Acceptable for Dev/Test)**

```bash
# Update both node groups at once
terraform apply
```

### Step 4: Verify Migration

```bash
# Check node OS version
kubectl get nodes -o wide

# Check node labels
kubectl get nodes -L eks.amazonaws.com/nodegroup -L kubernetes.io/os

# Verify pods are running
kubectl get pods --all-namespaces

# Check for any pod scheduling issues
kubectl get events --all-namespaces --field-selector type=Warning
```

## Variable Configuration

The module now supports `ami_type` variables:

```hcl
# terraform/modules/eks-node-groups/variables.tf

variable "system_ami_type" {
  description = "AMI type for system node group"
  type        = string
  default     = "AL2_x86_64"  # Conservative default
}

variable "app_ami_type" {
  description = "AMI type for application node group"
  type        = string
  default     = "AL2_x86_64"  # Conservative default
}
```

### Available AMI Types

- `AL2_x86_64` - Amazon Linux 2 x86_64
- `AL2023_x86_64_STANDARD` - Amazon Linux 2023 x86_64 ⭐ Recommended
- `AL2_x86_64_GPU` - Amazon Linux 2 with GPU support
- `AL2023_x86_64_NVIDIA` - Amazon Linux 2023 with NVIDIA GPU
- `AL2_ARM_64` - Amazon Linux 2 ARM64 (Graviton)
- `AL2023_ARM_64_STANDARD` - Amazon Linux 2023 ARM64 (Graviton)

## Rollback Plan

If you encounter issues with AL2023:

```hcl
# Revert to AL2
system_ami_type = "AL2_x86_64"
app_ami_type = "AL2_x86_64"

terraform apply
```

This will recreate nodes with AL2.

## Common Issues and Solutions

### Issue: SELinux blocking pods

**Solution**: Add SELinux context to pod security context:

```yaml
securityContext:
  seLinuxOptions:
    level: "s0:c123,c456"
```

### Issue: Package not found

**Solution**: AL2023 uses DNF instead of YUM. Update installation scripts:

```bash
# AL2
yum install -y package-name

# AL2023
dnf install -y package-name
```

### Issue: Python version mismatch

**Solution**: AL2023 uses Python 3.9 by default. Update scripts:

```bash
# Explicitly use Python 3.9
python3.9 -m pip install package
```

## Best Practices

1. ✅ **Test thoroughly in dev/staging first**
2. ✅ **Use Pod Disruption Budgets** to prevent service interruptions
3. ✅ **Monitor node health** during and after migration
4. ✅ **Update node groups one at a time** (system first, then app)
5. ✅ **Keep max_size flexible** during migration for rolling updates
6. ✅ **Have a rollback plan** ready

## Timeline Recommendation

- **Development**: Migrate immediately to gain experience
- **Staging**: Migrate within 1-2 weeks after dev validation
- **Production**: Migrate within 1-3 months after staging validation
- **Deadline**: Before June 2025 (AL2 end of support)

## References

- [Amazon Linux 2023 Documentation](https://docs.aws.amazon.com/linux/al2023/)
- [EKS AMI Release Notes](https://github.com/awslabs/amazon-eks-ami/releases)
- [AL2023 Migration Guide](https://docs.aws.amazon.com/linux/al2023/ug/migration-overview.html)
- [AL2 End of Support Timeline](https://aws.amazon.com/amazon-linux-2/faqs/)
