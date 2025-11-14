# Terraform Linters Setup

This project uses multiple linters to ensure code quality and security.

## Linters Overview

| Linter | Purpose | Documentation |
|--------|---------|---------------|
| **TFLint** | Terraform code linting | [github.com/terraform-linters/tflint](https://github.com/terraform-linters/tflint) |
| **tfsec** | Security scanning | [aquasecurity.github.io/tfsec](https://aquasecurity.github.io/tfsec/) |
| **checkov** | Policy-as-code scanning | [checkov.io](https://www.checkov.io/) |
| **terraform-docs** | Documentation generation | [terraform-docs.io](https://terraform-docs.io/) |

## Installation

### macOS (Homebrew)

```bash
# TFLint
brew install tflint

# tfsec
brew install tfsec

# checkov (requires Python)
pip3 install checkov

# terraform-docs
brew install terraform-docs
```

### Linux

```bash
# TFLint
curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash

# tfsec
curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash

# checkov
pip3 install checkov

# terraform-docs
brew install terraform-docs  # or download from releases
```

### Windows

```powershell
# Using Chocolatey
choco install tflint
choco install tfsec
pip3 install checkov
choco install terraform-docs
```

### Verify Installation

```bash
make check-linters
```

## Configuration Files

- `.tflint.hcl` - TFLint configuration
- `.tfsec.yml` - tfsec configuration
- `.checkov.yaml` - checkov configuration (optional)

## Usage

### Run All Linters

```bash
make lint
```

### Run Individual Linters

```bash
# TFLint
make tflint

# tfsec
make tfsec

# checkov
make checkov

# Generate documentation
make docs
```

### Run on Specific Directory

```bash
# TFLint
tflint --chdir=terraform/modules/vpc

# tfsec
tfsec terraform/modules/vpc

# checkov
checkov -d terraform/modules/vpc
```

## TFLint Configuration

Located in `.tflint.hcl`:

- **Naming conventions**: Enforces snake_case
- **Documentation**: Requires variable/output descriptions
- **AWS plugin**: Validates AWS-specific resources
- **Version constraints**: Ensures provider versions are pinned

### Initialize TFLint (First Time)

```bash
tflint --init
```

This downloads the AWS plugin.

## tfsec Configuration

Located in `.tfsec.yml`:

- **Minimum severity**: MEDIUM
- **Excluded checks**: Documented exceptions
- **Output format**: Configurable (default, json, sarif)

### Common tfsec Checks

- S3 bucket encryption
- S3 bucket versioning
- VPC flow logs
- IAM policy validation
- Security group rules
- Database encryption

## Checkov Configuration

Optional `.checkov.yaml`:

```yaml
framework: terraform
quiet: false
compact: true
skip-check:
  - CKV_AWS_18  # Example: Skip specific check
```

### Common Checkov Policies

- CKV_AWS_19: Ensure S3 bucket has encryption
- CKV_AWS_21: Ensure S3 bucket has versioning
- CKV_AWS_18: Ensure S3 bucket has access logging
- CKV_AWS_20: Ensure S3 bucket has MFA delete

## Pre-Commit Integration

Linters run automatically on commit via `.pre-commit-config.yaml`:

```bash
# Install pre-commit hooks
make install-hooks

# Run manually
pre-commit run --all-files
```

## CI/CD Integration

Add to GitHub Actions:

```yaml
- name: Run TFLint
  run: |
    tflint --init
    tflint --recursive

- name: Run tfsec
  uses: aquasecurity/tfsec-action@v1.0.0
  with:
    soft_fail: true

- name: Run Checkov
  uses: bridgecrewio/checkov-action@master
  with:
    directory: terraform/
    framework: terraform
```

## Ignoring Specific Checks

### TFLint

In code:
```hcl
# tflint-ignore: aws_instance_previous_type
resource "aws_instance" "example" {
  instance_type = "t2.micro"
}
```

### tfsec

In code:
```hcl
# tfsec:ignore:aws-s3-enable-bucket-logging
resource "aws_s3_bucket" "example" {
  bucket = "my-bucket"
}
```

In config (`.tfsec.yml`):
```yaml
exclude:
  - aws-s3-enable-bucket-logging
```

### checkov

In code:
```hcl
# checkov:skip=CKV_AWS_18: Logging not required for this bucket
resource "aws_s3_bucket" "example" {
  bucket = "my-bucket"
}
```

## Fixing Common Issues

### Issue: TFLint AWS Plugin Not Found

```bash
tflint --init
```

### Issue: tfsec False Positives

Update `.tfsec.yml` to exclude specific checks:
```yaml
exclude:
  - aws-s3-enable-bucket-logging
```

### Issue: Checkov Blocking CI/CD

Use `soft_fail: true` or exclude checks:
```yaml
skip-check:
  - CKV_AWS_18
```

## Best Practices

1. **Run linters locally** before pushing
2. **Fix issues** rather than ignoring (when possible)
3. **Document exceptions** when ignoring checks
4. **Update configurations** as project evolves
5. **Run in CI/CD** for enforcement
6. **Review linter reports** in PRs

## Linter Output Examples

### TFLint Success
```
✅ No issues found
```

### tfsec Issues Found
```
Result 1

  [aws-s3-enable-bucket-logging]
  Resource 'aws_s3_bucket.example'
  Bucket does not have logging enabled

  See https://aquasecurity.github.io/tfsec/latest/checks/aws/s3/enable-bucket-logging/
```

### Checkov Issues Found
```
Check: CKV_AWS_18: "Ensure S3 bucket has access logging enabled"
        FAILED for resource: aws_s3_bucket.example
        File: /main.tf:10-13
```

## Resources

- [TFLint Rules](https://github.com/terraform-linters/tflint-ruleset-aws/blob/master/docs/rules/README.md)
- [tfsec Checks](https://aquasecurity.github.io/tfsec/latest/checks/aws/)
- [Checkov Policies](https://www.checkov.io/5.Policy%20Index/terraform.html)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)

## Support

For issues or questions:
- Check linter documentation
- Review configuration files
- Ask in team chat
- Create GitHub issue
