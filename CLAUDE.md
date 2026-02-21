# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a GitOps-based homelab setup using ArgoCD to manage Kubernetes infrastructure and applications. The repository follows an "app of apps" pattern where a root application deploys both infrastructure components and user applications.

## Key Commands

### Kubernetes Operations
```bash
# Check ArgoCD applications status
kubectl get applications -n argocd

# Sync a specific application
kubectl patch app <app-name> -n argocd -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"syncStrategy":{"hook":{}}}}}' --type merge

# Check sealed-secrets controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=sealed-secrets

# Validate Helm charts
helm template <chart-path> --validate
```

### SealedSecrets Management
```bash
# Create a new sealed secret (homelab specific - requires controller params)
kubectl create secret generic <secret-name> \
  --from-literal=key=value \
  --dry-run=client -o yaml | \
  kubeseal --controller-name=sealed-secrets --controller-namespace=kube-system -o yaml > <secret-name>-sealedsecret.yaml

# Backup sealed secrets keys
./bootstrap/backup-sealed-secrets-keys.sh

# Restore sealed secrets keys
./bootstrap/restore-sealed-secrets-keys.sh <backup-file>

# Validate sealed secret format
kubeseal --controller-name=sealed-secrets --controller-namespace=kube-system --validate -f <sealedsecret>.yaml
```

### Testing and Validation
```bash
# Test Helm chart rendering
helm template charts/<chart-name> --values <values-file>

# Dry run ArgoCD sync
argocd app sync <app-name> --dry-run

# Check application health
kubectl get applications -n argocd -o wide
```

## Architecture

### GitOps Flow
1. **Root App** (`root-app.yaml`) deploys two main apps:
   - Infrastructure app (`infrastructure/infrastructure-app.yaml`)
   - Applications app (`apps/apps-app.yaml`)

2. **Infrastructure Components**:
   - `sealed-secrets/` - SealedSecrets controller for encrypted secrets
   - `cert-manager/` - Certificate management with Cloudflare DNS
   - `traefik/` - Ingress controller and load balancer
   - `metallb/` - Load balancer for bare metal
   - `authentik/` - Identity provider and SSO
   - `kube-prometheus-stack/` - Monitoring (Prometheus, Grafana, Alertmanager)
   - `pihole/` - DNS filtering and ad blocking
   - `node-setup/` - Node-level configurations including:
     - Core manifests (DaemonSets, StorageClasses)
     - `nfs-csi-driver/` - NFS CSI driver for network storage
     - `intel-gpu-plugin/` - Intel GPU device plugin for hardware acceleration

3. **User Applications**:
   - `actual-budget/` - Personal finance management with OIDC config
   - `media-stack/` - Complete media management stack (uses custom chart)
   - `nginx/` - Static web hosting

### Custom Helm Charts
- `charts/homelab-app/` - Generic chart for simple applications with ingress
- `charts/media-stack/` - Comprehensive chart for media management services (Jellyfin, Radarr, Sonarr, Seerr, Prowlarr, qBittorrent)

### Security Model
- All secrets are encrypted using SealedSecrets and stored in `config/` directories
- Custom controller configuration requires `--controller-name=sealed-secrets --controller-namespace=kube-system`
- OIDC authentication via Authentik for supported services
- Automated SSL certificate management via cert-manager + Cloudflare

### Storage Strategy
- Multiple StorageClasses for different performance tiers:
  - `nfs-ssd-fast` - Default class for SSD-backed NFS storage
  - `nfs-hdd-bulk` - HDD-backed storage for large files
  - `fast-ssd-critical` - Local SSD for critical workloads
- NFS CSI driver provides shared storage across cluster nodes
- Storage classes defined in `node-setup/manifests/`

## File Structure

