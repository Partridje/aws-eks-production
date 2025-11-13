# AWS EKS Production Infrastructure

Production-ready AWS EKS infrastructure with hybrid observability approach (AWS CloudWatch + in-cluster Prometheus/Grafana) and full DevOps/SRE best practices.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                          AWS Cloud                               │
│                                                                   │
│  ┌──────────────┐         ┌────────────────────────────┐        │
│  │   Route53    │────────▶│    Application Load        │        │
│  │ devseatit.com│         │       Balancer             │        │
│  └──────────────┘         └────────────────────────────┘        │
│                                      │                            │
│  ┌──────────────────────────────────┴───────────────────────┐   │
│  │                    EKS Cluster                           │   │
│  │                                                           │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │   │
│  │  │   Ingress    │  │   ArgoCD     │  │  Prometheus  │   │   │
│  │  │   NGINX      │  │              │  │   Grafana    │   │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘   │   │
│  │                                                           │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │   │
│  │  │   Frontend   │  │   Backend    │  │  Fluent Bit  │   │   │
│  │  │   (Nginx)    │  │  (FastAPI)   │  │  X-Ray       │   │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘   │   │
│  │                            │                              │   │
│  └────────────────────────────┼──────────────────────────────┘   │
│                               │                                   │
│  ┌────────────────────────────┴──────────────────────────────┐   │
│  │  CloudWatch                   │         RDS PostgreSQL    │   │
│  │  - Container Insights         │         Multi-AZ          │   │
│  │  - Logs                        │         Encrypted         │   │
│  │  - Alarms                      └───────────────────────────┘   │
│  │  - X-Ray Traces                                            │   │
│  └────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Key Features

### Infrastructure
- **Multi-AZ VPC** with public, private, and database subnets
- **EKS 1.30** with managed node groups (Spot + On-Demand)
- **Cluster Autoscaler** for automatic node scaling
- **RDS PostgreSQL** Multi-AZ with automated backups
- **VPC Endpoints** to reduce NAT costs
- **KMS encryption** for EKS secrets and RDS

### Observability - Hybrid Approach

#### AWS Native (Production-Grade)
- **CloudWatch Container Insights**: Cluster, node, and pod metrics
- **CloudWatch Logs**: Centralized logging via Fluent Bit
- **AWS X-Ray**: Distributed tracing
- **CloudWatch Alarms**: Automated alerting via SNS
- **CloudWatch Dashboards**: Real-time operational visibility

#### In-Cluster (Development & Custom Metrics)
- **Prometheus**: Custom application metrics
- **Grafana**: Unified dashboards (CloudWatch + Prometheus data sources)
- **ServiceMonitors**: Kubernetes-native metric collection

### Why Hybrid?
✅ Best of both worlds
✅ AWS managed services = zero operational overhead for core metrics
✅ In-cluster Prometheus = demonstrates Kubernetes observability expertise
✅ Easy migration path to fully managed (Amazon Managed Prometheus/Grafana)
✅ Cost-optimized for demo, production-ready architecture

### Security
- **IRSA (IAM Roles for Service Accounts)** - no static credentials
- **Pod Security Standards** - restricted mode enforced
- **Network Policies** - least privilege network access
- **Secrets Manager** integration for sensitive data
- **TLS certificates** via cert-manager and Let's Encrypt

### GitOps
- **ArgoCD** for continuous deployment
- **App of Apps** pattern
- Automated sync from Git repository

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.5.0
- kubectl >= 1.28
- Helm >= 3.12
- Domain configured in Route53 (devseatit.com)

## Quick Start

### 1. Setup Backend State Storage

```bash
# Create S3 bucket for Terraform state
aws s3api create-bucket \
  --bucket partridje-terraform-state-eu-west-1 \
  --region eu-west-1 \
  --create-bucket-configuration LocationConstraint=eu-west-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket partridje-terraform-state-eu-west-1 \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket partridje-terraform-state-eu-west-1 \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region eu-west-1
```

### 2. Get Route53 Hosted Zone ID

```bash
# List hosted zones
aws route53 list-hosted-zones

# Get specific zone ID for devseatit.com
aws route53 list-hosted-zones --query "HostedZones[?Name=='devseatit.com.'].Id" --output text
```

### 3. Configure Terraform Variables

```bash
cd terraform/environments/dev

# Copy example tfvars
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your Route53 zone ID
vim terraform.tfvars
```

### 4. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Plan deployment
terraform plan

