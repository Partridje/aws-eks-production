.PHONY: help fmt validate backend-init backend-plan backend-apply backend-destroy install-hooks check-aws clean

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

help: ## Show this help message
	@echo "$(BLUE)EKS GitOps Infrastructure - Available Commands$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "$(GREEN)%-20s$(NC) %s\n", $$1, $$2}'

fmt: ## Format all Terraform files
	@echo "$(BLUE)Formatting Terraform files...$(NC)"
	@terraform fmt -recursive .
	@echo "$(GREEN)✓ Formatting complete$(NC)"

validate: ## Validate all Terraform configurations
	@echo "$(BLUE)Validating Terraform configurations...$(NC)"
	@for dir in terraform/backend-setup terraform/environments/dev terraform/environments/prod; do \
		if [ -f "$$dir/main.tf" ]; then \
			echo "$(YELLOW)Validating $$dir...$(NC)"; \
			cd $$dir && terraform init -backend=false > /dev/null 2>&1 && terraform validate && cd - > /dev/null; \
		fi \
	done
	@echo "$(GREEN)✓ Validation complete$(NC)"

backend-init: ## Initialize backend-setup (one-time operation)
	@echo "$(BLUE)Initializing backend-setup...$(NC)"
	@cd terraform/backend-setup && terraform init
	@echo "$(GREEN)✓ Backend setup initialized$(NC)"

backend-plan: ## Plan backend infrastructure changes
	@echo "$(BLUE)Planning backend infrastructure...$(NC)"
	@cd terraform/backend-setup && terraform plan
	@echo "$(YELLOW)⚠ Review the plan carefully before applying$(NC)"

backend-apply: ## Apply backend infrastructure (⚠️  ONE-TIME ONLY)
	@echo "$(RED)⚠️  WARNING: This will create the Terraform backend infrastructure!$(NC)"
	@echo "$(YELLOW)This should only be run ONCE during initial setup.$(NC)"
	@read -p "Are you sure you want to continue? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		cd terraform/backend-setup && terraform apply; \
		echo "$(GREEN)✓ Backend infrastructure created$(NC)"; \
		echo "$(BLUE)Copy the backend configuration from outputs to your environment backend.tf files$(NC)"; \
	else \
		echo "$(YELLOW)Cancelled.$(NC)"; \
	fi

backend-output: ## Show backend configuration outputs
	@echo "$(BLUE)Backend Configuration:$(NC)"
	@cd terraform/backend-setup && terraform output -raw backend_config

backend-destroy: ## Destroy backend infrastructure (⚠️  DANGEROUS)
	@echo "$(RED)⚠️  DANGER: This will destroy the Terraform backend!$(NC)"
	@echo "$(RED)This will delete all state files and lock tables!$(NC)"
	@echo "$(YELLOW)Make sure you have backups and all environments are destroyed first.$(NC)"
	@read -p "Type 'destroy-backend' to confirm: " confirm; \
	if [ "$$confirm" = "destroy-backend" ]; then \
		cd terraform/backend-setup && terraform destroy; \
	else \
		echo "$(YELLOW)Cancelled.$(NC)"; \
	fi

install-hooks: ## Install pre-commit hooks
	@echo "$(BLUE)Installing pre-commit hooks...$(NC)"
	@if command -v pre-commit > /dev/null; then \
		pre-commit install; \
		pre-commit install --hook-type commit-msg; \
		echo "$(GREEN)✓ Pre-commit hooks installed$(NC)"; \
	else \
		echo "$(RED)✗ pre-commit is not installed$(NC)"; \
		echo "$(YELLOW)Install with: pip install pre-commit$(NC)"; \
	fi

check-aws: ## Verify AWS credentials and configuration
	@echo "$(BLUE)Checking AWS configuration...$(NC)"
	@if command -v aws > /dev/null; then \
		echo "$(GREEN)✓ AWS CLI installed$(NC)"; \
		aws --version; \
		echo ""; \
		echo "$(BLUE)Current AWS Identity:$(NC)"; \
		aws sts get-caller-identity; \
	else \
		echo "$(RED)✗ AWS CLI is not installed$(NC)"; \
	fi

check-terraform: ## Verify Terraform installation
	@echo "$(BLUE)Checking Terraform installation...$(NC)"
	@if command -v terraform > /dev/null; then \
		echo "$(GREEN)✓ Terraform installed$(NC)"; \
		terraform version; \
	else \
		echo "$(RED)✗ Terraform is not installed$(NC)"; \
		echo "$(YELLOW)Install from: https://www.terraform.io/downloads$(NC)"; \
	fi

check-prereqs: check-terraform check-aws ## Check all prerequisites
	@echo ""
	@echo "$(GREEN)✓ All prerequisites checked$(NC)"

