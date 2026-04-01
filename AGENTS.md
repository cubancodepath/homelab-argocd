# AGENTS.md

This file is for agentic coding tools working in this repo.
It summarizes how to build, validate, and style changes.

## Repo summary
- GitOps homelab using ArgoCD (app of apps).
- Mostly Kubernetes YAML, Helm charts, and a few Bash scripts.
- Secrets are stored as SealedSecrets in per-app config directories.

## Build, lint, test, validate
There is no dedicated build/test framework in this repo.
Validation is typically done via Helm template rendering and kubectl checks.

### Helm template validation
```bash
# Render a chart with values
helm template charts/homelab-app --values charts/homelab-app/values.yaml

# Render a chart with validation (example)
helm template charts/homelab-app --validate

# Render an app values file (example)
helm template charts/homelab-app --values apps/nginx/values.yaml
```

### ArgoCD and cluster checks
```bash
# List ArgoCD applications
kubectl get applications -n argocd

# Dry-run sync an app
argocd app sync <app-name> --dry-run

# Check application health
kubectl get applications -n argocd -o wide
```

### Storage notes
- Default StorageClass: longhorn-2replicas (2-node HA).
- NFS dynamic provisioners: nfs-ssd and nfs-hdd.
- shared-media-pvc stays as a static NFS claim on /volume2/media.

### SealedSecrets validation
```bash
# Validate a SealedSecret (custom controller name/namespace)
kubeseal \
  --controller-name=sealed-secrets \
  --controller-namespace=kube-system \
  --validate -f <sealedsecret>.yaml
```

### Single test guidance
There are no unit/integration tests in this repo.
If you need a single-target validation, use Helm template on the specific
chart or values file you modified (see Helm commands above).

## Cursor/Copilot rules
No .cursor/rules/, .cursorrules, or .github/copilot-instructions.md were found.

## Repository layout
- root-app.yaml: root ArgoCD app (app of apps)
- infrastructure/: infra apps and configs
- apps/: user apps and configs
- charts/: custom Helm charts
- bootstrap/: maintenance scripts
- docs/: guides

## Code style guidelines

### YAML (Kubernetes and values)
- Use 2-space indentation.
- Keep key order conventional: apiVersion, kind, metadata, spec.
- Use quoted strings for values that could be parsed as numbers or booleans.
- Prefer explicit namespaces in manifests and ArgoCD applications.
- Use consistent labels/annotations with app.kubernetes.io/* where relevant.

### ArgoCD Application manifests
- Keep Application names aligned with their directory (e.g., apps/<app>/application.yaml).
- Use repoURL/targetRevision/path patterns consistent with existing apps.
- Keep syncPolicy.automated enabled unless the app explicitly requires manual sync.
- Prefer syncOptions CreateNamespace=true; add ServerSideApply=true when already used.
- Avoid hardcoding secrets or credentials in Application manifests.

### Helm charts and templates
- Use helper templates for names/labels (see charts/homelab-app/templates/_helpers.tpl).
- Use nindent with include/toYaml to keep indentation correct.
- Wrap optional blocks with with/end to avoid empty keys.
- Keep template logic minimal; move structure into values.yaml when possible.
- Keep resource names under 63 chars (DNS label limits).
- For Bitnami charts pinned to public.ecr.aws, set global.security.allowInsecureImages: true to avoid image verification errors.

### SealedSecrets
- Always use the custom controller name and namespace:
  --controller-name=sealed-secrets
  --controller-namespace=kube-system
- Store SealedSecrets in the service config directory:
  infrastructure/<service>/config/
  apps/<app>/config/ (or app root for media stack)
- Do not commit unsealed Secret manifests.

### Bash scripts
- Use bash with set -euo pipefail.
- Quote variables and paths.
- Prefer functions for steps, and log helpers for messages.
- Use descriptive variable names in SCREAMING_SNAKE_CASE for constants.
- Handle errors explicitly and exit non-zero on failure.

### Naming conventions
- Kubernetes resources use kebab-case.
- YAML filenames are kebab-case; sealed secret files end with -sealedsecret.yaml.
- ArgoCD Application names are short and match the directory name.
- Helm values keys use lowerCamelCase or lower_snake_case as already present.

### Imports and types
- This repo has no application code; keep templates and YAML declarative.
- Avoid embedding logic in values; keep computed logic in templates.

### Error handling and safety
- Do not edit or commit CLAUDE.md.
- Do not delete or rotate SealedSecrets keys without explicit direction.
- Avoid destructive kubectl commands in automation scripts.

## Common workflows

### Adding a new application
1) Create apps/<app-name>/application.yaml.
2) Add values.yaml for chart configuration if needed.
3) Add config/ with SealedSecrets or related manifests.
4) Validate with helm template and commit.

### Updating an existing chart
1) Update templates or values.
2) Render with helm template using the app values file.
3) Check that labels/selectors remain consistent.

### Secret updates
1) Create a Secret via kubectl create secret ... --dry-run=client -o yaml.
2) Pipe to kubeseal with the custom controller settings.
3) Store the sealed secret in the correct config directory.

## Helpful commands from repo docs
```bash
# Sync all applications in ArgoCD (label-based)
argocd app sync -l app.kubernetes.io/instance=homelab-root

# Check sealed-secrets controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=sealed-secrets

# Backup SealedSecrets keys
./bootstrap/backup-sealed-secrets-keys.sh
```