# Apply (this will take 15-20 minutes)
terraform apply

# Save outputs
terraform output > outputs.txt
```

### 5. Configure kubectl

```bash
# Update kubeconfig
aws eks update-kubeconfig --region eu-west-1 --name eks-prod-dev

# Verify connection
kubectl get nodes
kubectl get pods --all-namespaces
```

### 6. Verify CloudWatch Container Insights

```bash
# Check if CloudWatch addon is installed
kubectl get pods -n amazon-cloudwatch

# View Container Insights in AWS Console
# Navigate to: CloudWatch > Container Insights > Performance monitoring
```

## Accessing Services

### Grafana
- URL: https://grafana.devseatit.com
- Data Sources:
  - CloudWatch (default) - AWS native metrics
  - Prometheus - Custom application metrics

### ArgoCD
- URL: https://argocd.devseatit.com
- Initial password: `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`

### Demo Application
- Frontend: https://demo.devseatit.com
- Backend API: https://api.devseatit.com
- API Docs: https://api.devseatit.com/docs

## Observability

### CloudWatch Container Insights
Access via AWS Console:
1. Go to CloudWatch > Container Insights
2. Select your cluster: `eks-prod-dev`
3. View cluster, node, and pod metrics

### CloudWatch Logs
- Application logs: `/aws/eks/eks-prod-dev/application`
- EKS cluster logs: `/aws/eks/eks-prod-dev/cluster`
- Fluent Bit logs: `/aws/eks/eks-prod-dev/fluent-bit`

### CloudWatch Alarms
Alarms configured for:
- High CPU utilization (nodes/pods)
- High memory utilization (nodes/pods)
- Failed nodes
- RDS CPU/storage/connections

### X-Ray Distributed Tracing
Access via AWS Console:
1. Go to X-Ray > Service map
2. View traces and performance bottlenecks

### Prometheus + Grafana
- Custom application metrics
- In-cluster resource monitoring
- Multi-datasource dashboards

## Cost Estimation

### Monthly Costs (eu-west-1, approximate)

#### Infrastructure
- EKS Control Plane: €73
- EC2 Nodes (3x t3.medium on-demand): ~€75
- EC2 Nodes (2x t3.medium spot avg): ~€25
- NAT Gateways (3x): ~€100
- RDS db.t3.medium Multi-AZ: ~€120
- EBS volumes (gp3, ~100GB): ~€10

#### Observability
- CloudWatch Logs (7 days retention): ~€20
- CloudWatch Metrics (Container Insights): ~€10
- X-Ray traces: ~€5
- CloudWatch Alarms: minimal

**Total: ~€438/month**

### Cost Optimization Tips
✅ Use spot instances (already configured)
✅ Short CloudWatch Logs retention (7 days)
✅ VPC endpoints reduce NAT costs
✅ Right-size instances based on actual usage
✅ Consider Reserved Instances for production

## Migration to Fully Managed Observability

See [docs/PRODUCTION_MIGRATION.md](docs/PRODUCTION_MIGRATION.md) for detailed guide on migrating to:
- Amazon Managed Prometheus (AMP)
- Amazon Managed Grafana (AMG)
- Benefits and cost comparison

## Documentation

- [ARCHITECTURE.md](docs/ARCHITECTURE.md) - Detailed architecture decisions
- [OBSERVABILITY.md](docs/OBSERVABILITY.md) - Observability deep dive
- [RUNBOOK.md](docs/RUNBOOK.md) - Operational runbook
- [PRODUCTION_MIGRATION.md](docs/PRODUCTION_MIGRATION.md) - Migration to fully managed

## CI/CD

GitHub Actions workflows:
- `terraform.yml` - Infrastructure deployment
- `build-push.yml` - Build and push Docker images
- `argocd-sync.yml` - Application deployment

## Cleanup

```bash
# Destroy infrastructure (will prompt for confirmation)
cd terraform/environments/dev
terraform destroy

# Delete S3 bucket (after destroying infrastructure)
aws s3 rm s3://partridje-terraform-state-eu-west-1 --recursive
aws s3api delete-bucket --bucket partridje-terraform-state-eu-west-1 --region eu-west-1

# Delete DynamoDB table
aws dynamodb delete-table --table-name terraform-state-lock --region eu-west-1
```

## Support

For issues or questions:
- Open an issue in this repository
- Email: tcytcerov@gmail.com

## License

MIT

---

**Built with ❤️ using Terraform, EKS, and AWS best practices**
