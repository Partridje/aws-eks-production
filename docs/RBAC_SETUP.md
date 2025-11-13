# EKS RBAC Setup Guide

## Overview

This guide explains how to set up role-based access control (RBAC) for your EKS cluster, allowing you to grant different levels of access to users and teams.

## Access Levels

We have three predefined access levels:

### 1. Admin (Full Access)
- Full cluster access (system:masters)
- Can do anything in any namespace
- Can manage cluster-level resources
- **Use for**: Platform team, SRE team

### 2. Developer (Namespace Scoped)
- Create/update/delete resources in assigned namespaces
- Read-only access to observability namespace
- Cannot modify cluster-level resources
- **Use for**: Application developers

### 3. Viewer (Read-Only)
- Read-only access across all namespaces
- Can view logs, metrics, events
- Cannot modify any resources
- **Use for**: QA team, support team, stakeholders

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     IAM Users/Roles                      │
│  ┌─────────┐  ┌──────────┐  ┌─────────┐                │
│  │  Admin  │  │Developer │  │ Viewer  │                │
│  │  Role   │  │   Role   │  │  Role   │                │
│  └────┬────┘  └─────┬────┘  └────┬────┘                │
└───────┼─────────────┼────────────┼──────────────────────┘
        │             │            │
        │ AWS IAM     │            │
        │ Assume Role │            │
        │             │            │
┌───────▼─────────────▼────────────▼──────────────────────┐
│              aws-auth ConfigMap                          │
│  Maps IAM identities to Kubernetes groups               │
│  - eks-prod-dev-admin-role    → system:masters         │
│  - eks-prod-dev-developer-role → developers            │
│  - eks-prod-dev-viewer-role    → viewers               │
└───────┬─────────────┬────────────┬──────────────────────┘
        │             │            │
┌───────▼─────────────▼────────────▼──────────────────────┐
│           Kubernetes RBAC (ClusterRoles)                 │
│  ┌─────────────┐  ┌──────────┐  ┌─────────┐            │
│  │system:masters│  │developer │  │ viewer  │            │
│  │(built-in)   │  │(custom)  │  │(custom) │            │
│  └─────────────┘  └──────────┘  └─────────┘            │
└──────────────────────────────────────────────────────────┘
```

## Setup Steps

### Step 1: Deploy Terraform (Creates IAM Roles)

```bash
cd terraform/environments/dev
terraform apply
```

This creates:
- `eks-prod-dev-admin-role`
- `eks-prod-dev-developer-role`
- `eks-prod-dev-viewer-role`

Save the role ARNs from outputs:
```bash
terraform output | grep role_arn
```

### Step 2: Configure aws-auth ConfigMap

The `aws-auth` ConfigMap maps IAM roles to Kubernetes RBAC groups.

**Edit the ConfigMap:**
```bash
# Get your AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Edit aws-auth-configmap.yaml
sed -i "s/ACCOUNT_ID/${AWS_ACCOUNT_ID}/g" kubernetes/infrastructure/aws-auth-configmap.yaml
```

**Apply the ConfigMap:**
```bash
# Make sure you have admin access first
aws eks update-kubeconfig --region eu-west-1 --name eks-prod-dev

# Apply
kubectl apply -f kubernetes/infrastructure/aws-auth-configmap.yaml
```

**Verify:**
```bash
kubectl get configmap aws-auth -n kube-system -o yaml
```

### Step 3: Apply Kubernetes RBAC Roles

```bash
# Apply developer role
kubectl apply -f kubernetes/security/rbac/developer-role.yaml

# Apply viewer role
kubectl apply -f kubernetes/security/rbac/viewer-role.yaml

# Verify
kubectl get clusterroles | grep -E "developer|viewer"
kubectl get clusterrolebindings | grep -E "developer|viewer"
```

### Step 4: Grant Access to Users

#### Option A: Add IAM Users (Recommended for small teams)

Edit `kubernetes/infrastructure/aws-auth-configmap.yaml` and add users:

```yaml
mapUsers: |
  - userarn: arn:aws:iam::123456789012:user/alice
    username: alice
    groups:
      - system:masters

  - userarn: arn:aws:iam::123456789012:user/bob
    username: bob
    groups:
      - developers

  - userarn: arn:aws:iam::123456789012:user/charlie
    username: charlie
    groups:
      - viewers
