#!/bin/bash
# Setup Git hooks for Terraform validation
# Run this script to install pre-commit and pre-push hooks

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOKS_DIR="$PROJECT_ROOT/.git/hooks"

echo "🪝 Setting up Git hooks for Terraform validation..."
echo ""

# Check if git repository
if [ ! -d "$PROJECT_ROOT/.git" ]; then
    echo "❌ Error: Not a git repository"
    exit 1
fi

# Create hooks directory if it doesn't exist
mkdir -p "$HOOKS_DIR"

# Pre-commit hook
echo "📝 Installing pre-commit hook..."
cat > "$HOOKS_DIR/pre-commit" << 'EOF'
#!/bin/bash
# Git pre-commit hook for Terraform validation

set -e

echo "🔍 Running Terraform pre-commit checks..."

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

FAILED=0

if ! command -v terraform &> /dev/null; then
    echo -e "${RED}❌ Terraform is not installed${NC}"
    exit 1
fi

echo ""
echo "🎨 Checking Terraform formatting..."
if terraform fmt -check -recursive terraform/ > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Terraform formatting is correct${NC}"
else
    echo -e "${RED}❌ Terraform files need formatting${NC}"
    echo ""
    echo "Running terraform fmt..."
    terraform fmt -recursive terraform/
    echo ""
    echo -e "${YELLOW}⚠️  Files formatted. Please review and commit again.${NC}"
    FAILED=1
fi

echo ""
echo "🔧 Validating Terraform configurations..."

for ENV_DIR in terraform/environments/*/; do
    if [ -d "$ENV_DIR" ]; then
        ENV_NAME=$(basename "$ENV_DIR")
        echo "  Validating: $ENV_NAME"

        cd "$ENV_DIR"

        if [ ! -d ".terraform" ]; then
            echo "  Initializing..."
            terraform init -backend=false > /dev/null 2>&1 || {
                echo -e "${RED}  ❌ Init failed${NC}"
                FAILED=1
                cd - > /dev/null
                continue
            }
        fi

        if terraform validate > /dev/null 2>&1; then
            echo -e "${GREEN}  ✅ Valid${NC}"
        else
            echo -e "${RED}  ❌ Invalid${NC}"
            terraform validate
            FAILED=1
        fi

        cd - > /dev/null
    fi
done

echo ""

if [ $FAILED -eq 1 ]; then
    echo -e "${RED}❌ Pre-commit checks failed${NC}"
    exit 1
else
    echo -e "${GREEN}✅ All checks passed!${NC}"
    exit 0
fi
EOF

chmod +x "$HOOKS_DIR/pre-commit"
echo "✅ Pre-commit hook installed"

echo ""

# Pre-push hook
echo "📤 Installing pre-push hook..."
cat > "$HOOKS_DIR/pre-push" << 'EOF'
#!/bin/bash
# Git pre-push hook for comprehensive Terraform checks

set -e

echo "🚀 Running Terraform pre-push checks..."

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

FAILED=0

if ! command -v terraform &> /dev/null; then
    echo -e "${RED}❌ Terraform is not installed${NC}"
    exit 1
fi

echo ""
echo "🎨 Checking formatting..."
terraform fmt -check -recursive terraform/ > /dev/null 2>&1 || FAILED=1

echo "🔧 Validating all environments..."
for ENV_DIR in terraform/environments/*/; do
    if [ -d "$ENV_DIR" ]; then
        ENV_NAME=$(basename "$ENV_DIR")
        cd "$ENV_DIR"
        [ ! -d ".terraform" ] && terraform init -backend=false > /dev/null 2>&1
        terraform validate > /dev/null 2>&1 || FAILED=1
        cd - > /dev/null
    fi
done

echo ""

if [ $FAILED -eq 1 ]; then
    echo -e "${RED}❌ Pre-push checks failed${NC}"
    echo "To skip: git push --no-verify"
    exit 1
else
    echo -e "${GREEN}✅ All checks passed!${NC}"
    exit 0
fi
EOF

chmod +x "$HOOKS_DIR/pre-push"
echo "✅ Pre-push hook installed"

echo ""
echo "🎉 Git hooks installed successfully!"
echo ""
echo "Hooks installed:"
echo "  - pre-commit: Runs terraform fmt + validate before commit"
echo "  - pre-push:   Runs comprehensive checks before push"
echo ""
echo "To skip hooks (not recommended):"
echo "  git commit --no-verify"
echo "  git push --no-verify"
echo ""
echo "Test the hooks:"
echo "  1. Make a change to a .tf file"
echo "  2. git add <file>"
echo "  3. git commit -m 'test'"
echo "  4. Hooks will run automatically"
