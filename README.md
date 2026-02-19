# Homelab GitOps with ArgoCD

A complete Kubernetes homelab setup using ArgoCD for GitOps-based infrastructure and application management.

## 🏗️ Architecture

This repository implements an "App of Apps" pattern where:
- **Root App** (`root-app.yaml`) deploys two main applications
- **Infrastructure App** manages core cluster services
- **Applications App** manages user-facing applications

```
root-app.yaml
├── infrastructure/infrastructure-app.yaml
│   ├── sealed-secrets/
│   ├── cert-manager/
│   ├── traefik/
│   ├── metallb/
│   ├── authentik/
│   ├── kube-prometheus-stack/
│   ├── pihole/
│   ├── node-setup/
│   └── intel-gpu-plugin/           # 🆕 Intel GPU hardware acceleration
└── apps/apps-app.yaml
    ├── actual-budget/
    ├── media-stack/
    └── nginx/
```

## 📦 Infrastructure Components

### Core Services
- **ArgoCD** - GitOps continuous deployment
- **SealedSecrets** - Encrypted secrets management
- **Cert-Manager** - Automatic SSL certificates via Cloudflare
- **Traefik** - Ingress controller and load balancer
- **MetalLB** - Load balancer for bare metal
- **Authentik** - Identity provider and SSO

### Hardware Acceleration
- **Intel GPU Plugin** - Hardware transcoding for media workloads
- **Node Feature Discovery** - Automatic hardware detection and labeling

### Monitoring & Observability
- **kube-prometheus-stack** - Prometheus, Grafana, Alertmanager
- **Pi-hole** - DNS filtering and ad blocking

### Storage Strategy
Four StorageClasses for different performance needs:

| StorageClass | Type | Capacity | Use Case |
|--------------|------|----------|----------|
| `fast-ssd-critical` | Local SSD | 280GB | Redis, Prometheus TSDB |
| `nfs-ssd-fast` | NFS SSD | 4TB | PostgreSQL, app configs |
| `nfs-hdd-bulk` (default) | NFS HDD | 8TB | Backups, logs, documents |
| `nfs-media-direct` | NFS Direct | ∞ | Media server files |

## 🚀 Applications

### Productivity
- **Actual Budget** - Personal finance management with OIDC
- **Nginx** - Static web hosting

### Media Stack
Complete media management suite with **hardware transcoding**:
- **Jellyfin** - Media server with Intel Quick Sync Video support
- **Radarr** - Movie collection manager
- **Sonarr** - TV show collection manager
- **Jellyseerr** - Request management
- **Prowlarr** - Indexer manager
- **qBittorrent** - Download client

## 🛠️ Prerequisites

### Cluster Requirements
- Kubernetes cluster (K3s recommended)
- ArgoCD installed and configured
- NFS server for shared storage
- Domain with Cloudflare DNS

### Required Provisioners
```bash
# Local Path Provisioner (usually included in K3s)
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml

# NFS CSI Driver
helm repo add csi-driver-nfs https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts
helm install csi-driver-nfs csi-driver-nfs/csi-driver-nfs --namespace kube-system
```

### NAS Configuration
Configure NFS exports on your NAS:
```bash
/volume1/k3s-ssd    10.5.1.0/24(rw,sync,no_subtree_check,no_root_squash)
/volume2/k3s-hdd    10.5.1.0/24(rw,sync,no_subtree_check,no_root_squash)
/volume2/media      10.5.1.0/24(rw,sync,no_subtree_check,no_root_squash)
```

## 📋 Deployment

### 1. Clone and Configure
```bash
git clone <your-repo>
cd homelab-argocd
```

### 2. Update Configuration
- Edit server IPs in StorageClass manifests (`infrastructure/node-setup/manifests/`)
- Configure your domain in ingress values
- Update Cloudflare API tokens in SealedSecrets

### 3. Create Secrets
Follow the [SealedSecrets guide](docs/sealed-secrets.md):
```bash
# Example: Create Cloudflare API token
kubectl create secret generic cloudflare-api-token \
  --from-literal=api-token=your-token \
  --dry-run=client -o yaml | \
  kubeseal --controller-name=sealed-secrets --controller-namespace=kube-system \
  -o yaml > infrastructure/cert-manager/config/cloudflare-api-token-sealedsecret.yaml
```

### 4. Deploy Root App
```bash
kubectl apply -f root-app.yaml
```

### 5. Monitor Deployment
```bash
# Watch ArgoCD applications
kubectl get applications -n argocd -w

# Check application status
argocd app list
```

## 🔧 Management

