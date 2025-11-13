# GitHub Repository Setup

## Create GitHub Repository

### Option 1: Using GitHub CLI (Recommended)

```bash
# Install GitHub CLI if not installed
# macOS: brew install gh
# Linux: https://github.com/cli/cli/blob/trunk/docs/install_linux.md

# Authenticate
gh auth login

# Create repository
gh repo create aws-eks-production \
  --public \
  --description "Production-ready AWS EKS infrastructure with hybrid observability (CloudWatch + Prometheus/Grafana)" \
  --source=. \
  --remote=origin \
  --push
```

### Option 2: Using GitHub Web UI

1. Go to https://github.com/new
2. Fill in:
   - Repository name: `aws-eks-production`
   - Description: `Production-ready AWS EKS infrastructure with hybrid observability (CloudWatch + Prometheus/Grafana)`
   - Visibility: Public (or Private if preferred)
   - **Do NOT initialize** with README, .gitignore, or license
3. Click "Create repository"
4. Push existing repository:

```bash
git remote add origin https://github.com/Partridje/aws-eks-production.git
git branch -M main
git push -u origin main
```

## Repository Settings

### 1. Branch Protection

Go to: Settings → Branches → Add branch protection rule

For `main` branch:
- ✅ Require a pull request before merging
- ✅ Require status checks to pass before merging
  - Select: `Validate`, `Security Scan`
- ✅ Require conversation resolution before merging
- ✅ Do not allow bypassing the above settings

### 2. Secrets Setup

Go to: Settings → Secrets and variables → Actions

Add these secrets:

```
AWS_ACCOUNT_ID
  Value: Your AWS account ID (12 digits)
  Example: 123456789012
```

### 3. Environments Setup

Go to: Settings → Environments → New environment

Create environment: `production`
- ✅ Required reviewers: Add yourself
- ✅ Wait timer: 0 minutes (or set delay if needed)

### 4. GitHub Actions OIDC Setup

For GitHub Actions to deploy to AWS, configure OIDC:

#### 4.1 Create IAM Identity Provider in AWS

```bash
# Get GitHub OIDC thumbprint
THUMBPRINT="6938fd4d98bab03faadb97b34396831e3780aea1"

# Create OIDC provider
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list $THUMBPRINT
```

#### 4.2 Create IAM Role for GitHub Actions

```bash
cat > github-actions-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:Partridje/aws-eks-production:*"
        }
      }
    }
  ]
}
EOF

# Create role
aws iam create-role \
  --role-name github-actions-role \
  --assume-role-policy-document file://github-actions-trust-policy.json

# Attach policies (adjust as needed)
aws iam attach-role-policy \
  --role-name github-actions-role \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# For production, use least-privilege policy instead:
# Create custom policy with only required permissions for Terraform
```

## Repository Topics

Add these topics to make the repository discoverable:

Settings → About → Topics:
- `aws`
- `eks`
- `kubernetes`
- `terraform`
- `cloudwatch`
- `prometheus`
- `grafana`
- `observability`
- `devops`
- `infrastructure-as-code`
- `gitops`
- `argocd`

## Repository Description

Update description:
```
Production-ready AWS EKS infrastructure with hybrid observability approach combining CloudWatch Container Insights and Prometheus/Grafana. Features: Multi-AZ VPC, managed node groups, RDS PostgreSQL, X-Ray tracing, comprehensive monitoring, and GitOps with ArgoCD.
```

## Social Preview

Create a custom social preview image:
- Settings → Options → Social preview
- Upload image (1280x640 recommended)
- Include: AWS logo, Kubernetes logo, project name

## License

If making repository public, add a license:

```bash
# Add MIT license
cat > LICENSE <<EOF
MIT License

Copyright (c) 2025 Partridje

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF

git add LICENSE
git commit -m "docs: Add MIT license"
git push
```

## Verify Setup

After setup, verify:

1. ✅ Repository is accessible
2. ✅ GitHub Actions can run (push a small change)
3. ✅ Secrets are configured
4. ✅ Branch protection is active
5. ✅ OIDC authentication works

Test GitHub Actions:
```bash
# Make a small change
echo "" >> README.md
git add README.md
git commit -m "test: Verify GitHub Actions"
git push

# Check Actions tab on GitHub
```

## Done!

Your repository is now set up at:
https://github.com/Partridje/aws-eks-production

Share it, star it, and start deploying!
