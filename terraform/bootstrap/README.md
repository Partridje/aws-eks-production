# Terraform Backend Bootstrap

This directory contains Terraform configuration to create the infrastructure needed for remote state management.

## What This Creates

- **S3 Bucket** for storing Terraform state files
  - Versioning enabled
  - Encryption enabled (AES256)
  - Public access blocked
  - Lifecycle policy for old versions
  - Optional access logging

- **DynamoDB Table** for state locking
  - Pay-per-request billing
  - Point-in-time recovery enabled
  - Server-side encryption enabled

## Prerequisites

- AWS CLI configured with credentials
- Terraform >= 1.13.5 installed
- Appropriate AWS permissions to create S3 and DynamoDB resources

## Usage

### Option 1: Using Bash Script (Recommended for First Time)

```bash
cd scripts
./setup-backend.sh
```

This script will create all necessary resources and configure them properly.

### Option 2: Using Terraform Bootstrap

```bash
cd terraform/bootstrap

# Review and customize variables if needed
terraform init

# Review the plan
terraform plan

# Create the backend infrastructure
terraform apply
```

## Important Notes

1. **Run This Once**: You only need to create these resources once per AWS account/region
2. **Local State**: The bootstrap configuration uses local state (stored in `terraform.tfstate`)
3. **Backup**: Keep the local `terraform.tfstate` file safe after running bootstrap
4. **Prevent Destroy**: Resources have `prevent_destroy` lifecycle to avoid accidental deletion

## After Bootstrap

Once the backend infrastructure is created, configure your main Terraform configurations to use it:

```hcl
terraform {
  backend "s3" {
    bucket         = "partridje-terraform-state-eu-west-1"
    key            = "eks-production/dev/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

Then initialize:

```bash
terraform init -reconfigure
```

## Customization

Edit `variables.tf` or create a `terraform.tfvars` file:

```hcl
aws_region          = "eu-west-1"
state_bucket_name   = "my-custom-terraform-state-bucket"
dynamodb_table_name = "my-terraform-locks"
enable_logging      = true
```

## Cleanup

⚠️ **WARNING**: Deleting these resources will remove your Terraform state!

To remove the backend infrastructure (only if you're absolutely sure):

1. Remove `prevent_destroy` lifecycle blocks from `main.tf`
2. Run `terraform destroy`
3. Manually empty and delete the S3 bucket if needed

## Security Best Practices

✅ **Implemented:**
- Bucket versioning for state file recovery
- Encryption at rest for S3 and DynamoDB
- Public access blocking on S3
- DynamoDB point-in-time recovery
- Lifecycle policies for cost optimization
- Resource tagging for organization

🔒 **Additional Recommendations:**
- Use AWS Organizations SCPs to prevent deletion
- Enable CloudTrail logging for audit
- Set up AWS Backup for additional protection
- Use IAM policies to restrict access to state files

## Troubleshooting

### Bucket Already Exists
If the bucket name is already taken, change `state_bucket_name` in `variables.tf`.

### DynamoDB Table Already Exists
The script/terraform will skip creation if resources already exist.

### Permission Denied
Ensure your AWS credentials have permissions for:
- `s3:CreateBucket`, `s3:PutBucketVersioning`, etc.
- `dynamodb:CreateTable`, `dynamodb:DescribeTable`, etc.

## Cost Estimate

- **S3 Bucket**: ~$0.01-0.05/month (for small state files)
- **DynamoDB Table**: ~$0.00/month (pay-per-request, minimal usage)
- **Total**: < $0.10/month typically

## References

- [Terraform S3 Backend Documentation](https://developer.hashicorp.com/terraform/language/settings/backends/s3)
- [AWS S3 Versioning](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Versioning.html)
- [DynamoDB Point-in-Time Recovery](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/PointInTimeRecovery.html)
