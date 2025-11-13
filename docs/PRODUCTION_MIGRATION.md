# Production Migration Guide

## Overview

This document outlines the migration path from the current hybrid observability approach to a fully AWS-managed solution using:
- **Amazon Managed Service for Prometheus (AMP)**
- **Amazon Managed Grafana (AMG)**

## Current State (Demo/Development)

```
┌────────────────────────────────────────┐
│           EKS Cluster                   │
│                                        │
│  ┌──────────────────┐                 │
│  │   Prometheus     │                 │
│  │   (Self-hosted)  │                 │
│  │   - 2d retention │                 │
│  │   - Single pod   │                 │
│  └────────┬─────────┘                 │
│           │                            │
│  ┌────────▼─────────┐                 │
│  │   Grafana        │                 │
│  │   (Self-hosted)  │                 │
│  │   - 2 datasources│                 │
│  └──────────────────┘                 │
└────────────────────────────────────────┘

┌────────────────────────────────────────┐
│        AWS Managed Services            │
│                                        │
│  ┌──────────────────┐                 │
│  │  CloudWatch      │                 │
│  │  Container       │                 │
│  │  Insights        │                 │
│  └──────────────────┘                 │
│                                        │
│  ┌──────────────────┐                 │
│  │  X-Ray           │                 │
│  └──────────────────┘                 │
└────────────────────────────────────────┘
```

## Target State (Production)

```
┌────────────────────────────────────────┐
│           EKS Cluster                   │
│                                        │
│  ┌──────────────────┐                 │
│  │  Prometheus      │                 │
│  │  Agent           │ Remote Write    │
│  │  (Scraper only)  │─────────────┐   │
│  └──────────────────┘             │   │
└────────────────────────────────────┼───┘
                                     │
┌────────────────────────────────────┼───┐
│        AWS Managed Services        │   │
│                                    │   │
│  ┌──────────────────┐              │   │
│  │  CloudWatch      │              │   │
│  │  Container       │              │   │
│  │  Insights        │              │   │
│  └──────────────────┘              │   │
│                                    │   │
│  ┌──────────────────┐              │   │
│  │  X-Ray           │              │   │
│  └──────────────────┘              │   │
│                                    │   │
│  ┌──────────────────┐              │   │
│  │  Amazon Managed  │◀─────────────┘   │
│  │  Prometheus(AMP) │                  │
│  │  - 150d retention│                  │
│  │  - Auto-scaling  │                  │
│  └────────┬─────────┘                  │
│           │                            │
│  ┌────────▼─────────┐                  │
│  │  Amazon Managed  │                  │
│  │  Grafana (AMG)   │                  │
│  │  - 3 datasources │                  │
│  │  - HA, managed   │                  │
│  └──────────────────┘                  │
└────────────────────────────────────────┘
```

## Benefits of Fully Managed

### Operational Benefits
- ✅ **Zero Infrastructure Management** - No Prometheus/Grafana pods to maintain
- ✅ **Automatic Scaling** - AMP/AMG scale automatically
- ✅ **High Availability** - Built-in redundancy
- ✅ **Long-term Retention** - 150 days (AMP) vs 2 days (self-hosted)
- ✅ **AWS Support** - Included in AWS support plan
- ✅ **Reduced Attack Surface** - Less in-cluster components

### Cost Benefits (at scale)
- ✅ **No EC2 Costs** for Prometheus/Grafana pods
- ✅ **Pay Per Use** - Only pay for what you use
- ✅ **Better Pricing** at high volume
- ✅ **Reduced EBS** storage costs

### Security Benefits
- ✅ **AWS IAM Integration** - IRSA for access control
- ✅ **Encryption at Rest** - Automatic
- ✅ **VPC PrivateLink** - Private connectivity
- ✅ **Compliance** - SOC, PCI, HIPAA certified

## Migration Steps

### Phase 1: Setup AMP Workspace (No Downtime)

#### 1.1 Create AMP Workspace

```bash
aws amp create-workspace \
  --alias eks-prod-dev-metrics \
  --region eu-west-1
```

Save the workspace ID:
```bash
export AMP_WORKSPACE_ID="ws-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

#### 1.2 Create IAM Role for Remote Write

```terraform
# Add to terraform/modules/iam/main.tf

module "amp_remote_write_role" {
  source = "./irsa"

  role_name                 = "${var.cluster_name}-amp-remote-write"
  oidc_provider_arn         = aws_iam_openid_connect_provider.eks.arn
  oidc_provider_url         = var.cluster_oidc_issuer_url
  service_account_name      = "prometheus"
  service_account_namespace = "observability"

  policy_arns = []