### Common Commands
```bash
# Sync all applications
argocd app sync -l app.kubernetes.io/instance=homelab-root

# Check sealed-secrets controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=sealed-secrets

# Backup sealed-secrets keys
./bootstrap/backup-sealed-secrets-keys.sh

# View storage classes
kubectl get storageclass
```

### GPU Monitoring
```bash
# Check GPU resources available
kubectl describe nodes | grep -A3 -B1 "gpu.intel.com"

# Monitor GPU usage on nodes
intel_gpu_top

# View GPU-enabled pods
kubectl get pods -o wide | grep jellyfin
```

### Adding New Applications
1. Create directory under `apps/<app-name>/`
2. Create `application.yaml` following existing patterns
3. Add configuration files and SealedSecrets as needed
4. Use custom charts in `charts/` for complex applications

## 📖 Documentation

- [SealedSecrets Usage Guide](docs/sealed-secrets.md) - Complete guide for managing encrypted secrets
- [Observability Components Guide](docs/observability-components-guide.md) - Future monitoring components
- [Bootstrap Scripts](bootstrap/README.md) - Cluster maintenance scripts

## 🔐 Security Features

- **Encrypted Secrets** - All secrets encrypted with SealedSecrets
- **OIDC Authentication** - Single sign-on via Authentik
- **Automatic SSL** - Let's Encrypt certificates via cert-manager
- **Network Security** - Traefik ingress with proper TLS termination

## 🏠 Homelab Infrastructure

### Compute Nodes

#### Primary Node - cubancodelab3 (10.5.1.10)
- **CPU**: Intel Core i5-1250P (12th Gen) - 16 cores
- **RAM**: 32GB (25GB available)
- **Storage**: 477GB NVMe SSD (100GB allocated to system)
- **GPU**: Intel Iris Xe Graphics (device-id: 0300-46a6) ✅
- **Role**: Control plane + Worker node
- **OS**: Ubuntu Server with K3s
- **GPU Resources**: `gpu.intel.com/i915: 1` + monitoring

#### Secondary Node - cubancodelab2 (10.5.1.11)
- **CPU**: Intel Core i5-6260U @ 1.80GHz - 4 cores
- **RAM**: 24GB (21GB available)
- **Storage**: 112GB SSD
- **GPU**: Intel Iris Graphics 540 (device-id: 0300-1926) ✅
- **Role**: Worker node
- **OS**: Ubuntu Server with K3s
- **GPU Resources**: `gpu.intel.com/i915: 1` + monitoring

### Storage Infrastructure
- **NAS**: Synology with SSD + HDD tiers
  - `/volume1/k3s-ssd` - 4TB SSD tier for fast storage
  - `/volume2/k3s-hdd` - 8TB HDD tier for bulk storage
  - `/volume2/media` - Direct media access for streaming
- **Local SSD**: 280GB total across nodes for critical workloads

### Hardware Acceleration Capabilities

#### Intel Iris Xe Graphics (cubancodelab3) - Primary for transcoding
- **H.264/H.265** encode/decode ✅
- **AV1** decode ✅
- **Simultaneous streams**: 3-5 x 1080p transcodes
- **Power efficiency**: ~80% CPU reduction vs software

#### Intel Iris Graphics 540 (cubancodelab2) - Backup/overflow
- **H.264** encode/decode ✅
- **H.265** decode (limited) ⚠️
- **Simultaneous streams**: 1-2 x 1080p transcodes
- **Power efficiency**: ~60% CPU reduction vs software

### Network Configuration
- **Cluster Network**: 10.5.1.0/24 VLAN
- **Primary Node**: 10.5.1.10/24
- **Secondary Node**: 10.5.1.11/24
- **NAS**: 10.5.1.5
- **Load Balancing**: MetalLB for bare metal deployments

## 🎮 Media Stack Performance

### Hardware Transcoding Status: ✅ ACTIVE
- **Intel Quick Sync Video** enabled on both nodes
- **GPU scheduling** automatically balances workloads
- **Preferred node**: cubancodelab3 (Iris Xe) for best performance
- **Fallback node**: cubancodelab2 (Iris 540) for overflow

### Expected Performance Improvements
- **Jellyfin transcoding**: 70-80% faster than CPU-only
- **Multiple streams**: 3-5 concurrent 1080p → 720p transcodes
- **CPU utilization**: Reduced from 80% to 15-20% during transcoding
- **Power consumption**: ~30W reduction during heavy transcoding

## 🤝 Contributing

This is a personal homelab setup, but feel free to:
- Open issues for questions
- Submit PRs for improvements
- Use as inspiration for your own setup

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.