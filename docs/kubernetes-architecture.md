# Kubernetes Architecture - Где что живёт

## Архитектура K8s

```
┌─────────────────────────────────────────────────────────────────┐
│                      CONTROL PLANE                              │
│                   (в EKS — AWS управляет)                       │
│                                                                 │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐               │
│  │kube-apiserver│ │    etcd    │ │  scheduler  │               │
│  │             │ │(база данных)│ │             │               │
│  └─────────────┘ └─────────────┘ └─────────────┘               │
│  ┌─────────────────────┐                                        │
│  │ controller-manager  │                                        │
│  └─────────────────────┘                                        │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ API
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       WORKER NODES                              │
│                    (EC2 инстансы)                               │
│                                                                 │
│  Node 1                         Node 2                          │
│  ┌────────────────────┐        ┌────────────────────┐          │
│  │ kubelet (агент)    │        │ kubelet            │          │
│  │ kube-proxy         │        │ kube-proxy         │          │
│  │ container runtime  │        │ container runtime  │          │
│  │                    │        │                    │          │
│  │ [Pod] [Pod] [Pod]  │        │ [Pod] [Pod]        │          │
│  └────────────────────┘        └────────────────────┘          │
└─────────────────────────────────────────────────────────────────┘
```

## Где что живёт

| Компонент | Где запущен | Как запущен |
|-----------|-------------|-------------|
| **kube-apiserver** | Control Plane | Процесс/контейнер |
| **etcd** | Control Plane | Процесс/контейнер |
| **scheduler** | Control Plane | Процесс/контейнер |
| **kubelet** | Каждая нода | systemd сервис |
| **kube-proxy** | Каждая нода | DaemonSet (Pod) |
| **CoreDNS** | Worker nodes | Deployment (Pods) |
| **VPC CNI** | Каждая нода | DaemonSet (Pod) |
| **EBS CSI** | Worker nodes | Deployment + DaemonSet |

## Add-ons — это просто поды

```bash
kubectl get pods -n kube-system

NAME                       READY   STATUS    NODE
aws-node-abc12             1/1     Running   node-1    # VPC CNI
aws-node-def34             1/1     Running   node-2    # VPC CNI
coredns-xyz789-aa          1/1     Running   node-1    # CoreDNS
coredns-xyz789-bb          1/1     Running   node-2    # CoreDNS
kube-proxy-111             1/1     Running   node-1    # kube-proxy
kube-proxy-222             1/1     Running   node-2    # kube-proxy
```

## Одна нода изнутри

```
┌──────────────────── EC2 Instance (Worker Node) ────────────────────┐
│                                                                     │
│  Linux OS (Amazon Linux 2023 / Ubuntu)                             │
│  ├── systemd                                                        │
│  │   └── kubelet.service  ← агент, общается с API server           │
│  │                                                                  │
│  └── containerd (container runtime)                                │
│      │                                                              │
│      ├── [kube-proxy pod]     ← iptables/networking                │
│      ├── [aws-node pod]       ← VPC CNI, раздаёт IP подам          │
│      ├── [coredns pod]        ← DNS (может быть на этой ноде)      │
│      │                                                              │
│      ├── [твой-app pod]       ← твоё приложение                    │
│      └── [другой pod]                                               │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## EKS Add-ons vs Vanilla K8s

### EKS Managed Add-ons

AWS устанавливает и управляет критическими компонентами:

```hcl
resource "aws_eks_addon" "vpc_cni" {
  cluster_name  = "my-cluster"
  addon_name    = "vpc-cni"
  addon_version = "v1.18.0"
}
```

**Под капотом AWS делает:**
```
aws eks create-addon
       │
       ▼
AWS Backend хранит проверенные манифесты
       │
       ▼
kubectl apply -f vpc-cni-v1.18.0.yaml
       │
       ▼
Pods создаются в kube-system namespace
```

### Vanilla K8s (kubeadm)

Всё ставишь сам:

```bash
# CNI — без него поды не запустятся
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

# Или через Helm
helm install cilium cilium/cilium --namespace kube-system
```

### Сравнение

```
EKS:
├── Control Plane        ✅ AWS управляет
├── CNI (vpc-cni)        ✅ Managed add-on
├── CoreDNS              ✅ Managed add-on
├── kube-proxy           ✅ Managed add-on
└── Cloud integration    ✅ Встроено

Vanilla (kubeadm):
├── Control Plane        ❌ Сам ставишь и обновляешь
├── CNI                  ❌ Выбираешь и ставишь
├── CoreDNS              ✅ kubeadm ставит
├── kube-proxy           ✅ kubeadm ставит
└── Cloud integration    ❌ Ставишь cloud-controller-manager
```

---

## CoreDNS vs external-dns

Разные задачи, не конкуренты:

| | CoreDNS | external-dns |
|---|---------|--------------|
| **Что делает** | DNS внутри кластера | Создаёт записи во внешнем DNS |
| **Где работает** | Внутри K8s | K8s → Route53/CloudFlare/etc |
| **Резолвит** | `my-svc.namespace.svc.cluster.local` | `app.example.com` → LoadBalancer IP |

```
Pod A → CoreDNS → "my-service" = 10.100.50.25 → Pod B  (внутри кластера)

Browser → Route53 → ALB → Pod  (снаружи, запись создал external-dns)
```

---

## Типичный Production стек

```
Managed Add-ons (aws_eks_addon):
├── vpc-cni
├── coredns
├── kube-proxy
├── aws-ebs-csi-driver
└── eks-pod-identity-agent

Helm Charts (helm_release):
├── aws-load-balancer-controller
├── external-dns
├── cert-manager
├── metrics-server
├── karpenter
├── argocd
└── prometheus + grafana
```

---

**Вывод:** "Ядра" нет. Есть Control Plane (мозг) и Worker Nodes (руки). Add-ons — обычные поды в `kube-system`, просто критически важные.
