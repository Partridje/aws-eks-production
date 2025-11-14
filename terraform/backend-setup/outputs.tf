output "s3_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.arn
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for state locking"
  value       = aws_dynamodb_table.terraform_locks.name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table for state locking"
  value       = aws_dynamodb_table.terraform_locks.arn
}

output "kms_key_id" {
  description = "ID of the KMS key for state encryption (if enabled)"
  value       = var.enable_kms_encryption ? aws_kms_key.terraform_state[0].id : null
}

output "kms_key_arn" {
  description = "ARN of the KMS key for state encryption (if enabled)"
  value       = var.enable_kms_encryption ? aws_kms_key.terraform_state[0].arn : null
}

output "backend_config" {
  description = "Backend configuration to use in other Terraform projects"
  value = templatefile("${path.module}/backend_template.tftpl", {
    bucket         = aws_s3_bucket.terraform_state.id
    region         = var.region
    dynamodb_table = aws_dynamodb_table.terraform_locks.name
    kms_key_id     = var.enable_kms_encryption ? aws_kms_key.terraform_state[0].id : ""
    encrypt        = var.enable_kms_encryption
  })
}

output "backend_config_summary" {
  description = "Summary of backend configuration"
  value = {
    s3_bucket      = aws_s3_bucket.terraform_state.id
    dynamodb_table = aws_dynamodb_table.terraform_locks.name
    region         = var.region
    encryption     = var.enable_kms_encryption ? "KMS" : "AES256"
  }
}
