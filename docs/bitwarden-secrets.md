# Bitwarden Secrets Manager (Test Flow)

This repo includes a test integration with Bitwarden Secrets Manager (BWS)
using External Secrets Operator (ESO) and the Bitwarden SDK Server. The goal
is to validate the workflow before any migration of existing SealedSecrets.

## Components in this repo

- ESO + Bitwarden SDK server ArgoCD app:
  - `infrastructure/external-secrets/application.yaml`
  - `infrastructure/external-secrets/values.yaml`
  - `infrastructure/external-secrets/config/bitwarden-sdk-cert.yaml`
- Test app using the custom chart:
  - `apps/bitwarden-test/application.yaml`
  - `apps/bitwarden-test/values.yaml`
  - `apps/bitwarden-test/config/bitwarden-secretstore.yaml`
  - `apps/bitwarden-test/config/bitwarden-externalsecret.yaml`

## Prerequisites

- `cert-manager` is installed and working.
- Access to Bitwarden Secrets Manager (not Password Manager).
- ArgoCD is running.

## Setup steps (first tasks during cluster bring-up)

### 1) Create Bitwarden Project and secrets

Create a project in BWS and add two secrets (names must match):

- `DB_PASSWORD`
- `API_KEY`

Generate a **machine account access token** with access to this project.

### 2) Sync ESO and SDK server

Ensure the ArgoCD application is synced:

```bash
argocd app sync external-secrets
```

This installs the Bitwarden SDK Server and creates a TLS cert in
`external-secrets` namespace.

### 3) Create the access token secret (global)

Token must **not** be stored in Git. Create it manually:

```bash
kubectl -n external-secrets create secret generic bitwarden-access-token \
  --from-literal=token='BWS_ACCESS_TOKEN'
```

### 4) Fill the ClusterSecretStore values

Update `infrastructure/external-secrets/config/bitwarden-clustersecretstore.yaml`:

- `organizationID`
- `projectID`
- `caBundle`

To get `caBundle` (base64):

```bash
kubectl -n external-secrets get secret bitwarden-tls-certs \
  -o jsonpath='{.data.ca\.crt}'
```

If `ca.crt` does not exist, use `tls.crt` instead:

```bash
kubectl -n external-secrets get secret bitwarden-tls-certs \
  -o jsonpath='{.data.tls\.crt}'
```

### 5) Sync the test app

```bash
argocd app sync bitwarden-test
```

### 6) Force sync and validate

```bash
kubectl -n bitwarden-test annotate externalsecret bitwarden-test-secret \
  "external-secrets.io/refresh-now=$(date +%s)" --overwrite

kubectl -n bitwarden-test get secret bitwarden-test-secret
```

If the secret exists, the flow is working.

## Notes

- The `SecretStore` and `ExternalSecret` are using `v1beta1` API.
- This is a **test-only** setup to validate the workflow before migration.
- Rotate the BWS access token periodically.

## Outline migration (parallel to SealedSecrets)

This repo includes a parallel Bitwarden flow for Outline. The SealedSecrets
remain intact, while Outline is pointed to new Bitwarden-backed secrets.

### Create secrets in Bitwarden

In the same BWS project, create these secret names:

- `outline-secret-key`
- `outline-utils-secret`
- `outline-postgres-password`
- `outline-minio-access-key-id`
- `outline-minio-secret-access-key`
- `outline-oidc-client-secret`

If you use a different BWS project for Outline, update
`infrastructure/external-secrets/config/bitwarden-clustersecretstore.yaml` with the correct IDs.

### Use the global access token secret

```bash
Ensure the secret exists in `external-secrets`:

```bash
kubectl -n external-secrets get secret bitwarden-access-token
```
```

### Sync and verify

```bash
argocd app sync outline
kubectl -n outline get secret outline-app-secret-bws
kubectl -n outline get secret outline-db-secret-bws
kubectl -n outline get secret outline-minio-secret-bws
kubectl -n outline get secret outline-oidc-secret-bws
```