clean: ## Clean up temporary files and caches
	@echo "$(BLUE)Cleaning up...$(NC)"
	@find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name ".terraform.lock.hcl" -delete 2>/dev/null || true
	@find . -type f -name "*.tfstate.backup" -delete 2>/dev/null || true
	@echo "$(GREEN)✓ Cleanup complete$(NC)"

init-dev: ## Initialize dev environment (after backend setup)
	@echo "$(BLUE)Initializing dev environment...$(NC)"
	@if [ ! -f "terraform/environments/dev/backend.tf" ]; then \
		echo "$(RED)✗ backend.tf not found in dev environment$(NC)"; \
		echo "$(YELLOW)Run 'make backend-output' and create backend.tf first$(NC)"; \
		exit 1; \
	fi
	@cd terraform/environments/dev && terraform init
	@echo "$(GREEN)✓ Dev environment initialized$(NC)"

init-prod: ## Initialize prod environment (after backend setup)
	@echo "$(BLUE)Initializing prod environment...$(NC)"
	@if [ ! -f "terraform/environments/prod/backend.tf" ]; then \
		echo "$(RED)✗ backend.tf not found in prod environment$(NC)"; \
		echo "$(YELLOW)Run 'make backend-output' and create backend.tf first$(NC)"; \
		exit 1; \
	fi
	@cd terraform/environments/prod && terraform init
	@echo "$(GREEN)✓ Prod environment initialized$(NC)"

###############################################################################
# Linting and Code Quality
###############################################################################

check-linters: ## Check if linters are installed
	@echo "$(BLUE)Checking linters installation...$(NC)"
	@command -v tflint >/dev/null 2>&1 && echo "$(GREEN)✓ TFLint installed$(NC)" || echo "$(YELLOW)✗ TFLint not installed (brew install tflint)$(NC)"
	@command -v tfsec >/dev/null 2>&1 && echo "$(GREEN)✓ tfsec installed$(NC)" || echo "$(YELLOW)✗ tfsec not installed (brew install tfsec)$(NC)"
	@command -v checkov >/dev/null 2>&1 && echo "$(GREEN)✓ checkov installed$(NC)" || echo "$(YELLOW)✗ checkov not installed (pip3 install checkov)$(NC)"
	@command -v terraform-docs >/dev/null 2>&1 && echo "$(GREEN)✓ terraform-docs installed$(NC)" || echo "$(YELLOW)✗ terraform-docs not installed (brew install terraform-docs)$(NC)"

tflint-init: ## Initialize TFLint (download plugins)
	@echo "$(BLUE)Initializing TFLint...$(NC)"
	@if command -v tflint > /dev/null; then \
		tflint --init; \
		echo "$(GREEN)✓ TFLint initialized$(NC)"; \
	else \
		echo "$(RED)✗ TFLint is not installed$(NC)"; \
		echo "$(YELLOW)Install with: brew install tflint$(NC)"; \
		exit 1; \
	fi

tflint: ## Run TFLint on all Terraform code
	@echo "$(BLUE)Running TFLint...$(NC)"
	@if command -v tflint > /dev/null; then \
		tflint --recursive --config=.tflint.hcl terraform/; \
		echo "$(GREEN)✓ TFLint checks passed$(NC)"; \
	else \
		echo "$(YELLOW)⚠ TFLint not installed, skipping$(NC)"; \
	fi

tfsec: ## Run tfsec security scanner
	@echo "$(BLUE)Running tfsec security scan...$(NC)"
	@if command -v tfsec > /dev/null; then \
		tfsec terraform/ --config-file=.tfsec.yml; \
		echo "$(GREEN)✓ tfsec security checks passed$(NC)"; \
	else \
		echo "$(YELLOW)⚠ tfsec not installed, skipping$(NC)"; \
	fi

checkov: ## Run checkov policy scanner
	@echo "$(BLUE)Running checkov policy scan...$(NC)"
	@if command -v checkov > /dev/null; then \
		checkov -d terraform/ --quiet --compact; \
		echo "$(GREEN)✓ checkov policy checks passed$(NC)"; \
	else \
		echo "$(YELLOW)⚠ checkov not installed, skipping$(NC)"; \
	fi

docs: ## Generate module documentation
	@echo "$(BLUE)Generating Terraform documentation...$(NC)"
	@if command -v terraform-docs > /dev/null; then \
		for dir in terraform/modules/*/; do \
			echo "$(YELLOW)Generating docs for $$dir$(NC)"; \
			terraform-docs markdown table $$dir > $$dir/README_AUTO.md; \
		done; \
		echo "$(GREEN)✓ Documentation generated$(NC)"; \
	else \
		echo "$(YELLOW)⚠ terraform-docs not installed, skipping$(NC)"; \
	fi

lint: tflint tfsec ## Run all linters (TFLint and tfsec)

lint-all: tflint tfsec checkov ## Run all linters including checkov

security-scan: tfsec checkov ## Run security scanners only
