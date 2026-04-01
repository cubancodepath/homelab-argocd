# Plane CE Deployment Guide

This directory contains the ArgoCD application definition for deploying [Plane CE](https://plane.so) (Community Edition) on the homelab cluster.

## Architecture

- **Database**: External PostgreSQL at `postgresql.database.svc.cluster.local:5432`
- **Storage**: External MinIO at `minio.storage.svc.cluster.local:9000`
- **Cache**: Internal Valkey (Redis-compatible)
- **Message Queue**: Internal RabbitMQ
- **Ingress**: Traefik + cert-manager TLS at `plane.cubancodelab.net`
- **SSO**: Authentik OAuth2/OIDC (configured post-deploy in god-mode)

## Pre-Deployment Steps

### 1. Create PostgreSQL Database

Plane requires a dedicated `plane` database and user in PostgreSQL:

```bash
# Option A: Port-forward and connect directly
kubectl port-forward -n database svc/postgresql 5432:5432 &
psql -h localhost -U postgres

# Then run in psql:
CREATE DATABASE plane;
CREATE USER plane WITH ENCRYPTED PASSWORD 'your-secure-password';
GRANT ALL PRIVILEGES ON DATABASE plane TO plane;
\q
```

**Option B**: Add to `infrastructure/postgresql/values.yaml`:

```yaml
initdbScripts:
  plane.sql: |
    CREATE DATABASE plane;
    CREATE USER plane WITH ENCRYPTED PASSWORD 'your-secure-password';
    GRANT ALL PRIVILEGES ON DATABASE plane TO plane;
```

Then redeploy PostgreSQL via ArgoCD.

### 2. Create MinIO Bucket and Service Account

Log into MinIO console at `https://minio-console.cubancodelab.net`:

1. **Create Bucket**: `plane-uploads`
2. **Create Service Account**:
   - Go to **Access Keys** → **Create Access Key**
   - Set scope to the `plane-uploads` bucket
   - Copy the Access Key and Secret Key

### 3. Generate and Seal Secrets

Run the provided script:

```bash
cd apps/plane
chmod +x CREATE_SECRETS.sh
./CREATE_SECRETS.sh
```

The script will:
- Generate cryptographic keys (`SECRET_KEY`, `LIVE_SERVER_SECRET_KEY`)
- Retrieve PostgreSQL password from existing secrets
- Prompt for MinIO credentials
- Create and seal the secrets using kubeseal

The sealed secrets will be written to:
- `config/plane-app-sealedsecret.yaml`
- `config/plane-storage-sealedsecret.yaml`

**Commit these files to git** — they are encrypted and safe to store in the repo.

## Deployment

Once secrets are created, commit and push:

```bash
git add apps/plane/
git commit -m "feat(plane): add Plane CE application deployment"
git push
```

ArgoCD will automatically sync the application in the `plane` namespace.

## Verification

```bash
# Check ArgoCD application status
kubectl get applications -n argocd plane

# Check pod status
kubectl get pods -n plane

# Check ingress + TLS
curl -I https://plane.cubancodelab.net

# Monitor deployment
kubectl logs -n plane -l app=plane-api -f
```

Expected behavior:
- All pods running (api, ws, worker, migrator, scheduler)
- Database migrations complete (check logs)
- Ingress shows valid Let's Encrypt certificate

## Post-Deployment: OIDC with Authentik

Plane CE does not support OIDC configuration via Helm values. Instead, SSO must be configured manually in the admin panel.

### Step 1: Create OAuth2 Provider in Authentik

In Authentik (`https://auth.cubancodelab.net`):

1. **Create OAuth2/OpenID Connect Provider**:
   - Name: `plane`
   - Client type: `Confidential`
   - Scopes: `openid`, `profile`, `email`
   - Redirect URI: `https://plane.cubancodelab.net/auth/oidc/callback/`

2. **Create Application**:
   - Name: `plane`
   - Slug: `plane`
   - Launch URL: `https://plane.cubancodelab.net`
   - Link to the OAuth2 provider created above

3. **Note the credentials**:
   - Client ID
   - Client Secret

### Step 2: Configure in Plane

1. Log into `https://plane.cubancodelab.net/god-mode/`
2. Go to **Settings** → **Integrations** → **OIDC/OAuth**
3. Fill in:
   - **Client ID**: From Authentik provider
   - **Client Secret**: From Authentik provider
   - **Authorization URL**: `https://auth.cubancodelab.net/application/o/authorize/`
   - **Token URL**: `https://auth.cubancodelab.net/application/o/token/`
   - **UserInfo URL**: `https://auth.cubancodelab.net/application/o/userinfo/`

4. Test by logging out and clicking the OIDC provider option

## Troubleshooting

### Database Connection Failed

Check if `plane` database and user exist:

```bash
kubectl exec -it -n database postgresql-0 -- \
  psql -U postgres -c "SELECT * FROM pg_user WHERE usename='plane';"
```

### MinIO Upload Fails

Verify MinIO credentials and bucket:

```bash
# Check pod logs
kubectl logs -n plane -l app=plane-api | grep -i minio

# Verify credentials are in sealed secret
kubectl get secret -n plane plane-storage-secret -o yaml
```

### Pods Won't Start

Check for image pull issues:

```bash
kubectl describe pod -n plane <pod-name>
kubectl logs -n plane <pod-name>
```

### OIDC Not Working

1. Verify Authentik provider was created with correct redirect URI
2. Check Plane god-mode configuration matches Authentik endpoints
3. Check browser console for OAuth errors

## References

- [Plane Helm Chart](https://github.com/makeplane/helm-charts)
- [Plane Documentation](https://docs.plane.so)
- [Plane CE vs Pro Features](https://docs.plane.so/self-hosting-community-edition)
