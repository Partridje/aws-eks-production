# EKS Production Infrastructure - Improvements

This document contains improvements identified during code review against AWS EKS Best Practices.

**Review Date:** 2025-11-25
**Reviewed By:** Claude Code + AWS Documentation MCP
**Last Updated:** 2025-11-25

---

## Completed Improvements

| Task | Module | Status |
|------|--------|--------|
| Create EKS Add-ons module | `eks-addons` | DONE |
| Add VPC endpoints (eks, eks-auth, elb, ssm) | `vpc` | DONE |
| Make CNI policy conditional for IRSA | `iam-eks` | DONE |
| Enable all 5 log types + KMS encryption | `eks-cluster` | DONE |
| Add EKS Access Entries | `eks-cluster` | DONE |

### New Files Created:
- `terraform/modules/eks-addons/main.tf` - EKS managed add-ons (VPC CNI, CoreDNS, kube-proxy, EBS CSI, Pod Identity)
- `terraform/modules/eks-addons/variables.tf` - Add-ons configuration variables
- `terraform/modules/eks-addons/outputs.tf` - Add-ons outputs
- `terraform/modules/eks-cluster/access-entries.tf` - EKS Access Entries for API-based access management

### Files Modified:
- `terraform/modules/vpc/endpoints.tf` - Added 6 new VPC endpoints
- `terraform/modules/vpc/outputs.tf` - Added outputs for new endpoints
- `terraform/modules/iam-eks/node-role.tf` - Made CNI policy conditional
- `terraform/modules/iam-eks/oidc.tf` - Added IRSA roles for VPC CNI and EBS CSI
- `terraform/modules/iam-eks/variables.tf` - Added `use_vpc_cni_irsa` variable
- `terraform/modules/iam-eks/outputs.tf` - Added IRSA role outputs
- `terraform/modules/eks-cluster/main.tf` - Added `access_config` block
- `terraform/modules/eks-cluster/variables.tf` - Updated log defaults, added access entries vars
- `terraform/modules/eks-cluster/outputs.tf` - Added access entries outputs

---

## 1. VPC Module

### Current Status: 8/10

### Improvements Required

#### 1.1 Add Dedicated Cluster Subnets (/28)
**Priority:** Medium
**File:** `terraform/modules/vpc/main.tf`

AWS recommends dedicated small subnets (/28) for EKS control plane X-ENIs to avoid IP exhaustion during cluster upgrades.

```hcl
# Add dedicated cluster subnets for EKS X-ENIs
resource "aws_subnet" "cluster" {
  count = length(local.availability_zones)

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 12, count.index + 240)  # /28 subnets
  availability_zone = local.availability_zones[count.index]

  tags = merge(
    local.common_tags,
    local.eks_cluster_tag,
    {
      Name = "${var.project_name}-${var.environment}-cluster-${local.availability_zones[count.index]}"
      Type = "cluster"
    }
  )
}
```

**Reference:** https://docs.aws.amazon.com/eks/latest/best-practices/subnets.html

---

#### 1.2 Add Missing VPC Endpoints for Private Cluster
**Priority:** High (if using private cluster)
**File:** `terraform/modules/vpc/endpoints.tf`

Missing endpoints:
- `eks` - For EKS API access
- `eks-auth` - For Pod Identity
- `elasticloadbalancing` - For ALB/NLB
- `ssm`, `ssmmessages`, `ec2messages` - For SSM node management

```hcl
# EKS API Endpoint
resource "aws_vpc_endpoint" "eks" {
  count = var.enable_vpc_endpoints ? 1 : 0

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.eks"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-eks-endpoint"
  })
}

# EKS Auth Endpoint (for Pod Identity)
resource "aws_vpc_endpoint" "eks_auth" {
  count = var.enable_vpc_endpoints ? 1 : 0

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.eks-auth"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-eks-auth-endpoint"
  })
}

# Elastic Load Balancing Endpoint
resource "aws_vpc_endpoint" "elasticloadbalancing" {
  count = var.enable_vpc_endpoints ? 1 : 0

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.elasticloadbalancing"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-elb-endpoint"
  })
}

# SSM Endpoints (for node management without SSH)
resource "aws_vpc_endpoint" "ssm" {
  count = var.enable_vpc_endpoints ? 1 : 0

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-ssm-endpoint"
  })
}
```