```

Apply changes:
```bash
kubectl apply -f kubernetes/infrastructure/aws-auth-configmap.yaml
```

#### Option B: Use IAM Roles (Recommended for production)

Users assume the appropriate IAM role:

**1. Create IAM policy for assuming roles:**

```bash
cat > /tmp/eks-assume-role-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": [
        "arn:aws:iam::${AWS_ACCOUNT_ID}:role/eks-prod-dev-admin-role",
        "arn:aws:iam::${AWS_ACCOUNT_ID}:role/eks-prod-dev-developer-role",
        "arn:aws:iam::${AWS_ACCOUNT_ID}:role/eks-prod-dev-viewer-role"
      ]
    }
  ]
}
EOF

aws iam create-policy \
  --policy-name EKSAssumeRolePolicy \
  --policy-document file:///tmp/eks-assume-role-policy.json
```

**2. Attach policy to users/groups:**
```bash
# For specific user
aws iam attach-user-policy \
  --user-name alice \
  --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/EKSAssumeRolePolicy

# Or for a group
aws iam attach-group-policy \
  --group-name developers \
  --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/EKSAssumeRolePolicy
```

## User Workflows

### As an Admin

```bash
# Assume admin role
aws sts assume-role \
  --role-arn arn:aws:iam::ACCOUNT_ID:role/eks-prod-dev-admin-role \
  --role-session-name admin-session \
  --external-id eks-prod-dev-admin

# Configure AWS credentials with temporary credentials
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_SESSION_TOKEN=...

# Update kubeconfig
aws eks update-kubeconfig --region eu-west-1 --name eks-prod-dev

# Verify access
kubectl auth can-i "*" "*"  # Should return "yes"
```

### As a Developer

```bash
# Assume developer role
aws sts assume-role \
  --role-arn arn:aws:iam::ACCOUNT_ID:role/eks-prod-dev-developer-role \
  --role-session-name dev-session \
  --external-id eks-prod-dev-developer

# Configure credentials and update kubeconfig
# ... (same as admin)

# Verify access
kubectl auth can-i create deployment -n default  # yes
kubectl auth can-i delete namespace              # no
kubectl auth can-i get pods -n kube-system       # no
```

### As a Viewer

```bash
# Assume viewer role
aws sts assume-role \
  --role-arn arn:aws:iam::ACCOUNT_ID:role/eks-prod-dev-viewer-role \
  --role-session-name viewer-session \
  --external-id eks-prod-dev-viewer

# Configure credentials and update kubeconfig
# ... (same as admin)

# Verify access
kubectl auth can-i get pods                     # yes
kubectl auth can-i create deployment            # no
kubectl auth can-i delete pod                   # no
```

## Helper Scripts

Create helper scripts for easy role assumption:

```bash
# ~/.aws-eks-roles.sh

eks-admin() {
    export AWS_PROFILE=default
    CREDS=$(aws sts assume-role \
        --role-arn arn:aws:iam::ACCOUNT_ID:role/eks-prod-dev-admin-role \
        --role-session-name admin-$(date +%s) \
        --external-id eks-prod-dev-admin \
        --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
        --output text)

    export AWS_ACCESS_KEY_ID=$(echo $CREDS | awk '{print $1}')
    export AWS_SECRET_ACCESS_KEY=$(echo $CREDS | awk '{print $2}')
    export AWS_SESSION_TOKEN=$(echo $CREDS | awk '{print $3}')

    aws eks update-kubeconfig --region eu-west-1 --name eks-prod-dev
    echo "✅ Assumed EKS Admin role"
}

eks-developer() {
    # Similar to eks-admin but with developer role
    ...
}

eks-viewer() {
    # Similar to eks-admin but with viewer role
    ...
}

