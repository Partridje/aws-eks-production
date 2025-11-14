# Terraform Bootstrap
# This configuration creates the S3 bucket and DynamoDB table for remote state
# Run this ONCE before using the main terraform configurations

terraform {
  required_version = ">= 1.13.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # WARNING: This uses local state initially
  # After running this, configure remote backend in main configurations
}

provider "aws" {
  region = var.aws_region
}

locals {
  common_tags = {
    Project     = "aws-eks-production"
    ManagedBy   = "Terraform"
    Purpose     = "TerraformState"
    Environment = "all"
  }
}

################################################################################
# S3 Bucket for Terraform State
################################################################################

resource "aws_s3_bucket" "terraform_state" {
  bucket = var.state_bucket_name

  tags = merge(local.common_tags, {
    Name = var.state_bucket_name
  })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "delete-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }

  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Optional: S3 Bucket for Access Logs
resource "aws_s3_bucket" "terraform_state_logs" {
  count  = var.enable_logging ? 1 : 0
  bucket = "${var.state_bucket_name}-logs"

  tags = merge(local.common_tags, {
    Name = "${var.state_bucket_name}-logs"
  })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_acl" "terraform_state_logs" {
  count  = var.enable_logging ? 1 : 0
  bucket = aws_s3_bucket.terraform_state_logs[0].id

  access_control_policy {
    grant {
      grantee {
        type = "Group"
        uri  = "http://acs.amazonaws.com/groups/s3/LogDelivery"
      }
      permission = "WRITE"
    }

    grant {
      grantee {
        type = "Group"
        uri  = "http://acs.amazonaws.com/groups/s3/LogDelivery"
      }
      permission = "READ_ACP"
    }

    owner {
      id = data.aws_canonical_user_id.current.id
    }
  }
}

resource "aws_s3_bucket_logging" "terraform_state" {
  count  = var.enable_logging ? 1 : 0
  bucket = aws_s3_bucket.terraform_state.id

  target_bucket = aws_s3_bucket.terraform_state_logs[0].id
  target_prefix = "terraform-state-logs/"
}

################################################################################
# DynamoDB Table for State Locking
################################################################################

resource "aws_dynamodb_table" "terraform_locks" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = merge(local.common_tags, {
    Name = var.dynamodb_table_name
  })

  lifecycle {
    prevent_destroy = true
  }
}

################################################################################
# Data Sources
################################################################################

data "aws_canonical_user_id" "current" {}
