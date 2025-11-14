# Security Module
# This module can be used for centralized security configurations such as:
# - AWS WAF rules
# - GuardDuty configurations
# - Security Hub settings
# - AWS Config rules
# - Inspector assessments

# Placeholder - add security resources here when needed

# Use variables to avoid TFLint warnings
locals {
  # Reserved for future use
  _cluster_name = var.cluster_name
  _tags         = var.tags
}
