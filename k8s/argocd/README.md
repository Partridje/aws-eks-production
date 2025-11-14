# ArgoCD GitOps Configuration

This directory contains ArgoCD manifests for GitOps-based application deployment.

## Structure

```
k8s/argocd/
├── projects/              # ArgoCD AppProjects
│   └── infrastructure.yaml
├── applications/          # ArgoCD Applications
│   ├── aws-load-balancer-controller.yaml
│   └── metrics-server.yaml
└── README.md
```

## Projects

### infrastructure
Platform and infrastructure services:
- AWS Load Balancer Controller
- Metrics Server
- Cert Manager
- External DNS
- External Secrets
- Monitoring stack (Prometheus/Grafana)

## Deploying Applications

### Option 1: Apply via kubectl (after ArgoCD is installed)

```bash
# Apply project
kubectl apply -f k8s/argocd/projects/infrastructure.yaml

# Apply applications
kubectl apply -f k8s/argocd/applications/
```

### Option 2: Using ArgoCD CLI

```bash
# Create project
argocd proj create -f k8s/argocd/projects/infrastructure.yaml

# Create applications
argocd app create -f k8s/argocd/applications/aws-load-balancer-controller.yaml
argocd app create -f k8s/argocd/applications/metrics-server.yaml
```

### Option 3: App of Apps Pattern (Recommended)

Create a root application that manages all other applications:

```yaml
# k8s/argocd/root-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/Partridje/aws-eks-production.git
    targetRevision: main
    path: k8s/argocd/applications
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## Application Sync Policies

All applications use automated sync with:
- **prune**: true - Remove resources deleted from Git
- **selfHeal**: true - Auto-sync on cluster drift
- **allowEmpty**: false - Prevent deletion of all resources

## Customizing Applications

### Update Chart Version

Edit `targetRevision` in the application manifest:

```yaml
source:
  targetRevision: 1.8.0  # New version
```

### Override Helm Values

Add/modify values in the `helm.values` section:

```yaml
helm:
  values: |
    replicaCount: 3
    resources:
      limits:
        memory: 512Mi
```

### Add Parameters

Use `helm.parameters` for simple overrides:

```yaml
helm:
  parameters:
    - name: serviceAccount.name
      value: my-sa
```

## Monitoring Applications

### Check Application Status

```bash
# List all applications
argocd app list

# Get specific app
argocd app get aws-load-balancer-controller

# View sync status
argocd app sync-status aws-load-balancer-controller
```

### View Application Logs

```bash
# Application controller logs
argocd app logs aws-load-balancer-controller

# Follow logs
argocd app logs aws-load-balancer-controller --follow
```

### Sync Applications

```bash
# Manual sync
argocd app sync aws-load-balancer-controller

# Hard refresh (clear cache)
argocd app sync aws-load-balancer-controller --force

# Sync with prune
argocd app sync aws-load-balancer-controller --prune
```

## Troubleshooting

### Application Out of Sync

```bash
# View diff
argocd app diff aws-load-balancer-controller

# View detailed sync status
argocd app get aws-load-balancer-controller --show-operation

# Refresh application
argocd app refresh aws-load-balancer-controller
```

### Sync Failures

```bash
# Check application events
kubectl describe application aws-load-balancer-controller -n argocd

# View application conditions
kubectl get application aws-load-balancer-controller -n argocd -o jsonpath='{.status.conditions}'

# Check logs
kubectl logs -n argocd deployment/argocd-application-controller
```

### Resource Pruning Issues

If resources are not being pruned:

1. Check if finalizers are set correctly
2. Ensure `prune: true` in syncPolicy
3. Check resource ownership labels

## Best Practices

1. **Use Projects**: Organize applications into logical projects
2. **Automated Sync**: Enable for non-production environments
3. **Version Pinning**: Pin chart versions instead of using `latest`
4. **Resource Limits**: Always set resource requests/limits
5. **Health Checks**: Define custom health checks for CRDs
6. **Ignore Differences**: Configure for known drift (e.g., webhook CA bundles)
7. **PDB**: Use Pod Disruption Budgets for HA applications
8. **Monitoring**: Enable ServiceMonitors for Prometheus

## Adding New Applications

1. Create application manifest in `applications/`
2. Set appropriate project (usually `infrastructure`)
3. Configure automated sync policy
4. Set resource limits
5. Add health checks if needed
6. Test in dev before production

Example:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  project: infrastructure
  source:
    repoURL: https://charts.example.com
    targetRevision: 1.0.0
    chart: my-app
  destination:
    server: https://kubernetes.default.svc
    namespace: my-namespace
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## Security Considerations

- Applications inherit RBAC from project definitions
- Service accounts use IRSA for AWS access
- Secrets managed via External Secrets or Sealed Secrets
- Image pull from private ECR requires authentication

## References

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [App of Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
- [Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
