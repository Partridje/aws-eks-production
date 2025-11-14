# CI/CD Guide for Terraform Infrastructure

This guide explains the complete CI/CD pipeline for managing EKS infrastructure with GitHub Actions.

## Table of Contents

- [Overview](#overview)
- [Workflows](#workflows)
- [Setup Instructions](#setup-instructions)
- [Development Workflow](#development-workflow)
- [Branch Protection](#branch-protection)
- [Security](#security)
- [Troubleshooting](#troubleshooting)

## Overview

Our CI/CD pipeline uses GitHub Actions with AWS OIDC authentication to automate Terraform operations:

```
┌─────────────────────────────────────────────────────────────┐
│                    Developer Workflow                        │
└─────────────────────────────────────────────────────────────┘
                            ↓
        ┌───────────────────────────────────────┐
        │   1. Create Feature Branch            │
        │   2. Make Changes                     │
        │   3. Commit (Pre-commit Hooks)       │
        │   4. Push (Pre-push Checks)          │
        │   5. Create Pull Request             │
        └───────────────────────────────────────┘
                            ↓
        ┌───────────────────────────────────────┐
        │      Terraform PR Workflow            │
        │  ✓ Format Check                       │
        │  ✓ Validation                         │
        │  ✓ TFLint                             │
        │  ✓ Security Scan (Checkov/Trivy)     │
        │  ✓ Terraform Plan                     │
        │  ✓ Cost Estimate (optional)          │
        │  ✓ PR Comment with Results           │
        └───────────────────────────────────────┘
                            ↓
        ┌───────────────────────────────────────┐
        │      Code Review & Approval           │
        └───────────────────────────────────────┘
                            ↓
        ┌───────────────────────────────────────┐
        │      Merge to Main                    │
        └───────────────────────────────────────┘
                            ↓
        ┌───────────────────────────────────────┐
        │    Terraform Apply Workflow           │
        │  ✓ Detect Changed Environments        │
        │  ✓ Terraform Init                     │
        │  ✓ Terraform Plan                     │
        │  ✓ Terraform Apply (auto-approve)    │
        │  ✓ Slack Notification                │
        └───────────────────────────────────────┘
                            ↓
        ┌───────────────────────────────────────┐
        │    Infrastructure Deployed            │
        └───────────────────────────────────────┘
```

## Workflows

### 1. terraform-pr.yml (Pull Request Checks)

**Trigger:** Pull requests to `main` branch
**Purpose:** Validate changes before merge

**Jobs:**

| Job | Description | Failure Action |
|-----|-------------|----------------|
| `terraform-fmt` | Check Terraform formatting | ❌ Blocks merge |
| `terraform-validate` | Validate all environments | ❌ Blocks merge |
| `tflint` | Lint Terraform code | ⚠️ Warning only |
| `security-scan` | Scan for security issues (Checkov + Trivy) | ⚠️ Warning only |
| `terraform-plan` | Generate plan for each environment | ✅ Informational |
| `cost-estimate` | Estimate infrastructure costs | ✅ Informational |
| `pr-summary` | Create summary comment on PR | ✅ Always runs |

**Permissions Required:**
```yaml
permissions:
  id-token: write      # For AWS OIDC
  contents: read       # To checkout code
  pull-requests: write # To comment on PRs
  issues: write        # To comment on PRs
```

**Example PR Comment:**

```markdown
## Terraform PR Checks Summary

| Check | Status |
|-------|--------|
| Terraform Format | ✅ success |
| Terraform Validate | ✅ success |
| TFLint | ⚠️ success |
| Security Scan | ⚠️ success |
| Terraform Plan | ✅ success |

---

### Terraform Plan: `dev/03-eks-cluster`

<details>
<summary>Show Plan</summary>

```terraform
Plan: 7 to add, 0 to change, 0 to destroy.
```

</details>

💰 **Cost Estimate:** $75/month
```

### 2. terraform-apply.yml (Deployment)

**Trigger:** Push to `main` branch
**Purpose:** Deploy infrastructure changes

**Jobs:**

| Job | Description | Environment |
|-----|-------------|-------------|
| `detect-changes` | Identify changed environments | All |
| `terraform-apply-dev` | Auto-deploy to dev | Dev |
| `terraform-apply-prod` | Deploy to prod (manual approval) | Prod |
| `summary` | Create deployment summary | All |

**Deployment Strategy:**

- **Dev:** Auto-apply after merge
- **Prod:** Requires manual approval via GitHub Environments

**Notifications:**

- ✅ Success: Slack notification
- ❌ Failure: Slack notification with run link

### 3. pre-commit.yml (Pre-commit Validation)

**Trigger:** All pushes
**Purpose:** Ensure pre-commit hooks are passing in CI

**Hooks Run:**
- Terraform fmt
- Terraform validate
- Terraform docs
- TFLint
- Trailing whitespace
- YAML/JSON syntax
- Large file detection
- Secret detection (gitleaks)

### 4. terraform-drift-detection.yml (Scheduled)

**Trigger:** Daily at 9 AM UTC (weekdays) + manual
**Purpose:** Detect configuration drift

**Actions on Drift:**
1. Creates GitHub Issue with drift details
2. Uploads drift plan as artifact
3. Sends Slack notification

**Example Drift Issue:**

```markdown
## Configuration Drift Detected

**Environment:** `dev/03-eks-cluster`
**Detected:** 2025-11-14T09:00:00Z

### What is Drift?

Configuration drift occurs when actual infrastructure differs from Terraform state.

### Next Steps
1. Review the drift
2. Import changes or revert
3. Investigate who/what made changes
```

## Setup Instructions

### Step 1: AWS OIDC Configuration

Follow [GITHUB_OIDC_SETUP.md](./GITHUB_OIDC_SETUP.md) to:

1. Create IAM OIDC provider in AWS
2. Create IAM role for GitHub Actions
3. Configure trust policy for your repository

**Required IAM Role ARN:**
```
arn:aws:iam::ACCOUNT_ID:role/github-actions-terraform
```

### Step 2: GitHub Secrets

Add repository secrets:

**Settings → Secrets and variables → Actions → New repository secret**

| Secret Name | Value | Required |
|-------------|-------|----------|
| `AWS_ACCOUNT_ID` | Your AWS account ID | ✅ Yes |
| `SLACK_WEBHOOK_URL` | Slack webhook URL | ⚠️ Optional |
| `INFRACOST_API_KEY` | Infracost API key | ⚠️ Optional |

### Step 3: GitHub Environments (for Production)

Create protected environment for production deployments:

**Settings → Environments → New environment**

**Name:** `production`

**Protection Rules:**
- ✅ Required reviewers: 1-2 people
- ✅ Wait timer: 0 minutes (or add delay)
- ✅ Deployment branches: Only `main`

### Step 4: Branch Protection Rules

Configure branch protection for `main`:

**Settings → Branches → Add rule**

**Branch name pattern:** `main`

**Protection settings:**
- ✅ Require pull request reviews before merging (1 approval)
- ✅ Require status checks to pass before merging:
  - `Terraform Format Check`
  - `Terraform Validate`
  - `TFLint Security & Best Practices`
- ✅ Require branches to be up to date before merging
- ✅ Require conversation resolution before merging
- ✅ Do not allow bypassing the above settings
- ✅ Block force pushes
- ✅ Do not allow deletions

### Step 5: Enable Workflows

Workflows are automatically enabled when you push them to the repository.

**Verify workflows:**
```bash
# List all workflows
gh workflow list

# Run test workflow
gh workflow run terraform-drift-detection.yml
```

## Development Workflow

### Step-by-Step Process

#### 1. Create Feature Branch

```bash
# Update main
git checkout main
git pull origin main

# Create feature branch
git checkout -b feature/add-node-groups

# Or for fixes
git checkout -b fix/eks-cluster-version
```

#### 2. Make Changes

```bash
# Edit Terraform files
vim terraform/environments/dev/04-node-groups/main.tf

# Format code
terraform fmt -recursive terraform/

# Validate locally (optional)
cd terraform/environments/dev/04-node-groups
terraform init -backend=false
terraform validate
```

#### 3. Commit Changes

Pre-commit hooks will automatically run:

```bash
git add terraform/environments/dev/04-node-groups/

git commit -m "Add EKS node groups module

- Create node-groups module for managed node groups
- Configure auto-scaling with min 2, max 10 nodes
- Add spot instance support for cost savings
- Enable SSM access for debugging"

# Pre-commit hooks run automatically:
# ✓ Terraform fmt
# ✓ Terraform validate
# ✓ TFLint
# ✓ Terraform docs
# ✓ YAML/JSON checks
# ✓ Secret detection
```

#### 4. Push to Remote

```bash
git push origin feature/add-node-groups

# Pre-push checks run:
# ✓ Terraform fmt validation
# ✓ Terraform validate all environments
# ✓ Secret scanning
```

#### 5. Create Pull Request

```bash
# Using GitHub CLI
gh pr create \
  --title "Add EKS Node Groups Module" \
  --body "See commit message for details"

# Or via GitHub web UI
```

#### 6. Wait for CI Checks

GitHub Actions will automatically:
- ✅ Check formatting
- ✅ Validate configuration
- ✅ Run TFLint
- ✅ Scan for security issues
- ✅ Generate Terraform plan
- ✅ Estimate costs (if Infracost configured)
- ✅ Comment results on PR

**Review the PR comment** for plan details and cost estimates.

#### 7. Code Review

- Request review from team members (CODEOWNERS auto-assigned)
- Address any feedback
- Ensure all checks pass

#### 8. Merge Pull Request

```bash
# Via GitHub CLI
gh pr merge --squash

# Or via GitHub web UI
# Click "Squash and merge"
```

#### 9. Automatic Deployment

After merge, `terraform-apply.yml` automatically:
1. Detects changed environments
2. Runs `terraform plan`
3. Runs `terraform apply -auto-approve` (for dev)
4. Sends Slack notification

**For production:** Manual approval required in GitHub UI.

## Branch Protection

### Recommended Settings

```yaml
# .github/branch-protection.yml (for reference)
main:
  required_reviews: 1
  dismiss_stale_reviews: true
  require_code_owner_reviews: true
  required_status_checks:
    - "Terraform Format Check"
    - "Terraform Validate"
    - "TFLint Security & Best Practices"
  enforce_admins: false  # Allow emergency bypasses
  restrictions: null     # No push restrictions
  allow_force_pushes: false
  allow_deletions: false
```

## Security

### OIDC vs Long-lived Credentials

**Traditional Approach (❌ Not Recommended):**
```yaml
# DON'T DO THIS
env:
  AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
  AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

**OIDC Approach (✅ Recommended):**
```yaml
# DO THIS
- uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/github-actions-terraform
    aws-region: us-east-1
```

**Benefits:**
- No long-lived credentials in GitHub secrets
- Automatic credential rotation
- Fine-grained IAM permissions
- CloudTrail audit trail

### Security Scanning

**Tools Used:**

1. **Checkov** - Terraform security scanning
   - Checks for 1000+ security policies
   - Covers AWS, Azure, GCP
   - Example: Detects unencrypted S3 buckets

2. **Trivy** - IaC misconfiguration scanning
   - SARIF output uploaded to GitHub Security
   - View results in **Security → Code scanning**

3. **Gitleaks** - Secret detection
   - Scans commits for hardcoded credentials
   - Runs in pre-commit hooks

4. **TFLint** - Terraform linting
   - AWS-specific rules
   - Naming conventions
   - Deprecated syntax

### Secrets Management

**Never commit:**
- ❌ AWS access keys
- ❌ AWS secret keys
- ❌ API tokens
- ❌ Private keys
- ❌ Passwords

**Use instead:**
- ✅ GitHub Secrets for sensitive values
- ✅ AWS Systems Manager Parameter Store
- ✅ AWS Secrets Manager
- ✅ OIDC for AWS authentication

## Troubleshooting

### Workflow Failed: "Not authorized to perform sts:AssumeRoleWithWebIdentity"

**Cause:** Trust policy doesn't allow GitHub Actions

**Fix:**
```bash
# Verify trust policy
aws iam get-role --role-name github-actions-terraform \
  --query 'Role.AssumeRolePolicyDocument'

# Should include:
# "token.actions.githubusercontent.com:sub": "repo:ORG/REPO:*"
```

### Workflow Failed: "Terraform fmt check failed"

**Cause:** Code not formatted

**Fix:**
```bash
terraform fmt -recursive terraform/
git add .
git commit --amend --no-edit
git push --force-with-lease
```

### Workflow Failed: "Backend initialization failed"

**Cause:** S3 bucket or DynamoDB table doesn't exist

**Fix:**
```bash
# Deploy backend first
cd terraform/backend-setup
terraform init
terraform apply
```

### PR Comment Not Created

**Cause:** Missing PR write permissions

**Fix:** Verify workflow has:
```yaml
permissions:
  pull-requests: write
  issues: write
```

### Drift Detection Creating Duplicate Issues

**Cause:** Issue matching logic not finding existing issue

**Fix:** Issues are deduplicated by environment name in title. Existing issues get new comments instead.

### Cost Estimate Not Showing

**Cause:** Infracost API key not configured

**Fix:**
```bash
# Get API key from https://www.infracost.io/
# Add to GitHub Secrets as INFRACOST_API_KEY
```

## Best Practices

### 1. Commit Messages

Follow conventional commits:

```bash
# Format
<type>(<scope>): <subject>

# Examples
feat(eks): add managed node groups with spot instances
fix(vpc): correct NAT gateway count for HA
docs(readme): update deployment instructions
chore(ci): upgrade terraform to 1.7.0
```

### 2. PR Size

Keep PRs small and focused:
- ✅ Single module or feature
- ✅ < 500 lines of code
- ❌ Multiple unrelated changes

### 3. Testing

Test locally before pushing:

```bash
# Format
terraform fmt -recursive terraform/

# Validate
terraform validate

# Plan
terraform plan

# Run pre-commit manually
pre-commit run --all-files
```

### 4. Documentation

Update README when changing modules:

```bash
# Auto-generate docs
terraform-docs markdown table . > README.md

# Or let pre-commit do it automatically
```

### 5. State Management

Never commit state files:

```bash
# Already in .gitignore
terraform.tfstate
terraform.tfstate.backup
.terraform/
```

## Monitoring

### Workflow Run History

View all workflow runs:
```bash
gh run list --workflow=terraform-pr.yml
gh run list --workflow=terraform-apply.yml
```

### Deployment History

Check what was deployed when:
```bash
# View recent deployments
gh run list --workflow=terraform-apply.yml --limit 10

# View specific run
gh run view <run-id>
```

### Cost Tracking

If Infracost is configured:
1. View PR comments for cost estimates
2. Track cost trends over time
3. Get alerts for unexpected cost increases

## Additional Resources

- [GitHub Actions OIDC Setup](./GITHUB_OIDC_SETUP.md)
- [Terraform Best Practices](../docs/TERRAFORM_BEST_PRACTICES.md)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
