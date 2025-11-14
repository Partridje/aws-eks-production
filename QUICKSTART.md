# Quick Start Guide

## Prerequisites Check

```bash
make check-prereqs
```

## One-Time Backend Setup

### Step 1: Initialize
```bash
make backend-init
```

### Step 2: Review Plan
```bash
make backend-plan
```

### Step 3: Create Backend (ONE-TIME ONLY)
```bash
make backend-apply
```

### Step 4: Get Backend Configuration
```bash
make backend-output
```

Copy the output and create `backend.tf` files:

**terraform/environments/dev/backend.tf**
**terraform/environments/prod/backend.tf**

Update the `key` value:
- dev: `key = "dev/terraform.tfstate"`
- prod: `key = "prod/terraform.tfstate"`

### Step 5: Initialize Environments
```bash
make init-dev
make init-prod
```

## Daily Workflow

### Format Code
```bash
make fmt
```

### Validate
```bash
make validate
```

### Install Pre-Commit Hooks
```bash
make install-hooks
```

## Important Rules

1. Backend setup runs ONCE locally
2. All other infrastructure: **GitHub Actions ONLY**
3. Never commit `.tfvars` files with secrets
4. Always create Pull Requests for changes
5. Review `terraform plan` before merging

## Next Steps

1. Set up AWS credentials in GitHub Secrets
2. Create GitHub Actions workflows
3. Start building infrastructure modules

See [README.md](README.md) for detailed documentation.
