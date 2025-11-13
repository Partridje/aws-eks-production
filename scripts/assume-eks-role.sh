#!/bin/bash
# Helper script to assume EKS IAM roles
# Usage: ./assume-eks-role.sh [admin|developer|viewer]

set -e

# Configuration
CLUSTER_NAME="eks-prod-dev"
AWS_REGION="eu-west-1"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to display usage
usage() {
    echo "Usage: $0 [admin|developer|viewer]"
    echo ""
    echo "Assumes the specified EKS IAM role and configures kubectl access"
    echo ""
    echo "Roles:"
    echo "  admin      - Full cluster access (system:masters)"
    echo "  developer  - Namespace-scoped access (can create/update resources)"
    echo "  viewer     - Read-only access across all namespaces"
    echo ""
    echo "Example:"
    echo "  $0 admin"
    exit 1
}

# Check arguments
if [ $# -ne 1 ]; then
    usage
fi

ROLE_TYPE=$1

# Validate role type
case $ROLE_TYPE in
    admin|developer|viewer)
        ;;
    *)
        echo -e "${RED}Error: Invalid role type '$ROLE_TYPE'${NC}"
        usage
        ;;
esac

# Construct role ARN and external ID
ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${CLUSTER_NAME}-${ROLE_TYPE}-role"
EXTERNAL_ID="${CLUSTER_NAME}-${ROLE_TYPE}"
SESSION_NAME="${ROLE_TYPE}-session-$(date +%s)"

echo -e "${YELLOW}🔐 Assuming EKS ${ROLE_TYPE} role...${NC}"
echo "Role ARN: $ROLE_ARN"
echo "External ID: $EXTERNAL_ID"
echo ""

# Assume role
CREDENTIALS=$(aws sts assume-role \
    --role-arn "$ROLE_ARN" \
    --role-session-name "$SESSION_NAME" \
    --external-id "$EXTERNAL_ID" \
    --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
    --output text)

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to assume role${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "1. Verify the role exists:"
    echo "   aws iam get-role --role-name ${CLUSTER_NAME}-${ROLE_TYPE}-role"
    echo ""
    echo "2. Check your IAM user/role has permission to assume the role"
    echo ""
    echo "3. Verify you have the correct AWS_PROFILE configured"
    exit 1
fi

# Parse credentials
export AWS_ACCESS_KEY_ID=$(echo $CREDENTIALS | awk '{print $1}')
export AWS_SECRET_ACCESS_KEY=$(echo $CREDENTIALS | awk '{print $2}')
export AWS_SESSION_TOKEN=$(echo $CREDENTIALS | awk '{print $3}')

# Update kubeconfig
echo -e "${YELLOW}📝 Updating kubeconfig...${NC}"
aws eks update-kubeconfig \
    --region "$AWS_REGION" \
    --name "$CLUSTER_NAME" \
    --alias "${CLUSTER_NAME}-${ROLE_TYPE}"

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to update kubeconfig${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ Successfully assumed ${ROLE_TYPE} role!${NC}"
echo ""
echo "Credentials exported to current shell session:"
echo "  AWS_ACCESS_KEY_ID=***${AWS_ACCESS_KEY_ID: -4}"
echo "  AWS_SECRET_ACCESS_KEY=***"
echo "  AWS_SESSION_TOKEN=***"
echo ""
echo "Kubeconfig updated. Current context:"
kubectl config current-context
echo ""

# Test access
echo -e "${YELLOW}🧪 Testing access...${NC}"
echo ""

case $ROLE_TYPE in
    admin)
        echo "Testing admin permissions:"
        kubectl auth can-i "*" "*" --all-namespaces && \
            echo -e "${GREEN}✅ Admin access confirmed${NC}" || \
            echo -e "${RED}❌ Admin access check failed${NC}"
        ;;
    developer)
        echo "Testing developer permissions:"
        kubectl auth can-i create deployment -n default && \
            echo -e "${GREEN}✅ Can create deployments in default namespace${NC}" || \
            echo -e "${RED}❌ Cannot create deployments${NC}"

        kubectl auth can-i delete namespace && \
            echo -e "${RED}❌ Can delete namespaces (unexpected!)${NC}" || \
            echo -e "${GREEN}✅ Cannot delete namespaces (expected)${NC}"
        ;;
    viewer)
        echo "Testing viewer permissions:"
        kubectl auth can-i get pods --all-namespaces && \
            echo -e "${GREEN}✅ Can view pods${NC}" || \
            echo -e "${RED}❌ Cannot view pods${NC}"

        kubectl auth can-i create deployment && \
            echo -e "${RED}❌ Can create deployments (unexpected!)${NC}" || \
            echo -e "${GREEN}✅ Cannot create deployments (expected)${NC}"
        ;;
esac

echo ""
echo -e "${YELLOW}📋 Quick commands:${NC}"
echo "  kubectl get nodes                    # View cluster nodes"
echo "  kubectl get pods --all-namespaces    # View all pods"
echo "  kubectl auth can-i <verb> <resource> # Check permissions"
echo ""
echo -e "${YELLOW}⏰ Note: These credentials expire in 1 hour${NC}"
echo ""
echo "To switch roles, run this script again with a different role type."