**Reference:** https://docs.aws.amazon.com/eks/latest/userguide/private-clusters.html

---

## 2. EKS Cluster Module

### Current Status: 9/10

### What's Good

- KMS encryption for secrets at rest
- KMS key rotation enabled
- OIDC provider for IRSA (IAM Roles for Service Accounts)
- Private endpoint enabled by default
- Public endpoint disabled by default
- Secure defaults for public_access_cidrs (empty - must be explicitly set)
- CloudWatch log group with configurable retention
- Input validation on variables

### Improvements Required

#### 2.1 Enable All Control Plane Log Types
**Priority:** Medium
**File:** `terraform/modules/eks-cluster/variables.tf`

Current default enables only 3 of 5 log types. For production, all 5 should be enabled for complete audit trail.

```hcl
variable "enabled_log_types" {
  description = "List of control plane logging types to enable"
  type        = list(string)
  # CHANGED: Enable all 5 log types for production
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  validation {
    condition = alltrue([
      for log_type in var.enabled_log_types :
      contains(["api", "audit", "authenticator", "controllerManager", "scheduler"], log_type)
    ])
    error_message = "Log types must be one of: api, audit, authenticator, controllerManager, scheduler."
  }
}
```

**Reference:** https://docs.aws.amazon.com/eks/latest/best-practices/auditing-and-logging.html

---

#### 2.2 Increase Default Log Retention for Production
**Priority:** Medium
**File:** `terraform/modules/eks-cluster/variables.tf`

7 days is too short for production audit requirements. Recommend 90 days minimum.

```hcl
variable "log_retention_days" {
  description = "Number of days to retain EKS cluster logs"
  type        = number
  # CHANGED: 90 days for production compliance
  default     = 90

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch Logs retention period."
  }
}
```

---

#### 2.3 Enable Log Encryption by Default
**Priority:** High
**File:** `terraform/modules/eks-cluster/variables.tf`

For production security, CloudWatch logs should be encrypted with KMS.

```hcl
variable "encrypt_logs" {
  description = "Encrypt CloudWatch logs with KMS"
  type        = bool
  # CHANGED: Enable encryption by default for production
  default     = true
}
```

---

#### 2.4 Add EKS Access Entries Support
**Priority:** Medium
**File:** `terraform/modules/eks-cluster/main.tf`

EKS now supports Access Entries as a more secure alternative to aws-auth ConfigMap.

```hcl
# Add to aws_eks_cluster resource
resource "aws_eks_cluster" "main" {
  # ... existing config ...

  # Access configuration (new in AWS provider 5.x+)
  access_config {
    authentication_mode                         = var.authentication_mode
    bootstrap_cluster_creator_admin_permissions = var.bootstrap_cluster_creator_admin_permissions
  }
}

# Add to variables.tf
variable "authentication_mode" {
  description = "Authentication mode for the cluster. Valid values: API, API_AND_CONFIG_MAP, CONFIG_MAP"
  type        = string
  default     = "API_AND_CONFIG_MAP"
}

variable "bootstrap_cluster_creator_admin_permissions" {
  description = "Whether to bootstrap cluster creator with admin permissions"
  type        = bool
  default     = true
}
```

**Reference:** https://docs.aws.amazon.com/eks/latest/userguide/access-entries.html

---

#### 2.5 Add Cluster Security Group Rules for Node Communication
**Priority:** Low
**File:** `terraform/modules/eks-cluster/security-groups.tf`

Consider adding explicit rules for node-to-control-plane communication.

