# Quick Start Guide

## Prerequisites

Install required tools:
- [AWS CLI](https://aws.amazon.com/cli/) - configured with credentials
- [Terraform](https://www.terraform.io/downloads) >= 1.5.0
- [kubectl](https://kubernetes.io/docs/tasks/tools/) >= 1.28
- [Helm](https://helm.sh/docs/intro/install/) >= 3.12

## Step-by-Step Deployment

### 1. Setup AWS Backend

```bash
# Run the setup script
./scripts/setup-backend.sh
```

This creates:
- S3 bucket: `partridje-terraform-state-eu-west-1`
- DynamoDB table: `terraform-state-lock`

### 2. Get Route53 Hosted Zone ID

```bash
# List all hosted zones
aws route53 list-hosted-zones

# Get specific zone ID for devseatit.com
aws route53 list-hosted-zones \
  --query "HostedZones[?Name=='devseatit.com.'].Id" \
  --output text
```

Copy the Zone ID (format: `Z0123456789ABC`)

### 3. Configure Terraform Variables

```bash
cd terraform/environments/dev

# Copy example file
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
nano terraform.tfvars
```

Update `route53_zone_id` with your actual Zone ID.

### 4. Deploy Infrastructure

```bash
# Return to project root
cd ../../..

# Run deployment script
./scripts/deploy.sh dev
```

This will:
1. Initialize Terraform
2. Show deployment plan
3. Prompt for confirmation
4. Deploy infrastructure (15-20 minutes)

### 5. Configure kubectl

```bash
# Command will be shown in deployment output
aws eks update-kubeconfig --region eu-west-1 --name eks-prod-dev

# Verify connection
kubectl get nodes
kubectl get pods --all-namespaces
```

### 6. Verify CloudWatch Container Insights

```bash
# Check if addon pods are running
kubectl get pods -n amazon-cloudwatch

# Expected output:
# cloudwatch-agent-xxxxx        1/1     Running
# fluent-bit-xxxxx              1/1     Running
```

Go to AWS Console:
```
CloudWatch → Container Insights → Performance monitoring
```

Select cluster: `eks-prod-dev`

### 7. Access Services

#### Get Service URLs

All services will be available at subdomains of `devseatit.com`:

- **Grafana**: https://grafana.devseatit.com
- **ArgoCD**: https://argocd.devseatit.com
- **Demo App**: https://demo.devseatit.com
- **API**: https://api.devseatit.com

#### ArgoCD Initial Password

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

### 8. Verify Observability

#### CloudWatch Logs
```bash
# List log groups
aws logs describe-log-groups \
  --log-group-name-prefix /aws/eks/eks-prod-dev

# Tail application logs
aws logs tail /aws/eks/eks-prod-dev/application --follow
```

#### CloudWatch Dashboard

URL will be in Terraform outputs:
```bash
cd terraform/environments/dev
terraform output cloudwatch_dashboard_url
```

#### Grafana

1. Open https://grafana.devseatit.com
2. Default credentials: admin / (get from ArgoCD or Kubernetes secret)
3. Check datasources:
   - CloudWatch (default)
   - Prometheus
4. Browse dashboards

## Troubleshooting

### Issue: Terraform fails with "bucket does not exist"

**Solution**: Run `./scripts/setup-backend.sh` first

### Issue: Terraform fails with "Route53 zone not found"

**Solution**: Update `route53_zone_id` in `terraform.tfvars`

### Issue: kubectl cannot connect to cluster

**Solution**:
```bash
# Update kubeconfig
aws eks update-kubeconfig --region eu-west-1 --name eks-prod-dev

# Verify AWS credentials
aws sts get-caller-identity
```

### Issue: No metrics in CloudWatch Container Insights

**Solution**:
```bash
# Check addon installation
kubectl get pods -n amazon-cloudwatch

# Check addon status
aws eks describe-addon \
  --cluster-name eks-prod-dev \
  --addon-name amazon-cloudwatch-observability
```

### Issue: Pods stuck in Pending

**Solution**:
```bash
# Check node status
kubectl get nodes

# Check pod events
kubectl describe pod POD_NAME

# Check cluster autoscaler logs
kubectl logs -n kube-system deployment/cluster-autoscaler
```

## Cost Management

### Current Infrastructure Cost: ~€438/month

To reduce costs:

1. **Scale down node groups** (when not in use):
```bash
# In terraform.tfvars, set:
# on_demand_min_size = 0
# on_demand_desired_size = 0
# spot_min_size = 0
# spot_desired_size = 0

terraform apply
```

2. **Destroy infrastructure** (when not needed):
```bash
cd terraform/environments/dev
terraform destroy
```

## Next Steps

1. **Deploy demo applications** - See `kubernetes/apps/`
2. **Setup ArgoCD** - See `kubernetes/argocd/`
3. **Configure monitoring** - See [docs/OBSERVABILITY.md](docs/OBSERVABILITY.md)
4. **Review architecture** - See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
5. **Plan production migration** - See [docs/PRODUCTION_MIGRATION.md](docs/PRODUCTION_MIGRATION.md)

## Support

- **Documentation**: See `docs/` directory
- **Issues**: Open an issue in this repository
- **Email**: tcytcerov@gmail.com

## Cleanup

To destroy all infrastructure:

```bash
cd terraform/environments/dev
terraform destroy

# Optionally, delete backend resources
aws s3 rm s3://partridje-terraform-state-eu-west-1 --recursive
aws s3api delete-bucket --bucket partridje-terraform-state-eu-west-1 --region eu-west-1
aws dynamodb delete-table --table-name terraform-state-lock --region eu-west-1
```