```
.
├── root-app.yaml                    # Root ArgoCD application
├── infrastructure/
│   ├── infrastructure-app.yaml     # Infrastructure app of apps
│   ├── <service>/
│   │   ├── application.yaml        # ArgoCD application definition
│   │   ├── values.yaml             # Helm values
│   │   └── config/                 # Service configs and sealed secrets
│   └── node-setup/                 # Node-level configurations
│       ├── application.yaml        # Main node-setup app
│       ├── manifests/              # Direct K8s manifests
│       │   ├── *-daemonset.yaml
│       │   └── storage-class-*.yaml
│       ├── nfs-csi-driver/         # NFS CSI driver app
│       │   └── application.yaml
│       └── intel-gpu-plugin/       # Intel GPU plugin app
│           └── application.yaml
├── apps/
│   ├── apps-app.yaml              # Applications app of apps
│   └── <app>/
│       ├── application.yaml       # ArgoCD application definition
│       ├── values.yaml            # Helm values (when using external charts)
│       ├── config/                # App configs and sealed secrets (actual-budget)
│       └── *-sealedsecret.yaml    # Direct sealed secrets (media-stack)
├── charts/                        # Custom Helm charts
│   ├── homelab-app/              # Generic app chart
│   └── media-stack/              # Media services chart
├── bootstrap/                     # Cluster bootstrap and maintenance scripts
└── docs/                         # Documentation and guides
```

## Working with SealedSecrets

### Important Configuration
This homelab uses a custom SealedSecrets deployment. Always include these parameters:
- `--controller-name=sealed-secrets`
- `--controller-namespace=kube-system`

### Secret Storage Pattern
Secrets are stored in the `config/` directory of the service that needs them:
- `infrastructure/<service>/config/` - Infrastructure service secrets
- `apps/actual-budget/config/` - Actual Budget OIDC secrets
- `apps/media-stack/` - Media stack secrets directly in app directory

### Key Management
- Keys are automatically rotated every 30 days
- Use `./bootstrap/backup-sealed-secrets-keys.sh` for regular backups
- Store backups securely outside the cluster
- Test restore procedures periodically with `./bootstrap/restore-sealed-secrets-keys.sh`

## Development Workflow

1. **Making Changes**: Edit YAML files directly or update Helm values
2. **Secret Management**: Always use SealedSecrets, store in appropriate `config/` directory
3. **Testing**: Use `helm template` to validate chart changes before committing
4. **Deployment**: ArgoCD automatically syncs changes from the main branch
5. **Monitoring**: Check application status in ArgoCD UI or via kubectl

## Commit Guidelines

### Conventional Commits
All commits must follow the Conventional Commits specification:

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

**Types:**
- `feat`: A new feature
- `fix`: A bug fix
- `docs`: Documentation only changes
- `style`: Changes that do not affect the meaning of the code
- `refactor`: A code change that neither fixes a bug nor adds a feature
- `perf`: A code change that improves performance
- `test`: Adding missing tests or correcting existing tests
- `chore`: Changes to the build process or auxiliary tools

**Examples:**
```
feat(media-stack): add seerr service to media stack chart
fix(traefik): resolve ingress routing issue for authentik
docs: update sealed secrets usage guide
chore(cert-manager): update to v1.13.0
```

### Commit Rules
- NEVER reference AI tools or assistants in commit messages
- NEVER include CLAUDE.md in commits
- Keep commit messages concise but descriptive
- Use imperative mood ("add" not "added")
- Reference issues when applicable

## Common Patterns

### Adding New Applications
1. Create directory under `apps/<app-name>/`
2. Create `application.yaml` following existing patterns
3. Add Helm values in `values.yaml` for external charts OR use custom charts
4. Use `charts/homelab-app` for simple apps with ingress needs
5. Create `config/` subdirectory for sealed secrets if needed

### Managing Secrets
- Create secrets in the `config/` directory of the app that uses them
- This keeps secrets close to where they're consumed
- Always use the SealedSecrets controller parameters specific to this homelab
- Examples: `infrastructure/authentik/config/`, `apps/actual-budget/config/`

### Troubleshooting
1. Check ArgoCD application status and sync errors
2. Review controller logs for sealed-secrets issues
3. Use `kubectl describe` on failed resources
4. Check ingress and certificate status for connectivity issues
5. Consult `docs/sealed-secrets.md` for detailed SealedSecrets usage