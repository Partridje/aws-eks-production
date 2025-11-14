# Contributing Guide

This document outlines the development workflow and best practices for this project.

## Table of Contents

- [Development Workflow](#development-workflow)
- [Branch Protection](#branch-protection)
- [Pull Request Process](#pull-request-process)
- [Commit Message Guidelines](#commit-message-guidelines)
- [Code Quality Standards](#code-quality-standards)
- [Testing Requirements](#testing-requirements)

## Development Workflow

### 1. Never Push Directly to Main

**❌ NEVER do this:**
```bash
git checkout main
git add .
git commit -m "changes"
git push origin main  # ❌ BLOCKED
```

**✅ ALWAYS use feature branches:**
```bash
# Create feature branch
git checkout -b feature/my-feature
# or
git checkout -b fix/bug-description

# Make changes and commit
git add .
git commit -m "feat: add new feature"

# Push to feature branch
git push -u origin feature/my-feature

# Create Pull Request
gh pr create
# or visit GitHub UI
```

### 2. Branch Naming Convention

Use prefixes to indicate the type of change:

- `feature/` - New features or enhancements
- `fix/` - Bug fixes
- `docs/` - Documentation changes
- `refactor/` - Code refactoring
- `test/` - Adding or updating tests
- `chore/` - Maintenance tasks

**Examples:**
```
feature/add-monitoring-dashboard
fix/terraform-circular-dependency
docs/update-rbac-setup
refactor/extract-iam-module
chore/update-dependencies
```

### 3. Git Hooks

Pre-commit and pre-push hooks are automatically configured:

**Pre-commit** (runs on `git commit`):
- ✅ Terraform format check
- ✅ Terraform validate
- ✅ Auto-format if needed
- ✅ Check for hardcoded secrets

**Pre-push** (runs on `git push`):
- ✅ Terraform format check (strict)
- ✅ Validate all environments
- ✅ Security scans
- ✅ Large file detection

## Branch Protection

The `main` branch is protected with the following rules:

### Required Status Checks
- ✅ Terraform Format Check
- ✅ Terraform Validate
- ✅ TFLint (Best Practices)
- ✅ tfsec (Security Scan)
- ✅ Checkov (Security Scan)

### Branch Protection Rules
- ✅ Require pull request before merging
- ✅ Require approvals: 1 (configure in GitHub Settings)
- ✅ Dismiss stale pull request approvals when new commits are pushed
- ✅ Require status checks to pass before merging
- ✅ Require branches to be up to date before merging
- ✅ Require linear history (no merge commits)
- ❌ Do not allow bypassing the above settings

### How to Configure (Repository Admin)

1. Go to **Settings** → **Branches**
2. Click **Add branch protection rule**
3. Branch name pattern: `main`
4. Enable the following:
   - ☑ Require a pull request before merging
     - Required approvals: 1
     - Dismiss stale reviews when new commits are pushed
   - ☑ Require status checks to pass before merging
     - ☑ Require branches to be up to date
     - Add status checks: `Validate`, `Lint & Best Practices`, `Security & Cost Analysis`
   - ☑ Require linear history
   - ☑ Do not allow bypassing the above settings
5. Click **Create**

## Pull Request Process

### 1. Create Pull Request

```bash
# Using GitHub CLI (recommended)
gh pr create --title "feat: Add monitoring dashboard" \
  --body "Description of changes"

# Or push and use GitHub UI
git push -u origin feature/my-feature
# Then create PR on GitHub
```

### 2. PR Requirements

Before your PR can be merged:

✅ **All CI checks must pass:**
- Terraform Format Check
- Terraform Validate
- TFLint
- tfsec
- Checkov
- Terraform Plan (review output)

✅ **Code review:**
- At least 1 approval required
- Address all review comments

✅ **Up to date:**
- Branch must be up to date with main
- Resolve any merge conflicts

### 3. PR Template

Use this template for PR descriptions:

```markdown
## Changes
- Brief description of what changed
- Why this change was needed

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update

## Testing
- [ ] Pre-commit hooks passed
- [ ] Terraform validate passed
- [ ] Tested in dev environment
- [ ] Reviewed Terraform plan output

## Checklist
- [ ] My code follows the code style of this project
- [ ] I have updated the documentation accordingly
- [ ] I have added tests that prove my fix is effective or that my feature works
- [ ] All new and existing tests passed
```

### 4. Merging

Once approved and all checks pass:

```bash
# Squash and merge (recommended for clean history)
gh pr merge --squash

# Or use GitHub UI to merge
```

## Commit Message Guidelines

Follow [Conventional Commits](https://www.conventionalcommits.org/) specification:

### Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only changes
- `style`: Code style changes (formatting, no code change)
- `refactor`: Code refactoring
- `perf`: Performance improvements
- `test`: Adding or updating tests
- `chore`: Maintenance tasks
- `ci`: CI/CD changes

### Examples

```
feat(vpc): add VPC flow logs for network monitoring

Add VPC flow logs to capture network traffic for security analysis
and troubleshooting. Logs are stored in CloudWatch with 7-day retention.

Closes #123
```

```
fix(eks): resolve circular dependency in IRSA configuration

Move RBAC IAM roles to separate module to avoid circular dependency
between EKS cluster OIDC and IAM role creation.

Fixes #45
```

```
docs(rbac): update RBAC setup guide with role assumption examples

Add detailed examples of how to assume different RBAC roles
using the helper script.
```

## Code Quality Standards

### Terraform Best Practices

1. **Module Structure**
   ```
   module-name/
   ├── main.tf       # Primary entrypoint
   ├── variables.tf  # Input variables
   ├── outputs.tf    # Output values
   ├── versions.tf   # Version constraints
   └── README.md     # Module documentation
   ```

2. **Naming Conventions**
   - Use `snake_case` for all resource names
   - Be descriptive: `eks_cluster_security_group` not `sg1`
   - Use consistent prefixes: `${var.cluster_name}-resource-name`

3. **Variables**
   - Always include descriptions
   - Specify types explicitly
   - Provide defaults when sensible
   - Use validation rules

   ```hcl
   variable "cluster_name" {
     description = "Name of the EKS cluster"
     type        = string

     validation {
       condition     = can(regex("^[a-z0-9-]+$", var.cluster_name))
       error_message = "Cluster name must be lowercase alphanumeric with hyphens."
     }
   }
   ```

4. **Outputs**
   - Always include descriptions
   - Mark sensitive outputs as `sensitive = true`
   - Export useful values for consumption

5. **Documentation**
   - Use `terraform-docs` to auto-generate module docs
   - Keep README.md up to date
   - Document complex logic with comments

### Security Best Practices

1. **Never commit secrets**
   - Use AWS Secrets Manager or SSM Parameter Store
   - Reference secrets via data sources
   - Git hooks check for hardcoded secrets

2. **Use least privilege IAM**
   - IRSA for pod-level permissions
   - Specific policies, not `*` permissions
   - Regular security scans with tfsec/Checkov

3. **Enable encryption**
   - S3 bucket encryption
   - EBS volume encryption
   - RDS encryption at rest
   - Secrets Manager encryption

4. **Network security**
   - Private subnets for workloads
   - Security groups with minimal access
   - VPC endpoints to avoid NAT gateway costs
   - Network ACLs where appropriate

## Testing Requirements

### Before Committing

```bash
# Format Terraform code
terraform fmt -recursive terraform/

# Validate configurations
cd terraform/environments/dev
terraform init -backend=false
terraform validate

# Run TFLint
cd ../../../terraform
tflint --init
tflint --recursive
```

### Before Creating PR

```bash
# Run all checks
./scripts/pre-push-check.sh  # If you create this script

# Or manually:
terraform fmt -check -recursive terraform/
tflint --recursive terraform/
tfsec terraform/
checkov -d terraform/
```

### In Pull Request

GitHub Actions automatically runs:
- Terraform fmt check
- Terraform validate
- TFLint
- tfsec
- Checkov
- Infracost (if configured)
- Terraform plan (with comment)

## Troubleshooting

### CI Checks Failing

**Terraform Format:**
```bash
terraform fmt -recursive terraform/
git add .
git commit --amend --no-edit
git push --force-with-lease
```

**TFLint Errors:**
```bash
cd terraform
tflint --init
tflint --recursive --fix
git add .
git commit -m "fix: address TFLint issues"
```

**Validation Errors:**
- Check the error message in CI logs
- Test locally: `cd terraform/environments/dev && terraform validate`
- Fix the issue and push

### Merge Conflicts

```bash
# Update your branch with main
git fetch origin
git rebase origin/main

# Resolve conflicts
# ... edit files ...

git add .
git rebase --continue
git push --force-with-lease
```

### Need to Update PR

```bash
# Make changes
git add .
git commit -m "fix: address review comments"
git push

# PR automatically updates
```

## Getting Help

- 📖 Read the [README](../README.md)
- 🔍 Check [existing issues](https://github.com/Partridje/aws-eks-production/issues)
- 💬 Ask in pull request comments
- 📝 Create a new issue if you found a bug

## Resources

- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [AWS EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [TFLint Rules](https://github.com/terraform-linters/tflint)