# Source this file: source ~/.aws-eks-roles.sh
# Then use: eks-admin, eks-developer, eks-viewer
```

## AWS SSO Integration (Optional)

If using AWS SSO, you can map SSO roles directly:

**1. Enable AWS SSO in your account**

**2. Create SSO permission sets:**
- EKS-Admin
- EKS-Developer
- EKS-Viewer

**3. Update aws-auth ConfigMap:**

```yaml
mapRoles: |
  # SSO Admin role
  - rolearn: arn:aws:iam::ACCOUNT_ID:role/aws-reserved/sso.amazonaws.com/eu-west-1/AWSReservedSSO_EKS-Admin_xxxxx
    username: sso-admin:{{SessionName}}
    groups:
      - system:masters

  # SSO Developer role
  - rolearn: arn:aws:iam::ACCOUNT_ID:role/aws-reserved/sso.amazonaws.com/eu-west-1/AWSReservedSSO_EKS-Developer_xxxxx
    username: sso-dev:{{SessionName}}
    groups:
      - developers
```

**4. Users login via SSO:**
```bash
aws sso login --profile eks-admin
aws eks update-kubeconfig --region eu-west-1 --name eks-prod-dev --profile eks-admin
```

## OIDC for External IdP (Advanced)

For integrating with external identity providers (Okta, Azure AD, etc.):

### Option 1: AWS IAM Identity Center + EKS

Use AWS IAM Identity Center (formerly AWS SSO) as described above.

### Option 2: OIDC Connector

Deploy an OIDC connector in the cluster:

```bash
# Install gangway or dex
helm repo add dexidp https://charts.dexidp.io
helm install dex dexidp/dex -f dex-values.yaml
```

Configure your IdP to authenticate users, then map them to Kubernetes groups.

## Testing Access

### Test Admin Access
```bash
kubectl auth can-i "*" "*" --all-namespaces  # yes
kubectl create namespace test-admin          # succeeds
kubectl delete namespace test-admin          # succeeds
```

### Test Developer Access
```bash
kubectl auth can-i create deployment -n default       # yes
kubectl auth can-i create deployment -n kube-system   # no
kubectl auth can-i get pods -n observability          # yes
kubectl auth can-i delete pods -n observability       # no
```

### Test Viewer Access
```bash
kubectl auth can-i get pods                  # yes
kubectl auth can-i create deployment         # no
kubectl auth can-i delete anything           # no
```

## Troubleshooting

### Issue: "error: You must be logged in to the server (Unauthorized)"

**Solution:**
1. Check aws-auth ConfigMap is applied:
   ```bash
   kubectl get configmap aws-auth -n kube-system
   ```

2. Verify your IAM identity:
   ```bash
   aws sts get-caller-identity
   ```

3. Check if your IAM role/user is in aws-auth:
   ```bash
   kubectl get configmap aws-auth -n kube-system -o yaml | grep -A5 mapRoles
   ```

### Issue: "User cannot assume role"

**Solution:**
Check the trust policy on the IAM role allows your user to assume it.

### Issue: "Forbidden: User cannot perform action"

**Solution:**
Check RBAC permissions:
```bash
kubectl auth can-i <verb> <resource> -n <namespace>
kubectl describe clusterrole <role-name>
```

## Security Best Practices

✅ **Use IAM roles, not IAM users** - Easier to manage and rotate
✅ **Require MFA** for role assumption in production
✅ **Audit access** - Enable CloudTrail and review EKS API calls
✅ **Least privilege** - Only grant minimum required permissions
✅ **Namespace isolation** - Use namespaces to separate environments
✅ **Regular review** - Audit aws-auth ConfigMap regularly
✅ **Use AWS SSO** - For centralized user management

## Next Steps

1. ✅ Apply RBAC configuration
2. ✅ Grant access to team members
3. ✅ Test access levels
4. Set up audit logging (see [AUDIT.md](AUDIT.md))
5. Configure Pod Security Standards
6. Implement Network Policies

## Additional Resources

- [EKS User Guide - Managing Users](https://docs.aws.amazon.com/eks/latest/userguide/add-user-role.html)
- [Kubernetes RBAC Documentation](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
