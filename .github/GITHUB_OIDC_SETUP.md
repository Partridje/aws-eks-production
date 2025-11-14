# GitHub Actions OIDC Setup for AWS

This guide explains how to configure GitHub Actions to authenticate with AWS using OpenID Connect (OIDC), eliminating the need to store long-lived AWS credentials as GitHub secrets.

## Why OIDC?

**Benefits:**
- ✅ **No long-lived credentials**: No AWS access keys stored in GitHub
- ✅ **Automatic rotation**: Temporary credentials that expire
- ✅ **Granular permissions**: Specific IAM role per repository/workflow
- ✅ **Audit trail**: CloudTrail logs show GitHub Actions identity
- ✅ **Better security**: Follows AWS IAM best practices

## Architecture

```
GitHub Actions Workflow
        ↓
    (OIDC Token)
        ↓
  AWS IAM OIDC Provider
        ↓
   IAM Role (Trust Policy)
        ↓
  Assume Role with Web Identity
        ↓
   Temporary AWS Credentials
```

## Setup Instructions

### Step 1: Create IAM OIDC Provider in AWS

Create the OIDC provider that trusts GitHub:

```bash
# Get GitHub's OIDC thumbprint
THUMBPRINT="6938fd4d98bab03faadb97b34396831e3780aea1"

# Create OIDC provider
aws iam create-open-id-connect-provider \
  --url "https://token.actions.githubusercontent.com" \
  --client-id-list "sts.amazonaws.com" \
  --thumbprint-list "$THUMBPRINT" \
  --tags Key=Name,Value=github-actions-oidc \
         Key=ManagedBy,Value=Manual \
         Key=Purpose,Value=GitHubActionsAuth
```

**Output:**
```json
{
  "OpenIDConnectProviderArn": "arn:aws:iam::851725636341:oidc-provider/token.actions.githubusercontent.com"
}
```

Save this ARN - you'll need it in the next step.

### Step 2: Create IAM Role for GitHub Actions

Create a Terraform configuration file for the GitHub Actions role:

**`terraform/github-oidc-role/main.tf`:**

