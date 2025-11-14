# TFLint Configuration
# https://github.com/terraform-linters/tflint

config {
  call_module_type    = "all"
  force               = false
  disabled_by_default = false
}

# Exclude root directory from module structure checks
# (terraform/ is not a module, it's a workspace root)
rule "terraform_standard_module_structure" {
  enabled = true

  # This will be checked for modules/*, environments/*, bootstrap/*
  # but not for the root terraform/ directory
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "aws" {
  enabled = true
  version = "0.31.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# Best Practices Rules
rule "terraform_naming_convention" {
  enabled = true
  format  = "snake_case"
}

rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_typed_variables" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_comment_syntax" {
  enabled = true
}

rule "terraform_deprecated_index" {
  enabled = true
}

rule "terraform_deprecated_interpolation" {
  enabled = true
}

rule "terraform_module_pinned_source" {
  enabled = true
  style   = "semver"
}

rule "terraform_standard_module_structure" {
  enabled = true
}

# AWS Specific Rules
rule "aws_resource_missing_tags" {
  enabled = true
  tags    = ["Environment", "Project", "ManagedBy"]
}

rule "aws_instance_invalid_type" {
  enabled = true
}

rule "aws_db_instance_invalid_type" {
  enabled = true
}

rule "aws_iam_policy_document_gov_friendly_arns" {
  enabled = false  # Not applicable for non-gov regions
}