  inline_policies = {
    amp_remote_write = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "aps:RemoteWrite",
            "aps:GetSeries",
            "aps:GetLabels",
            "aps:GetMetricMetadata"
          ]
          Resource = "arn:aws:aps:${var.aws_region}:*:workspace/${var.amp_workspace_id}"
        }
      ]
    })
  }

  tags = var.tags
}
```

Apply Terraform:
```bash
cd terraform/environments/dev
terraform apply
```

#### 1.3 Configure Prometheus Remote Write

Update Prometheus configuration:

```yaml
# kubernetes/observability/prometheus-operator/values.yaml

prometheus:
  prometheusSpec:
    # Keep local storage
    retention: 2d
    retentionSize: "2GB"

    # Add remote write to AMP
    remoteWrite:
      - url: https://aps-workspaces.eu-west-1.amazonaws.com/workspaces/${AMP_WORKSPACE_ID}/api/v1/remote_write
        sigv4:
          region: eu-west-1
        queueConfig:
          maxSamplesPerSend: 1000
          maxShards: 200
          capacity: 2500
        writeRelabelConfigs:
          # Only send custom app metrics to AMP
          - sourceLabels: [__name__]
            regex: 'http_.*|items_.*'
            action: keep

    serviceAccount:
      annotations:
        eks.amazonaws.com/role-arn: ${AMP_REMOTE_WRITE_ROLE_ARN}
```

Apply changes:
```bash
helm upgrade prometheus prometheus-community/kube-prometheus-stack \
  -n observability \
  -f kubernetes/observability/prometheus-operator/values.yaml
```

#### 1.4 Verify Data in AMP

Query AMP workspace:
```bash
# Get workspace endpoint
aws amp describe-workspace \
  --workspace-id $AMP_WORKSPACE_ID \
  --query 'workspace.prometheusEndpoint' \
  --output text
```

Test query (using awscurl or AWS SDK):
```bash
# Install awscurl: pip install awscurl
awscurl --service aps \
  --region eu-west-1 \
  "https://aps-workspaces.eu-west-1.amazonaws.com/workspaces/${AMP_WORKSPACE_ID}/api/v1/query?query=up"
```

### Phase 2: Setup Amazon Managed Grafana (No Downtime)

#### 2.1 Create AMG Workspace

Via AWS Console or CLI:
```bash
aws grafana create-workspace \
  --account-access-type CURRENT_ACCOUNT \
  --authentication-providers AWS_SSO \
  --permission-type SERVICE_MANAGED \
  --workspace-name eks-prod-dev-grafana \
  --workspace-role-arn arn:aws:iam::ACCOUNT_ID:role/AWSGrafanaServiceRole
```

Save workspace ID and URL.

#### 2.2 Configure Data Sources in AMG

1. Open AMG workspace URL
2. Go to Configuration → Data Sources
3. Add CloudWatch:
   - Authentication: Workspace IAM role
   - Default Region: eu-west-1
   - Mark as default

4. Add Amazon Managed Prometheus:
   - URL: https://aps-workspaces.eu-west-1.amazonaws.com/workspaces/${AMP_WORKSPACE_ID}
   - Authentication: SigV4 auth
   - Region: eu-west-1

5. Test both data sources

#### 2.3 Migrate Dashboards

Export dashboards from self-hosted Grafana:
```bash
# Port-forward to self-hosted Grafana
kubectl port-forward -n observability svc/grafana 3000:80

# Export dashboards (manually or via API)
curl -H "Authorization: Bearer ${GRAFANA_API_KEY}" \
  http://localhost:3000/api/dashboards/db/${DASHBOARD_UID}
```

Import to AMG:
1. Open AMG workspace
2. Dashboards → Import
3. Upload JSON files
4. Update data source references

#### 2.4 Parallel Testing

At this point you have:
- ✅ Self-hosted Prometheus + Grafana (still running)
- ✅ AMP receiving metrics via remote write
- ✅ AMG with migrated dashboards

Test AMG thoroughly before proceeding.

### Phase 3: Cutover (Minimal Downtime)

#### 3.1 Update DNS/URLs

Update ingress or DNS to point to AMG:
```yaml
# kubernetes/observability/grafana/ingress.yaml
# Change from self-hosted Grafana to redirect
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana-redirect
  annotations:
    nginx.ingress.kubernetes.io/permanent-redirect: "https://g-xxxxxxxxxx.grafana-workspace.eu-west-1.amazonaws.com"
spec:
  ...
```

#### 3.2 Update Alerting

Migrate alerts from Prometheus to:
- CloudWatch Alarms (for infrastructure)
- AMG Alerting (for custom metrics)

AMG Alerting Configuration:
```yaml
# In AMG UI: Alerting → Contact points
- SNS Topic: eks-prod-dev-cloudwatch-alarms
```

#### 3.3 Switch to Prometheus Agent Mode

Convert Prometheus from server to agent (scrape-only):

```yaml
# kubernetes/observability/prometheus-operator/values.yaml