```hcl
terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id

  # Your GitHub organization/username and repository
  github_org  = "Partridje"  # Change to your GitHub username/org
  github_repo = "aws-eks-production"  # Change to your repo name
}

###############################################################################
# IAM Role for GitHub Actions
###############################################################################

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::${local.account_id}:oidc-provider/token.actions.githubusercontent.com"]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      # Allow from main branch and pull requests
      values = [
        "repo:${local.github_org}/${local.github_repo}:ref:refs/heads/main",
        "repo:${local.github_org}/${local.github_repo}:pull_request"
      ]
    }
  }
}

resource "aws_iam_role" "github_actions_terraform" {
  name               = "github-actions-terraform"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json
  description        = "IAM role for GitHub Actions to manage Terraform infrastructure"

  tags = {
    Name       = "github-actions-terraform"
    ManagedBy  = "Terraform"
    Purpose    = "GitHubActionsOIDC"
    Repository = "${local.github_org}/${local.github_repo}"
  }
}

###############################################################################
# IAM Policies for Terraform Operations
###############################################################################

# S3 backend access
data "aws_iam_policy_document" "terraform_s3_backend" {
  statement {
    sid    = "S3BackendAccess"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]

    resources = [
      "arn:aws:s3:::eks-gitops-terraform-state-${local.account_id}",
      "arn:aws:s3:::eks-gitops-terraform-state-${local.account_id}/*"
    ]
  }

  statement {
    sid    = "DynamoDBLockAccess"
    effect = "Allow"

    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
      "dynamodb:DescribeTable"
    ]

    resources = [
      "arn:aws:dynamodb:us-east-1:${local.account_id}:table/eks-gitops-terraform-locks"
    ]
  }
}

resource "aws_iam_policy" "terraform_s3_backend" {
  name        = "github-actions-terraform-backend"
  description = "Allow GitHub Actions to access Terraform S3 backend"
  policy      = data.aws_iam_policy_document.terraform_s3_backend.json
}

resource "aws_iam_role_policy_attachment" "terraform_s3_backend" {
  role       = aws_iam_role.github_actions_terraform.name
  policy_arn = aws_iam_policy.terraform_s3_backend.arn
}

# Terraform operations - grant necessary AWS permissions
# WARNING: This is a broad set of permissions for demonstration
# In production, scope down to specific resources and actions needed

data "aws_iam_policy_document" "terraform_operations" {
  # VPC permissions
  statement {
    sid    = "VPCManagement"
    effect = "Allow"

    actions = [
      "ec2:*Vpc*",
      "ec2:*Subnet*",
      "ec2:*RouteTable*",
      "ec2:*InternetGateway*",
      "ec2:*NatGateway*",
      "ec2:*ElasticIp*",
      "ec2:*SecurityGroup*",
      "ec2:*VpcEndpoint*",
      "ec2:*FlowLogs*",
      "ec2:Describe*",
      "ec2:CreateTags",
      "ec2:DeleteTags"
    ]

    resources = ["*"]
  }

  # EKS permissions
  statement {
    sid    = "EKSManagement"
    effect = "Allow"

    actions = [
      "eks:*"
    ]

    resources = ["*"]
  }

  # IAM permissions (limited)
  statement {
    sid    = "IAMManagement"
    effect = "Allow"

    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:ListRoles",
      "iam:UpdateRole",
      "iam:PutRolePolicy",
      "iam:GetRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:ListAttachedRolePolicies",
      "iam:ListRolePolicies",
      "iam:CreatePolicy",
      "iam:DeletePolicy",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:ListPolicyVersions",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion",
      "iam:CreateOpenIDConnectProvider",
      "iam:DeleteOpenIDConnectProvider",
      "iam:GetOpenIDConnectProvider",
      "iam:ListOpenIDConnectProviders",
      "iam:TagOpenIDConnectProvider",
      "iam:TagRole",
      "iam:TagPolicy",
      "iam:CreateInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:GetInstanceProfile",
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile"
    ]

    resources = ["*"]
  }

  # KMS permissions
  statement {
    sid    = "KMSManagement"
    effect = "Allow"

    actions = [
      "kms:CreateKey",
      "kms:CreateAlias",
      "kms:DeleteAlias",
      "kms:DescribeKey",
      "kms:GetKeyPolicy",
      "kms:PutKeyPolicy",
      "kms:EnableKeyRotation",
      "kms:DisableKey",
      "kms:ScheduleKeyDeletion",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:ListAliases",
      "kms:ListKeys"
    ]

    resources = ["*"]
  }

  # CloudWatch Logs
  statement {
    sid    = "CloudWatchLogsManagement"
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:DescribeLogGroups",
      "logs:PutRetentionPolicy",
      "logs:TagLogGroup",
      "logs:UntagLogGroup"
    ]

    resources = ["*"]
  }

  # Read-only access for planning
  statement {
    sid    = "ReadOnlyAccess"
    effect = "Allow"

    actions = [
      "ec2:Describe*",
      "eks:Describe*",
      "eks:List*",
      "iam:Get*",
      "iam:List*",
      "kms:Describe*",
      "kms:Get*",
      "kms:List*",
      "logs:Describe*",
      "s3:Get*",
      "s3:List*"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "terraform_operations" {
  name        = "github-actions-terraform-operations"
  description = "Allow GitHub Actions to perform Terraform operations"
  policy      = data.aws_iam_policy_document.terraform_operations.json
}

resource "aws_iam_role_policy_attachment" "terraform_operations" {
  role       = aws_iam_role.github_actions_terraform.name
  policy_arn = aws_iam_policy.terraform_operations.arn
}

###############################################################################
# Outputs
###############################################################################

output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions IAM role"
  value       = aws_iam_role.github_actions_terraform.arn
}

output "github_actions_role_name" {
  description = "Name of the GitHub Actions IAM role"
  value       = aws_iam_role.github_actions_terraform.name
}
```

**Apply the Terraform:**

```bash
cd terraform/github-oidc-role
terraform init
terraform plan
terraform apply
```

