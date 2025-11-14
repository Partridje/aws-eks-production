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

## GitHub Actions Setup

### Configure AWS Credentials in GitHub

All infrastructure changes **must** be deployed via GitHub Actions.

#### Option 1: OIDC (Recommended)

1. Create an IAM OIDC provider for GitHub Actions
2. Create IAM roles with appropriate permissions
3. Configure in `.github/workflows/` (coming in next step)

#### Option 2: IAM User with Access Keys

1. Create an IAM user with programmatic access
2. Attach necessary policies (AdministratorAccess or custom)
3. Generate access keys
4. Add secrets to GitHub repository:

```
Settings → Secrets and variables → Actions → New repository secret
```

Add the following secrets:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION` (e.g., `us-east-1`)

### GitHub Actions Workflows

Workflows will be added in the next step. They will:
- Run `terraform fmt` check
- Run `terraform validate`
- Run `terraform plan` on PRs
- Run `terraform apply` on merges to main
- Environment-specific deployments (dev/prod)

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
3. 🔄 Add GitHub Actions workflows
4. 🔄 Create VPC module
5. 🔄 Create EKS module
6. 🔄 Configure ArgoCD
7. 🔄 Set up monitoring and logging

## Resources

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [GitOps Principles](https://opengitops.dev/)

## Support

For issues or questions:
- Create an issue in this repository
- Check Terraform documentation
- Review AWS EKS documentation

---

**Remember**: Always use GitHub Actions for infrastructure deployments. Local applies should only be used for the initial backend setup.
