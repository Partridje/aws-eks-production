###############################################################################
# TFLint Configuration
# https://github.com/terraform-linters/tflint
###############################################################################

config {
  # Enable module inspection (v0.54.0+)
  call_module_type = "all"  # all, local, or none

  # Force all checks to be enabled
  force = false

  # Disable specific rules if needed
  disabled_by_default = false
}

###############################################################################
# AWS Plugin
###############################################################################

plugin "aws" {
  enabled = true
  version = "0.32.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"

  # Deep checking (makes AWS API calls to validate)
  deep_check = false  # Set to true for production
}

###############################################################################
# Terraform Rules
###############################################################################

# Disallow deprecated interpolation syntax
rule "terraform_deprecated_interpolation" {
  enabled = true
}

# Disallow legacy dot index syntax
rule "terraform_deprecated_index" {
  enabled = true
}

# Disallow variables, data sources, and locals that are declared but never used
rule "terraform_unused_declarations" {
  enabled = false  # Disabled - may be used in future or by consumers
}

# Require documentation for all variables
rule "terraform_documented_variables" {
  enabled = true
}

# Require documentation for all outputs
rule "terraform_documented_outputs" {
  enabled = true
}

# Disallow // comments in favor of #
rule "terraform_comment_syntax" {
  enabled = true
}

# Require that all providers have version constraints
rule "terraform_required_version" {
  enabled = true
}

# Require that all providers have version constraints
rule "terraform_required_providers" {
  enabled = true
}

# Ensure naming conventions are followed
rule "terraform_naming_convention" {
  enabled = false  # Disabled - allow flexibility for AWS managed policy names

  # Variable names should be snake_case
  variable {
    format = "snake_case"
  }

  # Output names should be snake_case
  output {
    format = "snake_case"
  }

  # Local names should be snake_case
  locals {
    format = "snake_case"
  }

  # Module names should be snake_case
  module {
    format = "snake_case"
  }
}

# Ensure consistent module sources
rule "terraform_module_version" {
  enabled = false  # We're using local modules
}

# Disallow specifying a git or mercurial repository as a module source without pinning to a version
rule "terraform_module_pinned_source" {
  enabled = true
}

###############################################################################
# AWS-Specific Rules
###############################################################################

# Ensure all resources have tags (informational only)
rule "aws_resource_missing_tags" {
  enabled = false  # Disabled - tags are optional, common_tags cover most cases
  tags = [
    "Name",
    "Environment",
    "Project",
    "ManagedBy"
  ]
}

# Warn about invalid instance types
rule "aws_instance_invalid_type" {
  enabled = true
}

# Warn about previous generation instance types
rule "aws_instance_previous_type" {
  enabled = true
}

# Check S3 bucket configuration
rule "aws_s3_bucket_name" {
  enabled = true
}

# Check for valid IAM policy documents
rule "aws_iam_policy_document_gov_friendly_arns" {
  enabled = false  # We're not in GovCloud
}

# Check for valid IAM role assume role policy
rule "aws_iam_role_policy_gov_friendly_arns" {
  enabled = false  # We're not in GovCloud
}