**Save the role ARN from the output:**
```
github_actions_role_arn = "arn:aws:iam::851725636341:role/github-actions-terraform"
```

### Step 3: Configure GitHub Secrets

Add the AWS account ID to GitHub repository secrets:

1. Go to your repository on GitHub
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add the following secret:

| Name | Value | Description |
|------|-------|-------------|
| `AWS_ACCOUNT_ID` | `851725636341` | Your AWS account ID |

**Optional secrets:**

| Name | Value | Description |
|------|-------|-------------|
| `SLACK_WEBHOOK_URL` | `https://hooks.slack.com/...` | Slack webhook for notifications |
| `INFRACOST_API_KEY` | `ico-...` | Infracost API key for cost estimates |

### Step 4: Test the OIDC Connection

Create a test workflow to verify OIDC authentication:

**`.github/workflows/test-oidc.yml`:**

```yaml
name: Test OIDC

on:
  workflow_dispatch:

permissions:
  id-token: write
  contents: read

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/github-actions-terraform
          aws-region: us-east-1
          role-session-name: GitHubActions-Test

      - name: Verify AWS Identity
        run: |
          aws sts get-caller-identity
          echo "✅ OIDC authentication successful!"
```

Run this workflow manually from the GitHub Actions tab to test the connection.

## Workflow Configuration

In your workflows, use the following configuration to assume the role:

```yaml
permissions:
  id-token: write   # Required for OIDC
  contents: read

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/github-actions-terraform
          aws-region: us-east-1
          role-session-name: GitHubActions-Terraform
```

## Security Best Practices

### 1. Scope Down IAM Permissions

The example above grants broad permissions for demonstration. In production:

```hcl
# Limit to specific resources
condition {
  test     = "StringEquals"
  variable = "aws:RequestedRegion"
  values   = ["us-east-1"]
}

# Limit to specific resource tags
condition {
  test     = "StringEquals"
  variable = "aws:ResourceTag/ManagedBy"
  values   = ["Terraform"]
}
```

### 2. Restrict by Branch/Environment

Restrict OIDC trust to specific branches:

```hcl
condition {
  test     = "StringLike"
  variable = "token.actions.githubusercontent.com:sub"
  values = [
    "repo:ORG/REPO:ref:refs/heads/main",           # Only main branch
    "repo:ORG/REPO:environment:production"         # Only prod environment
  ]
}
```

### 3. Use Separate Roles per Environment

Create separate IAM roles for dev and production:

```hcl
# Dev role - more permissive
resource "aws_iam_role" "github_actions_dev" {
  name = "github-actions-terraform-dev"
  # ... limited to dev resources
}

# Prod role - restricted
resource "aws_iam_role" "github_actions_prod" {
  name = "github-actions-terraform-prod"
  # ... requires approval, limited permissions
}
```

### 4. Enable CloudTrail Logging

Ensure CloudTrail is enabled to audit all GitHub Actions operations:

```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=github-actions-terraform
```

## Troubleshooting

### Error: "Not authorized to perform sts:AssumeRoleWithWebIdentity"

**Cause:** Trust policy doesn't match GitHub repository or branch.

**Fix:** Verify the trust policy conditions:
```bash
aws iam get-role --role-name github-actions-terraform \
  --query 'Role.AssumeRolePolicyDocument' \
  --output json
```

### Error: "AccessDenied" when accessing S3 backend

**Cause:** IAM role lacks S3/DynamoDB permissions.

**Fix:** Attach the S3 backend policy:
```bash
aws iam attach-role-policy \
  --role-name github-actions-terraform \
  --policy-arn arn:aws:iam::ACCOUNT_ID:policy/github-actions-terraform-backend
```

### Error: "OpenIDConnect provider not found"

**Cause:** OIDC provider not created in AWS.

**Fix:** Create the provider (see Step 1).

## References

- [GitHub Actions OIDC Documentation](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [AWS IAM OIDC Provider](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)
- [aws-actions/configure-aws-credentials](https://github.com/aws-actions/configure-aws-credentials)
