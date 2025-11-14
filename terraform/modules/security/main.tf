# Security Module
# This module can be used for centralized security configurations such as:
# - AWS WAF rules
# - GuardDuty configurations
# - Security Hub settings
# - AWS Config rules
# - Inspector assessments

# Placeholder - add security resources here when needed

# Example usage of variables (commented out for now):
# resource "aws_guardduty_detector" "main" {
#   enable = true
#   tags   = merge(var.tags, { Name = "${var.cluster_name}-guardduty" })
# }