```hcl
# Allow nodes to communicate with control plane
resource "aws_security_group_rule" "cluster_ingress_nodes" {
  count = var.create_cluster_security_group && var.node_security_group_id != "" ? 1 : 0

  security_group_id        = aws_security_group.cluster[0].id
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = var.node_security_group_id
  description              = "Allow nodes to communicate with control plane"
}
```

---

## 3. EKS Node Groups Module

### Current Status: 9.5/10

### What's Good

- Separation of concerns: system vs app node groups
- System nodes with `CriticalAddonsOnly` taint
- On-Demand for system nodes, Spot option for app nodes
- IMDSv2 enforced (`http_tokens = "required"`)
- EBS encryption enabled
- GP3 volumes with optimized IOPS/throughput
- Node repair config (AWS Provider 6.0+)
- Cluster Autoscaler tags properly configured
- `ignore_changes` for desired_size (Cluster Autoscaler compatibility)
- Launch templates with proper security settings
- Detailed monitoring enabled
- Strong input validation

### Improvements Required

#### 3.1 Consider AL2023 as Default AMI for New Clusters
**Priority:** Low
**File:** `terraform/modules/eks-node-groups/variables.tf`

AL2023 is the recommended AMI for new clusters with better security defaults.

```hcl
variable "system_ami_type" {
  # ...
  # RECOMMENDATION: For new clusters, consider AL2023
  default     = "AL2023_x86_64_STANDARD"
}

variable "app_ami_type" {
  # ...
  # RECOMMENDATION: For new clusters, consider AL2023
  default     = "AL2023_x86_64_STANDARD"
}
```

**Note:** Keep AL2 default for compatibility. Document AL2023 as recommended for new clusters.

---

#### 3.2 Consider Non-Burstable Instance Types for Production
**Priority:** Low
**File:** `terraform/modules/eks-node-groups/variables.tf`

t3.medium/t3.large are burstable instances. For production workloads, consider m5/m6i/m7i.

```hcl
variable "system_instance_types" {
  description = "Instance types for system node group"
  type        = list(string)
  # RECOMMENDATION: Use non-burstable for production
  # default     = ["m6i.large"]  # Production
  default     = ["t3.medium"]    # Dev/Test (current)
}
```

**Reference:** https://docs.aws.amazon.com/eks/latest/best-practices/reliability.html

---

#### 3.3 Add KMS Key Option for EBS Encryption
**Priority:** Low
**File:** `terraform/modules/eks-node-groups/launch-template.tf`

Currently uses AWS managed key. For compliance, add option for customer-managed KMS key.

```hcl
# Add to variables.tf
variable "ebs_kms_key_id" {
  description = "KMS key ID for EBS volume encryption. If not specified, uses AWS managed key."
  type        = string
  default     = null
}

# Update launch-template.tf
block_device_mappings {
  device_name = "/dev/xvda"

  ebs {
    volume_size           = var.system_node_disk_size
    volume_type           = "gp3"
    iops                  = 3000
    throughput            = 125
    encrypted             = true
    kms_key_id            = var.ebs_kms_key_id  # Add this line
    delete_on_termination = true
  }
}
```

---

#### 3.4 Add Bottlerocket AMI Support
**Priority:** Low
**File:** `terraform/modules/eks-node-groups/variables.tf`

Bottlerocket is a security-focused container OS from AWS.

```hcl
# Add to validation in ami_type variables
validation {
  condition = contains([
    "AL2_x86_64",
    "AL2023_x86_64_STANDARD",
    "BOTTLEROCKET_x86_64",        # Add
    "BOTTLEROCKET_ARM_64",         # Add
    # ... other types
  ], var.system_ami_type)
}
```

**Reference:** https://docs.aws.amazon.com/eks/latest/userguide/eks-optimized-ami-bottlerocket.html

---

## 4. IAM EKS Module

### Current Status: 8.5/10

### What's Good

- Cluster role with proper trust policy
- Node role with required AWS managed policies
- OIDC provider for IRSA
- Pre-built IRSA policies for common add-ons (EBS CSI, External DNS, Cluster Autoscaler)
- SSM access option for node management
- Strong input validation
- Instance profile for nodes

