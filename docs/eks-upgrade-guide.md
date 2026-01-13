# EKS Upgrade Guide

## Порядок обновления

```
1. Add-ons        ← сначала (совместимость с новой версией K8s)
2. Control Plane  ← потом (AWS управляет)
3. Node Groups    ← последними (rolling update)
```

---

## Пошаговая инструкция

### 0. Подготовка

```bash
# Проверь текущие версии
kubectl version --short
aws eks describe-cluster --name my-cluster --query 'cluster.version'

# Версии add-ons
aws eks describe-addon --cluster-name my-cluster --addon-name vpc-cni
aws eks describe-addon --cluster-name my-cluster --addon-name coredns
aws eks describe-addon --cluster-name my-cluster --addon-name kube-proxy

# Проверь deprecated APIs
kubectl get --raw /apis/apps/v1/deployments | jq .

# Посмотри какие API будут удалены
kubectl api-resources --verbs=list -o name | xargs -n 1 kubectl get --show-kind --ignore-not-found

# Backup важного (опционально)
velero backup create pre-upgrade-backup
```

### 1. Обнови Add-ons

```hcl
# terraform/environments/prod/main.tf

# Сначала add-ons — они должны поддерживать НОВУЮ версию K8s
module "eks_addons" {
  source = "../../modules/eks-addons"

  addon_versions = {
    vpc_cni            = "v1.19.0"  # версия для K8s 1.32
    coredns            = "v1.11.3"
    kube_proxy         = "v1.32.0"
    ebs_csi            = "v1.37.0"
    pod_identity_agent = "v1.3.4"
  }
}
```

```bash
# Примени изменения
terraform plan -target=module.eks_addons
terraform apply -target=module.eks_addons

# Проверь статус
kubectl get pods -n kube-system
aws eks describe-addon --cluster-name my-cluster --addon-name vpc-cni --query 'addon.status'
```

### 2. Обнови Control Plane

```hcl
# terraform/environments/prod/main.tf

module "eks_cluster" {
  source = "../../modules/eks-cluster"

  cluster_version = "1.32"  # было 1.31
}
```

```bash
# Примени изменения (~15-30 минут, zero downtime)
terraform plan -target=module.eks_cluster
terraform apply -target=module.eks_cluster

# Мониторь статус
watch aws eks describe-cluster --name my-cluster --query 'cluster.status'

# Проверь после завершения
kubectl version --short
```

### 3. Обнови Node Groups

```hcl
# terraform/environments/prod/main.tf

module "eks_node_groups" {
  source = "../../modules/eks-node-groups"

  cluster_version = "1.32"  # должна совпадать с cluster

  # Rolling update настройки
  update_config = {
    max_unavailable = 1
  }
}
```

```bash
# Примени изменения (rolling update)
terraform plan -target=module.eks_node_groups
terraform apply -target=module.eks_node_groups

# Мониторь прогресс
watch kubectl get nodes
kubectl get nodes -o wide
```

---

## Best Practices

| Правило | Почему |
|---------|--------|
| **+1 версия за раз** | 1.30 → 1.31 → 1.32, никогда не прыгать |
| **Add-ons первыми** | CNI/CoreDNS должны работать с новой версией |
| **Dev → Staging → Prod** | Всегда тестируй перед продом |
| **PodDisruptionBudget** | Гарантирует availability при rolling update |
| **Drain timeout** | Дай подам время завершиться gracefully |
| **Проверь deprecated APIs** | Перед апгрейдом, иначе сломается |
| **Читай Release Notes** | AWS и Kubernetes changelog |
| **Maintenance window** | Планируй на низкую нагрузку |

---

## Версионная совместимость

```
Control Plane:  1.32
                  │
                  ├── Nodes: 1.32 ✅ (рекомендуется)
                  ├── Nodes: 1.31 ⚠️  (допустимо, но обнови)
                  └── Nodes: 1.30 ❌ (не поддерживается)

kubectl:        ±1 от control plane (1.31, 1.32, 1.33)

Add-ons:        Версия совместимая с control plane
                (проверь в AWS Console или docs)
```

### Как узнать совместимые версии add-ons

```bash
# Список доступных версий для твоего кластера
aws eks describe-addon-versions \
  --kubernetes-version 1.32 \
  --addon-name vpc-cni \
  --query 'addons[].addonVersions[].addonVersion'
```

---

## PodDisruptionBudget (обязательно для prod)

```yaml
# Гарантирует что минимум 1 pod всегда доступен
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: my-app-pdb
spec:
  minAvailable: 1  # или maxUnavailable: 1
  selector:
    matchLabels:
      app: my-app
```

---

## Rollback план

```
┌─────────────────────────────────────────────────────────────┐
│  Control Plane — НЕЛЬЗЯ откатить! Только вперёд.           │
│                                                             │
│  Поэтому:                                                   │
│  1. Всегда тестируй на dev/staging                         │
│  2. Читай release notes                                     │
│  3. Проверяй deprecated APIs заранее                       │
│  4. Имей план отката приложений                            │
└─────────────────────────────────────────────────────────────┘

Node Groups — можно пересоздать со старым AMI:
  terraform apply -target=module.eks_node_groups -var="ami_version=old"

Add-ons — можно откатить версию:
  aws eks update-addon --addon-version v1.18.0 ...

Приложения — откат через:
  - Helm rollback
  - ArgoCD sync to previous commit
  - kubectl rollout undo
```

---

## Автоматизация в Terraform

```hcl
# variables.tf
variable "cluster_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.32"
}

# Все компоненты используют одну переменную
module "eks_cluster" {
  cluster_version = var.cluster_version
}

module "eks_node_groups" {
  cluster_version = var.cluster_version
}

# Add-ons версии в отдельной map
variable "addon_versions" {
  type = map(string)
  default = {
    vpc_cni    = "v1.19.0"
    coredns    = "v1.11.3"
    kube_proxy = "v1.32.0"
  }
}
```

---

## Чеклист перед апгрейдом

- [ ] Прочитал Kubernetes release notes
- [ ] Прочитал EKS release notes
- [ ] Проверил deprecated APIs в своих манифестах
- [ ] Обновил kubectl до совместимой версии
- [ ] Протестировал на dev окружении
- [ ] Протестировал на staging окружении
- [ ] Настроил PodDisruptionBudget для критичных сервисов
- [ ] Уведомил команду о maintenance window
- [ ] Подготовил план отката приложений
- [ ] Создал backup (если используется Velero)

---

## Полезные команды

```bash
# Статус кластера
aws eks describe-cluster --name my-cluster --query 'cluster.{Version:version,Status:status}'

# Статус нод
kubectl get nodes -o wide

# Статус add-ons
aws eks list-addons --cluster-name my-cluster
aws eks describe-addon --cluster-name my-cluster --addon-name vpc-cni

# Проверка подов после апгрейда
kubectl get pods --all-namespaces | grep -v Running

# События (ошибки)
kubectl get events --sort-by='.lastTimestamp' -A | tail -20

# Проверка API deprecations
kubectl deprecations  # если установлен pluto
```

---

## Ссылки

- [EKS Release Notes](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html)
- [Kubernetes Deprecation Guide](https://kubernetes.io/docs/reference/using-api/deprecation-guide/)
- [EKS Add-on Versions](https://docs.aws.amazon.com/eks/latest/userguide/managing-add-ons.html)
- [EKS Best Practices - Upgrades](https://aws.github.io/aws-eks-best-practices/upgrades/)
