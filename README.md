# EKS GitOps Infrastructure

Production-ready EKS infrastructure managed with Terraform and GitOps principles.

## Table of Contents

- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [One-Time Backend Setup](#one-time-backend-setup)
- [GitHub Actions Setup](#github-actions-setup)
- [Important Guidelines](#important-guidelines)
- [Development Workflow](#development-workflow)
- [Makefile Commands](#makefile-commands)
- [Troubleshooting](#troubleshooting)

## Project Structure

```
eks-infrastructure/
├── .github/
│   └── workflows/              # GitHub Actions CI/CD pipelines
├── terraform/
│   ├── modules/                # Reusable Terraform modules
│   ├── environments/
│   │   ├── dev/               # Development environment
│   │   └── prod/              # Production environment
│   └── backend-setup/         # ONE-TIME backend infrastructure setup
├── .gitignore                 # Git ignore rules
├── .pre-commit-config.yaml    # Pre-commit hooks configuration
├── Makefile                   # Helper commands
└── README.md                  # This file
```

## Prerequisites

Before you begin, ensure you have the following installed:

### Required Tools

- **Terraform** (>= 1.6): [Download](https://www.terraform.io/downloads)
- **AWS CLI** (>= 2.0): [Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- **kubectl** (>= 1.28): [Installation Guide](https://kubernetes.io/docs/tasks/tools/)
- **helm** (>= 3.0): [Installation Guide](https://helm.sh/docs/intro/install/)
- **pre-commit**: `pip install pre-commit`

### AWS Credentials

Configure AWS credentials with appropriate permissions:

```bash
aws configure
```

Verify your identity:

```bash
make check-aws
```

Required AWS permissions for backend setup:
- S3: CreateBucket, PutBucketVersioning, PutBucketEncryption, PutBucketPolicy
- DynamoDB: CreateTable
- KMS: CreateKey (if using KMS encryption)

## One-Time Backend Setup

The Terraform backend (S3 + DynamoDB) must be created **once** before deploying any environments.

### Step 1: Initialize Backend Setup

```bash
make backend-init
```

This initializes the `terraform/backend-setup` directory.

### Step 2: Review the Plan

```bash
make backend-plan
```

Review the resources that will be created:
- S3 bucket: `eks-gitops-terraform-state-{account-id}`
- DynamoDB table: `eks-gitops-terraform-locks`

### Step 3: Apply Backend Infrastructure

```bash
make backend-apply
```

**Important**: This command should only be run **ONCE** during initial setup.

### Step 4: Copy Backend Configuration

After successful apply, get the backend configuration:

```bash
make backend-output
```

Create `backend.tf` files in each environment directory:

**terraform/environments/dev/backend.tf:**
```hcl
terraform {
  backend "s3" {
    bucket         = "eks-gitops-terraform-state-123456789012"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "eks-gitops-terraform-locks"
    encrypt        = true
  }
}
```

**terraform/environments/prod/backend.tf:**
```hcl
terraform {
  backend "s3" {
    bucket         = "eks-gitops-terraform-state-123456789012"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "eks-gitops-terraform-locks"
    encrypt        = true
  }
}
```

### Step 5: Initialize Environments

```bash
make init-dev
make init-prod
```

## GitHub Actions CI/CD Setup

All infrastructure changes **must** be deployed via GitHub Actions using automated CI/CD pipelines.

### Quick Start

1. **Set up AWS OIDC authentication** (recommended over long-lived credentials)
   - Follow the complete guide: [.github/GITHUB_OIDC_SETUP.md](.github/GITHUB_OIDC_SETUP.md)
   - This eliminates the need to store AWS access keys in GitHub

2. **Add required GitHub secrets**
   ```
   Settings → Secrets and variables → Actions → New repository secret
   ```
   - `AWS_ACCOUNT_ID` - Your AWS account ID (required)
   - `SLACK_WEBHOOK_URL` - For deployment notifications (optional)
   - `INFRACOST_API_KEY` - For cost estimates (optional)

3. **Configure branch protection rules**
   - See [Branch Protection](#branch-protection-rules) section below

4. **Start using the CI/CD pipeline**
   - Create a feature branch
   - Make changes and push
   - Create pull request
   - Review automated checks and Terraform plan
   - Merge to deploy!

### CI/CD Workflows

Our CI/CD pipeline consists of 4 automated workflows:

#### 1. **terraform-pr.yml** - Pull Request Validation
**Triggered on:** Pull requests to `main`

**What it does:**
- ✅ Terraform format check (`terraform fmt`)
- ✅ Terraform validation for all environments
- ✅ TFLint security and best practices scanning
- ✅ Security scanning (Checkov + Trivy)
- ✅ Generate Terraform plan for each environment
- 💰 Cost estimation with Infracost (optional)
- 💬 Post comprehensive summary comment on PR

**Result:** Blocks merge if critical checks fail

#### 2. **terraform-apply.yml** - Automated Deployment
**Triggered on:** Push to `main` (after PR merge)

**What it does:**
- 🔍 Detect which environments changed
- ✅ Run `terraform plan` to confirm changes
- 🚀 Auto-apply to **dev** environment
- 🛡️ Require manual approval for **prod** environment
- 📢 Send Slack notifications on success/failure

**Deployment Strategy:**
- **Dev:** Automatic deployment
- **Prod:** Manual approval required (configured via GitHub Environments)

#### 3. **pre-commit.yml** - Pre-commit Validation
**Triggered on:** All pushes

**What it does:**
- Validates pre-commit hooks are passing
- Ensures code quality and security checks
- Runs terraform fmt, validate, docs, tflint

#### 4. **terraform-drift-detection.yml** - Configuration Drift Monitoring
**Triggered on:** Daily at 9 AM UTC (weekdays) + manual

**What it does:**
- 🔍 Detect configuration drift (manual changes in AWS)
- 📝 Create GitHub issue with drift details
- 📢 Send Slack notification
- 💾 Upload drift plan as artifact

### Detailed Documentation

For complete CI/CD documentation including:
- Step-by-step workflow process
- Development workflow guide
- Security best practices
- Troubleshooting

**See: [.github/CI_CD_GUIDE.md](.github/CI_CD_GUIDE.md)**

### Branch Protection Rules

Configure branch protection for `main`:

**Settings → Branches → Add branch protection rule**

```yaml
Branch name pattern: main

Protection settings:
  ✅ Require pull request reviews (1 approval)
  ✅ Dismiss stale reviews
  ✅ Require review from Code Owners
  ✅ Require status checks to pass:
     - Terraform Format Check
     - Terraform Validate
     - TFLint Security & Best Practices
  ✅ Require branches to be up to date
  ✅ Require conversation resolution
  ✅ Block force pushes
  ✅ Block deletions
```

### GitHub Environments (for Production Approval)

Create protected environment for production:

**Settings → Environments → New environment: "production"**

```yaml
Environment name: production

Protection rules:
  ✅ Required reviewers: 1-2 people
  ✅ Deployment branches: main only
  ⏱️ Wait timer: 0 minutes (or add delay if desired)
```

## Important Guidelines

### Infrastructure Changes Policy

```
⚠️  ALL INFRASTRUCTURE CHANGES MUST GO THROUGH GITHUB ACTIONS
```

**DO NOT** run `terraform apply` locally for environments (dev/prod).

**Exceptions:**
- Backend setup (one-time operation)
- Local development and testing with `-backend=false`
- Emergency fixes (must be documented)

### Why GitHub Actions Only?

1. **Audit Trail**: All changes are tracked in Git history
2. **Peer Review**: Changes must be reviewed via Pull Requests
3. **Consistency**: Same execution environment for all deployments
4. **Security**: AWS credentials stored securely in GitHub Secrets
5. **State Safety**: Prevents concurrent modifications and state corruption

### Local Development Workflow

1. Create a feature branch
2. Make infrastructure changes
3. Test locally: `terraform init -backend=false && terraform validate`
4. Format code: `make fmt`
5. Commit and push changes
6. Create Pull Request
7. GitHub Actions runs `terraform plan`
8. Review plan in PR comments
9. Merge after approval
10. GitHub Actions runs `terraform apply`

## Makefile Commands

Run `make help` to see all available commands:

### Backend Management
- `make backend-init` - Initialize backend setup (one-time)
- `make backend-plan` - Plan backend infrastructure changes
- `make backend-apply` - Apply backend infrastructure (⚠️ ONE-TIME)
- `make backend-output` - Show backend configuration for copy-paste
- `make backend-destroy` - Destroy backend (⚠️ DANGEROUS)

### Code Quality
- `make fmt` - Format all Terraform files
- `make validate` - Validate all Terraform configurations
- `make install-hooks` - Install pre-commit hooks

### Environment Management
- `make init-dev` - Initialize dev environment
- `make init-prod` - Initialize prod environment

### Utilities
- `make check-aws` - Verify AWS credentials
- `make check-terraform` - Verify Terraform installation
- `make check-prereqs` - Check all prerequisites
- `make clean` - Clean up temporary files

## Development Workflow

### Setting Up Pre-Commit Hooks

```bash
make install-hooks
```

This installs hooks that automatically run on every commit:
- `terraform fmt` - Format Terraform files
- `terraform validate` - Validate configurations
- `terraform_docs` - Generate documentation
- `tflint` - Lint Terraform code
- `tfsec` - Security scanning
- `gitleaks` - Detect secrets

### Making Infrastructure Changes

1. **Create a Branch**
   ```bash
   git checkout -b feature/add-eks-cluster
   ```

2. **Make Changes**
   - Edit Terraform files in `terraform/environments/{env}/`
   - Add or modify modules in `terraform/modules/`

3. **Format and Validate**
   ```bash
   make fmt
   make validate
   ```

4. **Test Locally (Optional)**
   ```bash
   cd terraform/environments/dev
   terraform init -backend=false
   terraform plan
   ```

5. **Commit Changes**
   ```bash
   git add .
   git commit -m "Add EKS cluster configuration"
   ```
   Pre-commit hooks will run automatically.

6. **Push and Create PR**
   ```bash
   git push origin feature/add-eks-cluster
   ```

7. **Review Plan in GitHub Actions**
   - GitHub Actions will run `terraform plan`
   - Review the plan output in PR comments

8. **Merge PR**
   - After approval, merge to main
   - GitHub Actions will run `terraform apply`

## Security Best Practices

### State File Security

- State files are stored in encrypted S3 bucket
- Versioning enabled for recovery
- DynamoDB locking prevents concurrent modifications
- Public access blocked

### Secrets Management

- **NEVER** commit sensitive values to Git
- Use AWS Secrets Manager or Parameter Store
- Reference secrets in Terraform using data sources
- Add `.tfvars` files to `.gitignore`

### IAM Permissions

- Follow principle of least privilege
- Use separate IAM roles for dev/prod
- Enable CloudTrail for audit logging
- Rotate credentials regularly

## Troubleshooting

### Common Issues

#### Backend Initialization Failed

**Problem**: `Error loading state: AccessDenied`

**Solution**: Verify AWS credentials have access to S3 bucket and DynamoDB table.

```bash
make check-aws
aws s3 ls s3://eks-gitops-terraform-state-{account-id}
```

#### State Lock Timeout

**Problem**: `Error acquiring the state lock`

**Solution**: Someone else is running Terraform, or a previous run crashed.

```bash
# List locks
aws dynamodb scan --table-name eks-gitops-terraform-locks

# If confirmed stuck, force unlock (use with caution)
cd terraform/environments/dev
terraform force-unlock LOCK_ID
```

#### Pre-Commit Hooks Failing

**Problem**: Hooks fail on commit

**Solution**: Fix the issues or temporarily skip (not recommended):

```bash
git commit --no-verify -m "message"
```

#### Terraform Version Mismatch

**Problem**: `Required Terraform version mismatch`

**Solution**: Install correct Terraform version or use `tfenv`:

```bash
# Install tfenv
brew install tfenv

# Install and use specific version
tfenv install 1.6.0
tfenv use 1.6.0
```

## Next Steps

1. ✅ Backend infrastructure created
2. ✅ Environments initialized (dev/prod)
3. ✅ GitHub Actions CI/CD workflows configured
4. ✅ VPC module created
5. ✅ IAM module created
6. ✅ EKS cluster module created
7. 🔄 Deploy VPC infrastructure
8. 🔄 Deploy IAM roles
9. 🔄 Deploy EKS cluster
10. 🔄 Create node groups module
11. 🔄 Configure ArgoCD
12. 🔄 Set up monitoring and logging

## Documentation

### Core Guides
- **[CI/CD Guide](.github/CI_CD_GUIDE.md)** - Complete GitHub Actions CI/CD documentation
- **[OIDC Setup](.github/GITHUB_OIDC_SETUP.md)** - AWS OIDC authentication setup
- **[VPC Module](terraform/modules/vpc/README.md)** - VPC module documentation
- **[IAM Module](terraform/modules/iam-eks/README.md)** - IAM roles and IRSA setup
- **[EKS Module](terraform/modules/eks-cluster/README.md)** - EKS cluster and OIDC provider

### External Resources
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [GitOps Principles](https://opengitops.dev/)
- [GitHub Actions OIDC](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)

## Support

For issues or questions:
- Create an issue in this repository
- Check Terraform documentation
- Review AWS EKS documentation

---

**Remember**: Always use GitHub Actions for infrastructure deployments. Local applies should only be used for the initial backend setup.