### Improvements Required

#### 4.1 Use IRSA for VPC CNI Instead of Node Role
**Priority:** High
**File:** `terraform/modules/iam-eks/node-role.tf`

Attaching `AmazonEKS_CNI_Policy` to node role is a security anti-pattern. Use IRSA for VPC CNI add-on instead.

```hcl
# REMOVE this attachment (or make it conditional)
resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  count = var.attach_cni_policy_to_node_role ? 1 : 0  # Make conditional

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node.name
}

# Add variable
variable "attach_cni_policy_to_node_role" {
  description = <<-EOT
    Attach CNI policy to node role. Set to false when using IRSA for VPC CNI.

    **Best Practice:** Use IRSA for VPC CNI add-on instead of attaching to node role.
    This provides better security isolation.
  EOT
  type        = bool
  default     = true  # For backward compatibility
}
```

**Reference:** https://docs.aws.amazon.com/eks/latest/userguide/cni-iam-role.html

---

#### 4.2 Restrict EBS CSI Policy Resources
**Priority:** Medium
**File:** `terraform/modules/iam-eks/policies.tf`

Current policy uses `resources = ["*"]`. Can be scoped to cluster-tagged resources.

```hcl
statement {
  sid    = "EBSCSICreateVolume"
  effect = "Allow"

  actions = [
    "ec2:CreateVolume",
    # ...
  ]

  resources = ["*"]

  # Add condition to scope to cluster-tagged resources
  condition {
    test     = "StringEquals"
    variable = "aws:RequestTag/kubernetes.io/cluster/${var.cluster_name}"
    values   = ["owned", "shared"]
  }
}
```

---

#### 4.3 Complete AWS Load Balancer Controller Policy
**Priority:** High
**File:** `terraform/modules/iam-eks/policies.tf`

Current policy is a skeleton. Replace with full official policy.

```hcl
# Option 1: Use AWS managed policy (recommended)
resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  count = var.create_aws_load_balancer_controller_role ? 1 : 0

  policy_arn = "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
  role       = aws_iam_role.aws_load_balancer_controller[0].name
}

# Option 2: Download and use official policy from:
# https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
```

---

#### 4.4 Add Permissions Boundary Support
**Priority:** Low
**File:** `terraform/modules/iam-eks/variables.tf`

For enterprise environments with IAM guardrails.

```hcl
variable "permissions_boundary" {
  description = "ARN of the permissions boundary policy to attach to all roles"
  type        = string
  default     = null
}

# Apply to roles
resource "aws_iam_role" "cluster" {
  name                 = "${var.cluster_name}-cluster-role"
  assume_role_policy   = data.aws_iam_policy_document.cluster_assume_role.json
  permissions_boundary = var.permissions_boundary  # Add this
  # ...
}
```

---

#### 4.5 Add CloudWatch Container Insights Policy
**Priority:** Medium
**File:** `terraform/modules/iam-eks/policies.tf`

For CloudWatch Container Insights observability.

```hcl
resource "aws_iam_policy" "cloudwatch_agent" {
  count = var.create_cloudwatch_agent_policy ? 1 : 0

  name        = "${var.cluster_name}-cloudwatch-agent-policy"
  description = "Policy for CloudWatch Container Insights"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      }
    ]
  })
}
```

---

## 5. Missing Components

### What's Missing from the Project

#### 5.1 EKS Add-ons Module
**Priority:** High
**Status:** NOT IMPLEMENTED

The project lacks Terraform management for EKS managed add-ons. These should be managed via Terraform for consistency:

