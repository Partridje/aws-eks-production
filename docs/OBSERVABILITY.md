# Observability Architecture Deep Dive

## Table of Contents
- [Overview](#overview)
- [Hybrid Observability Strategy](#hybrid-observability-strategy)
- [CloudWatch Container Insights](#cloudwatch-container-insights)
- [Fluent Bit Logging](#fluent-bit-logging)
- [AWS X-Ray Tracing](#aws-x-ray-tracing)
- [In-Cluster Prometheus](#in-cluster-prometheus)
- [Grafana Multi-Datasource](#grafana-multi-datasource)
- [CloudWatch Alarms](#cloudwatch-alarms)
- [Dashboards](#dashboards)
- [Application Instrumentation](#application-instrumentation)

## Overview

This project implements a **hybrid observability approach** that combines:
1. **AWS Native Services** (CloudWatch, X-Ray) - production-grade, zero operational overhead
2. **In-Cluster Tools** (Prometheus, Grafana) - Kubernetes expertise demonstration, custom metrics

### Three Pillars of Observability

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   METRICS   │     │    LOGS     │     │   TRACES    │
│             │     │             │     │             │
│ CloudWatch  │     │ CloudWatch  │     │  AWS X-Ray  │
│ Container   │     │    Logs     │     │             │
│  Insights   │     │   (Fluent   │     │  Service    │
│      +      │     │     Bit)    │     │    Map      │
│ Prometheus  │     │             │     │             │
└─────────────┘     └─────────────┘     └─────────────┘
       │                   │                   │
       └───────────────────┴───────────────────┘
                           │
                    ┌──────▼──────┐
                    │   Grafana   │
                    │ Multi-Source│
                    │  Dashboards │
                    └─────────────┘
```

## Hybrid Observability Strategy

### Why Hybrid?

#### AWS Native (Primary)
✅ **Zero operational overhead** - fully managed
✅ **Automatic scaling** - no capacity planning
✅ **Built-in retention** - 15 months for metrics
✅ **Native EKS integration** - Container Insights addon
✅ **Production-ready** - AWS SLAs and support
✅ **Cost-effective at scale** - pay per use

#### In-Cluster (Secondary)
✅ **Kubernetes expertise** - demonstrates DevOps skills
✅ **Custom metrics** - application-specific monitoring
✅ **Flexible querying** - PromQL for advanced queries
✅ **Development workflow** - faster iteration
✅ **Migration path** - easy to move to AMP/AMG

### Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                      EKS Worker Nodes                        │
│                                                               │
│  ┌──────────┐      ┌──────────┐      ┌──────────┐          │
│  │   Pod    │      │   Pod    │      │   Pod    │          │
│  │          │      │          │      │          │          │
│  │  stdout  │──┐   │  stdout  │──┐   │  stdout  │──┐       │
│  │  stderr  │  │   │  stderr  │  │   │  stderr  │  │       │
│  │          │  │   │          │  │   │          │  │       │
│  │ /metrics │──┼──▶│ /metrics │──┼──▶│ /metrics │──┼──┐    │
│  │ endpoint │  │   │ endpoint │  │   │ endpoint │  │  │    │
│  │          │  │   │          │  │   │          │  │  │    │
│  │  X-Ray   │──┼──▶│  X-Ray   │──┼──▶│  X-Ray   │──┼──┼──┐ │
│  │  spans   │  │   │  spans   │  │   │  spans   │  │  │  ││
│  └──────────┘  │   └──────────┘  │   └──────────┘  │  │  ││
│                │                 │                 │  │  ││
│    ┌───────────▼─────────────────▼─────────────────┘  │  ││
│    │         Fluent Bit DaemonSet                     │  ││
│    │       (Log Aggregation)                          │  ││
│    └────────────┬─────────────────────────────────────┘  ││
│                 │                                         ││
│    ┌────────────▼────────────────────────────────────┐   ││
│    │       Prometheus Server                         │◀──┘│
│    │     (Custom Metrics Scraping)                   │    ││
│    └─────────────────────────────────────────────────┘    ││
│                                                            ││
│    ┌───────────────────────────────────────────────────┐  ││
│    │        X-Ray Daemon DaemonSet                     │◀─┘│
│    │      (Trace Collection)                           │   │
│    └────────────┬──────────────────────────────────────┘   │
└─────────────────┼──────────────────────────────────────────┘
                  │
        ┌─────────┼─────────┬──────────────┐
        │         │         │              │
        ▼         ▼         ▼              ▼
  ┌──────────┐ ┌────────┐ ┌──────┐  ┌─────────┐
  │CloudWatch│ │ X-Ray  │ │Grafana│  │Prometheus│
  │   Logs   │ │        │ │       │  │  (Local)│
  └──────────┘ └────────┘ └───┬───┘  └─────────┘
                               │
                     ┌─────────▼────────┐
                     │   Datasources:   │
                     │  - CloudWatch    │
                     │  - Prometheus    │
                     └──────────────────┘
```

## CloudWatch Container Insights

### Automatic Metrics Collection

Container Insights is enabled via EKS addon:

```terraform
# terraform/modules/eks/main.tf
resource "aws_eks_addon" "cloudwatch_observability" {
  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "amazon-cloudwatch-observability"
  service_account_role_arn = var.cloudwatch_agent_role_arn
}
```

### Metrics Collected

#### Cluster Level
- `cluster_failed_node_count`
- `cluster_node_count`
- `namespace_number_of_running_pods`

#### Node Level
- `node_cpu_utilization`
- `node_cpu_usage_total`
- `node_memory_utilization`
- `node_memory_working_set`
- `node_network_total_bytes`
- `node_filesystem_utilization`

#### Pod Level
- `pod_cpu_utilization`
- `pod_cpu_usage_total`
- `pod_memory_utilization`
- `pod_memory_working_set`
- `pod_network_rx_bytes`
- `pod_network_tx_bytes`
- `pod_number_of_container_restarts`

### Accessing Container Insights

AWS Console:
```
CloudWatch → Container Insights → Performance monitoring
```

Select cluster: `eks-prod-dev`

### Retention
- Metrics: 15 months (automatic)
- Logs: 7 days (configurable)

## Fluent Bit Logging

### Architecture

Fluent Bit runs as DaemonSet on each node, collecting logs from all pods and forwarding to CloudWatch Logs.

### Configuration

```yaml
# kubernetes/infrastructure/fluent-bit/values.yaml
cloudWatch:
  enabled: true
  region: eu-west-1
  logGroupName: /aws/eks/eks-prod-dev/application
  logStreamPrefix: pod-

serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT:role/eks-prod-dev-fluent-bit
```

### Log Processing Pipeline

```
┌──────────────┐
│  Container   │
│  stdout/err  │
└──────┬───────┘
       │
┌──────▼───────────────────┐
│ Fluent Bit DaemonSet     │
│                          │
│ [INPUT]                  │
│   tail containers/*.log  │
│                          │
│ [FILTER]                 │
│   kubernetes metadata    │
│   parser (JSON/regex)    │
│                          │
│ [OUTPUT]                 │
│   cloudwatch_logs        │
└──────┬───────────────────┘
       │
┌──────▼─────────────────────────┐
│  CloudWatch Logs               │
│  /aws/eks/CLUSTER/application  │
│                                │
│  Streams:                      │
│  - pod-demo-backend-xxx        │
│  - pod-demo-frontend-xxx       │
│  - pod-prometheus-xxx          │
└────────────────────────────────┘
```

### Log Format

Structured JSON logs from applications:

```json
{
  "asctime": "2025-01-13T10:00:00Z",
  "name": "demo-backend",
  "levelname": "INFO",
  "message": "Item created",
  "item_id": 123,
  "kubernetes": {
    "pod_name": "demo-backend-6f8d5c9b7-x2k9p",
    "namespace_name": "default",
    "pod_id": "abc123...",
    "container_name": "backend"
  }
}
```

### Querying Logs

CloudWatch Logs Insights query examples:

```sql
# Find errors in last hour
fields @timestamp, @message
| filter @logStream like /demo-backend/
| filter levelname = "ERROR"
| sort @timestamp desc
| limit 100

# Count requests by endpoint
fields @timestamp
| filter @logStream like /demo-backend/
| stats count() by endpoint

# P95 latency
fields @timestamp, duration
| filter @logStream like /demo-backend/
| stats percentile(duration, 95) as p95_latency
```

## AWS X-Ray Tracing

### Architecture

```
┌──────────────┐      ┌──────────────┐
│   Frontend   │─────▶│   Backend    │
│              │      │   (FastAPI)  │
│  X-Ray SDK   │      │   X-Ray SDK  │
└──────┬───────┘      └──────┬───────┘
       │                     │
       │  UDP:2000          │
       │                     │
       └────────┬────────────┘
                │
        ┌───────▼───────┐
        │  X-Ray Daemon │
        │   DaemonSet   │
        └───────┬───────┘
                │
        ┌───────▼───────┐
        │  AWS X-Ray    │
        │   Service     │
        └───────────────┘
```

### Application Instrumentation

Python (FastAPI):

```python
# apps/backend/src/main.py
from aws_xray_sdk.core import xray_recorder, patch_all
from aws_xray_sdk.ext.fastapi.middleware import XRayMiddleware

# Patch AWS SDK and HTTP libraries
patch_all()

# Configure X-Ray
xray_recorder.configure(
    service='demo-backend',
    plugins=('EKSPlugin',),
    daemon_address='xray-daemon.amazon-cloudwatch.svc.cluster.local:2000'
)

# Add middleware
app.add_middleware(XRayMiddleware, recorder=xray_recorder)

# Instrument specific code sections
@app.get("/api/items")
async def list_items(db: AsyncSession = Depends(get_db)):
    with xray_recorder.capture('list_items'):
        # Your code here
        ...
```

### X-Ray Service Map

Visualizes:
- Service dependencies
- Request flow
- Latency between services
- Error rates

Access: `AWS Console → X-Ray → Service map`

### Traces Analysis

Find slow requests:
```
AWS Console → X-Ray → Traces
Filter: response time > 1s
```

## In-Cluster Prometheus

### Why Prometheus?

1. **Custom Application Metrics** - business metrics not available in CloudWatch
2. **PromQL** - powerful query language
3. **Kubernetes Native** - ServiceMonitor CRDs
4. **Development** - faster iteration than CloudWatch custom metrics

### Architecture

```yaml
# Lightweight deployment focused on custom metrics
prometheus:
  prometheusSpec:
    retention: 2d          # Short retention (CloudWatch has long-term)
    retentionSize: "2GB"
    replicas: 1            # Single replica for demo

    # Only scrape custom app metrics
    serviceMonitorSelector:
      matchLabels:
        prometheus: custom-metrics
```

### Custom Metrics Example

```python
# Backend application exposes metrics
from prometheus_client import Counter, Histogram

REQUEST_COUNT = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status']
)

REQUEST_DURATION = Histogram(
    'http_request_duration_seconds',
    'HTTP request duration',
    ['method', 'endpoint']
)

ITEMS_CREATED = Counter(
    'items_created_total',
    'Total items created'
)
```

### ServiceMonitor

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: demo-backend
  labels:
    prometheus: custom-metrics
spec:
  selector:
    matchLabels:
      app: demo-backend
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
```

### PromQL Query Examples

```promql
# Request rate
rate(http_requests_total[5m])

# Error rate
rate(http_requests_total{status=~"5.."}[5m])
  / rate(http_requests_total[5m])

# P95 latency
histogram_quantile(0.95,
  rate(http_request_duration_seconds_bucket[5m])
)

# Items created per minute
rate(items_created_total[1m]) * 60
```

## Grafana Multi-Datasource

### Configuration

```yaml
datasources:
  # Primary: CloudWatch (AWS native metrics)
  - name: CloudWatch
    type: cloudwatch
    jsonData:
      authType: default  # Uses IRSA
      defaultRegion: eu-west-1
    isDefault: true

  # Secondary: Prometheus (custom metrics)
  - name: Prometheus
    type: prometheus
    url: http://prometheus-operated:9090
    isDefault: false
```

### Dashboard Examples

#### EKS Cluster Overview (CloudWatch source)
- Cluster nodes count
- CPU/Memory utilization
- Pod restarts
- Network I/O

#### Application Metrics (Prometheus source)
- Request rate
- Error rate
- Latency percentiles
- Business metrics (items created, etc.)

#### Combined Dashboard
Uses both datasources to show complete picture:
- Infrastructure metrics from CloudWatch
- Application metrics from Prometheus

## CloudWatch Alarms

### Configured Alarms

```terraform
# Node CPU High
threshold = 80%
evaluation_periods = 2 (10 minutes)
action = SNS email

# Node Memory High
threshold = 85%
evaluation_periods = 2

# Pod CPU/Memory High
threshold = 80%/85%

# Cluster Failed Nodes
threshold = 0 (any failed node)
evaluation_periods = 1

# RDS CPU High
threshold = 80%

# RDS Storage Low
threshold = 10GB free space

# RDS Connections High
threshold = 80 connections
```

### SNS Notifications

Email sent to: `tcytcerov@gmail.com`

Email format:
```
AlarmName: eks-prod-dev-node-cpu-high
Alarm Description: Node CPU utilization is high
State Change: OK -> ALARM
Reason: Threshold Crossed: 2 datapoints [85.2, 82.1] were greater than threshold (80.0)
```

## Dashboards

### CloudWatch Dashboard

Auto-created: `eks-prod-dev-overview`

Widgets:
- Cluster nodes (total, failed)
- Node resource utilization
- Pod resource utilization
- Container restarts

Access:
```
CloudWatch → Dashboards → eks-prod-dev-overview
```

### Grafana Dashboards

Pre-configured:
1. **EKS CloudWatch Insights** (gnetId: 14623)
2. **EKS Pods** (gnetId: 14622)
3. **Application Custom Metrics** (Prometheus)

## Application Instrumentation

### Health Checks

All applications expose:

```python
@app.get("/health")          # Liveness
@app.get("/health/ready")    # Readiness
@app.get("/health/startup")  # Startup
```

### Metrics Endpoint

```python
@app.get("/metrics")
# Prometheus format metrics
```

### Structured Logging

```python
# JSON format with context
logger.info("Item created", extra={
    "item_id": 123,
    "user_id": 456,
    "environment": "production"
})
```

### Tracing

```python
# X-Ray segments
with xray_recorder.capture('database_query'):
    result = await db.execute(query)
```

## Best Practices

### Metrics
✅ Use CloudWatch for infrastructure metrics
✅ Use Prometheus for custom application metrics
✅ Expose `/metrics` endpoint for Prometheus scraping
✅ Use semantic metric names
✅ Add relevant labels

### Logs
✅ Use structured logging (JSON)
✅ Include correlation IDs
✅ Log at appropriate levels
✅ Avoid logging sensitive data
✅ Use log sampling for high-volume logs

### Tracing
✅ Trace user-facing requests
✅ Include database queries in traces
✅ Add metadata to spans
✅ Sample traces (not 100%)
✅ Use trace IDs for log correlation

## Cost Optimization

### CloudWatch Logs
- Retention: 7 days (vs 30+ days)
- Saves: ~70% on log storage costs

### CloudWatch Metrics
- Use Container Insights (free tier covers basics)
- Avoid unnecessary custom metrics

### Prometheus
- Short retention (2 days)
- Single replica (not HA)
- Only custom metrics

### X-Ray
- Sample traces (10-20%)
- Focus on critical paths

## Monitoring the Monitoring

### Fluent Bit
```bash
kubectl logs -n amazon-cloudwatch -l app=fluent-bit
```

### Prometheus
```bash
kubectl port-forward -n observability svc/prometheus-operated 9090:9090
# Open http://localhost:9090
```

### X-Ray Daemon
```bash
kubectl logs -n amazon-cloudwatch -l app=xray-daemon
```

## Troubleshooting

### No metrics in CloudWatch Container Insights
```bash
# Check addon status
kubectl get pods -n amazon-cloudwatch

# Check IAM role
kubectl describe sa -n amazon-cloudwatch cloudwatch-agent
```

### Logs not appearing in CloudWatch
```bash
# Check Fluent Bit pods
kubectl logs -n amazon-cloudwatch daemonset/fluent-bit

# Verify IAM permissions
aws logs describe-log-groups --log-group-name-prefix /aws/eks/
```

### X-Ray traces not showing
```bash
# Check X-Ray daemon
kubectl logs -n amazon-cloudwatch daemonset/xray-daemon

# Test from pod
kubectl exec -it POD_NAME -- curl xray-daemon.amazon-cloudwatch:2000
```

## Next Steps

See [PRODUCTION_MIGRATION.md](PRODUCTION_MIGRATION.md) for:
- Migrating to Amazon Managed Prometheus
- Migrating to Amazon Managed Grafana
- Long-term retention strategies
- Advanced alerting
