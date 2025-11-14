# ArgoCD Module

This module deploys ArgoCD for GitOps continuous deployment in the EKS cluster.

## Features

- **High Availability**: Configurable HA mode with multiple replicas
- **Metrics**: Prometheus metrics enabled for all components
- **Secure Password**: Auto-generated admin password stored in AWS Secrets Manager
- **LoadBalancer**: Network Load Balancer for external access
- **ApplicationSet Controller**: Manage multiple applications from templates
- **Notifications**: Event notifications support

## Components Installed

- **argocd-server**: API and UI server
- **argocd-repo-server**: Repository server (connects to Git)
- **argocd-application-controller**: Application reconciliation controller
- **argocd-applicationset-controller**: ApplicationSet controller
- **argocd-notifications-controller**: Notifications controller
- **redis/redis-ha**: Cache (HA mode in production)

## Usage

```hcl
module "argocd" {
  source = "../../modules/argocd"

  cluster_name                       = module.eks.cluster_id
  cluster_endpoint                   = module.eks.cluster_endpoint
  cluster_certificate_authority_data = module.eks.cluster_certificate_authority_data
  oidc_provider_arn                  = module.eks.oidc_provider_arn

  domain    = var.domain
  enable_ha = true

  tags = local.tags
}
```

## Accessing ArgoCD

### Get Admin Password

```bash
# From AWS Secrets Manager
aws secretsmanager get-secret-value \
  --secret-id <cluster-name>-argocd-admin-password \
  --query SecretString \
  --output text | jq -r '.password'

# Or from Terraform outputs
terraform output -raw argocd_admin_password
```

### Access UI

```bash
# Get LoadBalancer URL
kubectl get svc argocd-server -n argocd

# Port-forward (alternative)
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Open browser
# https://localhost:8080
# Username: admin
# Password: <from secrets manager>
```

### CLI Login

```bash
# Install ArgoCD CLI
brew install argocd  # macOS
# or
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/

# Login
ARGOCD_PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id <cluster-name>-argocd-admin-password \
  --query SecretString --output text | jq -r '.password')

argocd login <loadbalancer-url> \
  --username admin \
  --password $ARGOCD_PASSWORD \
  --insecure
```

## Post-Installation Steps

### 1. Add Git Repository

```bash
argocd repo add https://github.com/Partridje/aws-eks-production.git \
  --type git \
  --name aws-eks-production
```

### 2. Create First Application

```bash
argocd app create guestbook \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path guestbook \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default
```

### 3. Configure SSO (Optional)

Edit ArgoCD ConfigMap to add OAuth/OIDC configuration.

## Architecture

```
┌─────────────────────────────────────────────────┐
│                 ArgoCD Components                │
├─────────────────────────────────────────────────┤
│                                                  │
│  ┌────────────┐     ┌──────────────┐            │
│  │  argocd-   │────▶│  Git Repos   │            │
│  │  repo-     │     │  (GitHub)    │            │
│  │  server    │     └──────────────┘            │
│  └────────────┘                                  │
│        │                                         │
│        ▼                                         │
│  ┌────────────┐     ┌──────────────┐            │
│  │  argocd-   │────▶│  Kubernetes  │            │
│  │  application│     │  API Server  │            │
│  │  controller│     └──────────────┘            │
│  └────────────┘                                  │
│        │                                         │
│        ▼                                         │
│  ┌────────────┐                                  │
│  │  argocd-   │     ┌──────────────┐            │
│  │  server    │◀────│   Users /    │            │
│  │  (UI/API)  │     │   CI/CD      │            │
│  └────────────┘     └──────────────┘            │
│        │                                         │
│        ▼                                         │
│  ┌────────────┐                                  │
│  │  Redis/    │                                  │
│  │  Redis-HA  │                                  │
│  └────────────┘                                  │
└─────────────────────────────────────────────────┘
```

## Variables

See `variables.tf` for all available variables.

## Outputs

- `namespace`: ArgoCD namespace
- `release_name`: Helm release name
- `admin_password_secret_arn`: AWS Secrets Manager secret ARN
- `admin_password`: Admin password (sensitive)
- `argocd_server_url`: ArgoCD server URL

## Security Considerations

- Admin password is auto-generated and stored in AWS Secrets Manager
- TLS is handled at the LoadBalancer level (--insecure flag on server)
- RBAC policies configured with readonly default
- Consider enabling Dex for SSO/OAuth integration
- Rotate admin password periodically

## Monitoring

ArgoCD exposes Prometheus metrics on all components:
- Controller metrics: `:8082/metrics`
- Server metrics: `:8083/metrics`
- Repo server metrics: `:8084/metrics`

ServiceMonitor resources are created automatically for Prometheus Operator.