```hcl
# terraform/modules/eks-addons/main.tf

# VPC CNI Add-on
resource "aws_eks_addon" "vpc_cni" {
  cluster_name             = var.cluster_name
  addon_name               = "vpc-cni"
  addon_version            = var.vpc_cni_version
  service_account_role_arn = var.vpc_cni_role_arn  # IRSA role
  resolve_conflicts_on_update = "OVERWRITE"

  configuration_values = jsonencode({
    enableNetworkPolicy = "true"
  })
}

# CoreDNS Add-on
resource "aws_eks_addon" "coredns" {
  cluster_name      = var.cluster_name
  addon_name        = "coredns"
  addon_version     = var.coredns_version
  resolve_conflicts_on_update = "OVERWRITE"
}

# kube-proxy Add-on
resource "aws_eks_addon" "kube_proxy" {
  cluster_name      = var.cluster_name
  addon_name        = "kube-proxy"
  addon_version     = var.kube_proxy_version
  resolve_conflicts_on_update = "OVERWRITE"
}

# EBS CSI Driver Add-on
resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name             = var.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = var.ebs_csi_version
  service_account_role_arn = var.ebs_csi_role_arn  # IRSA role
  resolve_conflicts_on_update = "OVERWRITE"
}

# Pod Identity Agent (required for Pod Identity)
resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name      = var.cluster_name
  addon_name        = "eks-pod-identity-agent"
  addon_version     = var.pod_identity_agent_version
  resolve_conflicts_on_update = "OVERWRITE"
}
```

**Reference:** https://docs.aws.amazon.com/eks/latest/userguide/eks-add-ons.html

---

#### 5.2 EKS Pod Identity Support
**Priority:** Medium
**Status:** NOT IMPLEMENTED

Pod Identity is AWS's new recommended way to grant AWS permissions to Pods (simpler than IRSA).

```hcl
# terraform/modules/eks-pod-identity/main.tf

# Pod Identity Association for EBS CSI Driver
resource "aws_eks_pod_identity_association" "ebs_csi" {
  cluster_name    = var.cluster_name
  namespace       = "kube-system"
  service_account = "ebs-csi-controller-sa"
  role_arn        = aws_iam_role.ebs_csi.arn
}

# IAM Role for Pod Identity (simpler trust policy than IRSA)
resource "aws_iam_role" "ebs_csi" {
  name = "${var.cluster_name}-ebs-csi-pod-identity"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "pods.eks.amazonaws.com"
      }
      Action = [
        "sts:AssumeRole",
        "sts:TagSession"
      ]
    }]
  })
}
```

**Reference:** https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html

---

#### 5.3 Cluster Upgrade Runbook
**Priority:** Medium
**Status:** NOT DOCUMENTED

Create upgrade documentation and consider Terraform variables for version pinning.

```hcl
# Add to variables for version pinning
variable "cluster_version" {
  description = "Kubernetes version - should be updated during planned upgrades"
  type        = string
  default     = "1.31"

  validation {
    # Update this list as new versions are released
    condition     = contains(["1.29", "1.30", "1.31"], var.cluster_version)
    error_message = "Supported versions: 1.29, 1.30, 1.31"
  }
}

variable "addon_versions" {
  description = "Add-on versions - should match cluster version"
  type = object({
    vpc_cni    = string
    coredns    = string
    kube_proxy = string
    ebs_csi    = string
  })
  default = {
    vpc_cni    = "v1.18.5-eksbuild.1"
    coredns    = "v1.11.3-eksbuild.1"
    kube_proxy = "v1.31.2-eksbuild.3"
    ebs_csi    = "v1.36.0-eksbuild.1"
  }
}
```

**Reference:** https://docs.aws.amazon.com/eks/latest/best-practices/cluster-upgrades.html

---

#### 5.4 Karpenter Support (Alternative to Cluster Autoscaler)
**Priority:** Low
**Status:** NOT IMPLEMENTED

Karpenter is AWS's recommended autoscaler for new EKS clusters.

```hcl
# Consider adding Karpenter module for more efficient autoscaling
# Karpenter provides:
# - Faster node provisioning (seconds vs minutes)
# - Right-sizing based on pending pods
# - Consolidation to reduce costs
# - Native spot instance support
```

**Reference:** https://karpenter.sh/

---