prometheus:
  prometheusSpec:
    # Remove local storage
    retention: 1h  # Minimal local retention
    retentionSize: "500MB"

    # Agent mode settings
    walCompression: true

    # Keep remote write
    remoteWrite:
      - url: https://aps-workspaces.eu-west-1.amazonaws.com/workspaces/${AMP_WORKSPACE_ID}/api/v1/remote_write
        sigv4:
          region: eu-west-1

    # Reduce resources (agent mode needs less)
    resources:
      requests:
        memory: 200Mi
        cpu: 100m
      limits:
        memory: 1Gi
        cpu: 500m
```

Alternatively, use Prometheus Agent:
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus-agent prometheus-community/prometheus \
  --set mode=agent \
  --set remoteWrite.url=https://aps-workspaces.../api/v1/remote_write
```

#### 3.4 Remove Self-Hosted Grafana

```bash
# Delete Grafana deployment
helm uninstall grafana -n observability

# Cleanup PVCs
kubectl delete pvc -n observability grafana-storage
```

### Phase 4: Optimize & Monitor

#### 4.1 Right-size Prometheus Agent

Monitor resource usage:
```bash
kubectl top pod -n observability prometheus-agent-xxx
```

Adjust resources based on actual usage.

#### 4.2 Configure AMP Retention

```bash
# AMP retention is configurable (default 150 days)
# Adjust based on compliance requirements
```

#### 4.3 Setup AMP/AMG Monitoring

Create CloudWatch alarms for:
- AMP ingestion rate
- AMP storage used
- AMG active users

#### 4.4 Cost Monitoring

Track costs in Cost Explorer:
- Filter by service: Amazon Managed Service for Prometheus
- Filter by service: Amazon Managed Grafana

## Cost Comparison

### Self-Hosted (Current Demo)

```
EC2 costs (Prometheus/Grafana pods): €30/month
  - 2 pods on t3.medium nodes
  - ~0.5 vCPU, 1GB RAM each

EBS storage: €2/month
  - 10GB for Prometheus
  - 5GB for Grafana

Total: €32/month
```

### Fully Managed (Production)

```
Amazon Managed Prometheus:
  - Ingestion: €0.30 per million samples
    ~ 100K samples/min = €13/month
  - Query: €0.10 per million samples
    ~ 10M samples/month = €1/month
  - Storage: €0.03 per GB-month
    ~ 20GB = €0.60/month

Amazon Managed Grafana:
  - Editor license: €7.50/month per user
  - Viewer license: €5/month per user
  - Example: 2 editors + 5 viewers = €40/month

Total: €54.60/month (with 2 editors, 5 viewers)
```

### Breakeven Analysis

Self-hosted is cheaper for:
- ✅ Small teams (< 3 users)
- ✅ Low metric volume
- ✅ Short retention requirements

Managed is better for:
- ✅ Production workloads
- ✅ High availability requirements
- ✅ Long retention (> 30 days)
- ✅ Larger teams (> 5 users)
- ✅ Compliance requirements
- ✅ Operational efficiency

## Rollback Plan

If migration encounters issues:

### Quick Rollback (< 5 minutes)

1. Revert DNS/ingress to self-hosted Grafana:
```bash
kubectl apply -f kubernetes/observability/grafana/ingress.yaml
```

2. Verify self-hosted Grafana is still running:
```bash
kubectl get pods -n observability -l app=grafana
```

### Full Rollback

1. Stop remote write to AMP
2. Increase self-hosted Prometheus retention
3. Delete AMP workspace (optional)
4. Delete AMG workspace (optional)

## Testing Checklist

Before cutover, verify:

- [ ] All dashboards migrated to AMG
- [ ] All data sources configured in AMG
- [ ] Alerts configured (CloudWatch + AMG)
- [ ] Prometheus remote write working (check AMP for data)
- [ ] Team trained on AMG interface
- [ ] Access controls configured (IAM/SSO)
- [ ] Cost alerts set up
- [ ] Rollback plan tested

## Post-Migration

### Monitoring

Monitor these metrics:
- AMP ingestion errors
- Remote write queue size
- AMG response times
- Cost trends

### Optimization

Optimize over time:
- Reduce sample rate for low-value metrics
- Aggregate metrics before ingestion
- Use recording rules in AMP
- Optimize dashboard queries

### Documentation

Update documentation:
- Runbooks → use AMG URLs
- Onboarding docs → AMG access instructions
- Incident response → AMG dashboard links

## Additional Resources

- [AMP Documentation](https://docs.aws.amazon.com/prometheus/)
- [AMG Documentation](https://docs.aws.amazon.com/grafana/)
- [AMP Best Practices](https://aws.amazon.com/blogs/mt/best-practices-for-amazon-managed-service-for-prometheus/)
- [AMG Workshop](https://catalog.workshops.aws/observability/en-US/aws-managed-oss/amp)

## Support

For migration assistance:
- AWS Support (if you have Enterprise Support)
- AWS Solutions Architects
- Email: tcytcerov@gmail.com
