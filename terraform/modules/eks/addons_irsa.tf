# EKS Add-ons IRSA Configuration
# This file contains resources to update EKS add-ons with IRSA roles
# after the IAM module has been created (to avoid circular dependencies)

# These will be applied separately after initial cluster creation
# Use: terraform apply -target=module.eks_addons_irsa

# Note: In Terraform 1.13+, we can use kubectl provider to update these
# For now, these are documented for manual application or use aws CLI:
#
# aws eks update-addon \
#   --cluster-name eks-prod-dev \
#   --addon-name aws-ebs-csi-driver \
#   --service-account-role-arn arn:aws:iam::ACCOUNT:role/eks-prod-dev-ebs-csi-controller
#
# aws eks update-addon \
#   --cluster-name eks-prod-dev \
#   --addon-name amazon-cloudwatch-observability \
#   --service-account-role-arn arn:aws:iam::ACCOUNT:role/eks-prod-dev-cloudwatch-agent