#### 5.5 Network Policy Support
**Priority:** Medium
**Status:** NOT CONFIGURED

VPC CNI supports native network policies - should be enabled.

```hcl
# In eks-addons module, enable network policy in VPC CNI
configuration_values = jsonencode({
  enableNetworkPolicy = "true"
})
```

**Reference:** https://docs.aws.amazon.com/eks/latest/userguide/cni-network-policy.html

---

## Summary

| Module | Status | High Priority | Medium Priority | Low Priority |
|--------|--------|---------------|-----------------|--------------|
| **VPC** | 8/10 | VPC endpoints (eks, eks-auth, elb, ssm) | Dedicated cluster subnets (/28) | - |
| **EKS Cluster** | 9/10 | Enable log encryption | All 5 log types, 90 day retention, Access Entries | Security group rules |
| **Node Groups** | 9.5/10 | - | - | AL2023 AMI, non-burstable instances, KMS for EBS |
| **IAM EKS** | 8.5/10 | IRSA for VPC CNI, Complete ALB Controller policy | Restrict EBS CSI resources, Container Insights policy | Permissions boundary |
| **Missing** | 0/10 | **EKS Add-ons module** | Pod Identity, Network Policy, Upgrade runbook | Karpenter |

### Overall Assessment: **8/10** (was 8.75, adjusted for missing components)

This is a well-architected production-ready EKS infrastructure. The code follows most AWS best practices with:
- Proper separation of concerns (modules)
- Security-first defaults (private endpoints, IMDSv2, encryption)
- High availability design (multi-AZ, node groups)
- Good observability foundation (logging, monitoring)

### Priority Action Items

**High Priority (Critical for Production):**
1. **Create EKS Add-ons module** - Manage CoreDNS, kube-proxy, VPC CNI, EBS CSI via Terraform
2. Add missing VPC endpoints for private cluster support
3. Use IRSA for VPC CNI instead of node role attachment
4. Complete AWS Load Balancer Controller IAM policy
5. Enable CloudWatch log encryption by default

**Medium Priority (Production Readiness):**
6. Enable all 5 control plane log types
7. Increase log retention to 90 days
8. Add EKS Access Entries support
9. Add dedicated cluster subnets (/28)
10. Add Pod Identity support (simpler than IRSA)
11. Enable Network Policy in VPC CNI
12. Create cluster upgrade runbook/documentation

**Low Priority (Nice to Have):**
13. AL2023 AMI as recommended default
14. Bottlerocket AMI support
15. Non-burstable instance type recommendations
16. Permissions boundary support
17. Karpenter as Cluster Autoscaler alternative

---

## References

- [AWS EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [EKS VPC and Subnet Considerations](https://docs.aws.amazon.com/eks/latest/best-practices/subnets.html)
- [Private Clusters](https://docs.aws.amazon.com/eks/latest/userguide/private-clusters.html)
- [EKS Security Best Practices](https://docs.aws.amazon.com/eks/latest/best-practices/security.html)
- [EKS Auditing and Logging](https://docs.aws.amazon.com/eks/latest/best-practices/auditing-and-logging.html)
- [IAM Roles for Service Accounts](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
- [VPC CNI IAM Role](https://docs.aws.amazon.com/eks/latest/userguide/cni-iam-role.html)
- [EKS Access Entries](https://docs.aws.amazon.com/eks/latest/userguide/access-entries.html)
- [EKS Add-ons](https://docs.aws.amazon.com/eks/latest/userguide/eks-add-ons.html)
- [EKS Pod Identity](https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html)
- [Cluster Upgrades Best Practices](https://docs.aws.amazon.com/eks/latest/best-practices/cluster-upgrades.html)
- [VPC CNI Network Policy](https://docs.aws.amazon.com/eks/latest/userguide/cni-network-policy.html)
- [Karpenter](https://karpenter.sh/)
- [EKS Reliability Best Practices](https://docs.aws.amazon.com/eks/latest/best-practices/reliability.html)
