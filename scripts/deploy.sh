#!/bin/bash
# Deploy EKS infrastructure

set -e

ENVIRONMENT="${1:-dev}"
TERRAFORM_DIR="terraform/environments/$ENVIRONMENT"

echo "🚀 Deploying EKS infrastructure for environment: $ENVIRONMENT"

# Check if terraform directory exists
if [ ! -d "$TERRAFORM_DIR" ]; then
    echo "❌ Error: Environment directory not found: $TERRAFORM_DIR"
    exit 1
fi

cd "$TERRAFORM_DIR"

# Check for terraform.tfvars
if [ ! -f "terraform.tfvars" ]; then
    echo "⚠️  Warning: terraform.tfvars not found"
    echo "📝 Please create terraform.tfvars from terraform.tfvars.example"
    echo ""
    echo "Required variables:"
    echo "  - route53_zone_id (Get with: aws route53 list-hosted-zones)"
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Initialize Terraform
echo "🔧 Initializing Terraform..."
terraform init

# Validate configuration
echo "✅ Validating Terraform configuration..."
terraform validate

# Plan deployment
echo "📋 Planning deployment..."
terraform plan -out=tfplan

# Prompt for apply
echo ""
read -p "Apply this plan? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Deployment cancelled"
    exit 1
fi

# Apply
echo "🚀 Applying Terraform configuration..."
terraform apply tfplan

# Save outputs
echo "💾 Saving outputs..."
terraform output > outputs.txt

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📊 Outputs saved to: $TERRAFORM_DIR/outputs.txt"
echo ""
echo "Next steps:"
echo "1. Configure kubectl:"
terraform output -raw configure_kubectl
echo ""
echo "2. Verify cluster:"
echo "   kubectl get nodes"
echo ""
echo "3. Check CloudWatch Container Insights:"
echo "   AWS Console → CloudWatch → Container Insights"
echo ""
terraform output -raw cloudwatch_dashboard_url
