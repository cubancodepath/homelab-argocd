#!/bin/bash

# Helper script to create Plane sealed secrets
# Run this BEFORE syncing the ArgoCD application

set -e

NAMESPACE="plane"
CONTROLLER_NAME="sealed-secrets"
CONTROLLER_NS="kube-system"

echo "📝 Creating Plane Sealed Secrets"
echo "================================"

# Generate SECRET_KEY (50-char random string)
echo ""
echo "🔑 Generating SECRET_KEY..."
SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(50))")
echo "SECRET_KEY: $SECRET_KEY"

# Generate LIVE_SERVER_SECRET_KEY
echo ""
echo "🔑 Generating LIVE_SERVER_SECRET_KEY..."
LIVE_SERVER_SECRET=$(python3 -c "import secrets; print(secrets.token_urlsafe(50))")
echo "LIVE_SERVER_SECRET_KEY: $LIVE_SERVER_SECRET"

# Get PostgreSQL password from existing secret
echo ""
echo "🗄️  Fetching PostgreSQL password..."
PG_PASSWORD=$(kubectl get secret -n database postgresql-secret -o jsonpath='{.data.password}' | base64 -d)
PG_URL="postgresql://plane:${PG_PASSWORD}@postgresql.database.svc.cluster.local:5432/plane"

# TODO: Get MinIO credentials - user needs to set these manually
echo ""
echo "⚠️  MinIO credentials required:"
echo "   Please provide:"
echo "   - MINIO_ACCESS_KEY: Access key from MinIO service account"
echo "   - MINIO_SECRET_KEY: Secret key from MinIO service account"
echo ""
read -p "Enter MinIO Access Key: " MINIO_ACCESS_KEY
read -sp "Enter MinIO Secret Key: " MINIO_SECRET_KEY
echo ""

# Create plane-app-secret
echo ""
echo "📦 Creating plane-app-secret..."
kubectl create secret generic plane-app-secret \
  --namespace=$NAMESPACE \
  --from-literal=SECRET_KEY="$SECRET_KEY" \
  --from-literal=DATABASE_URL="$PG_URL" \
  --from-literal=LIVE_SERVER_SECRET_KEY="$LIVE_SERVER_SECRET" \
  --dry-run=client -o yaml | \
  kubeseal --controller-name=$CONTROLLER_NAME --controller-namespace=$CONTROLLER_NS -o yaml > config/plane-app-sealedsecret.yaml

echo "✅ Created: config/plane-app-sealedsecret.yaml"

# Create plane-storage-secret
echo ""
echo "📦 Creating plane-storage-secret..."
kubectl create secret generic plane-storage-secret \
  --namespace=$NAMESPACE \
  --from-literal=USE_MINIO="1" \
  --from-literal=AWS_ACCESS_KEY_ID="$MINIO_ACCESS_KEY" \
  --from-literal=AWS_SECRET_ACCESS_KEY="$MINIO_SECRET_KEY" \
  --from-literal=AWS_S3_BUCKET_NAME="plane-uploads" \
  --from-literal=AWS_S3_ENDPOINT_URL="http://minio.storage.svc.cluster.local:9000" \
  --from-literal=AWS_REGION="us-east-1" \
  --from-literal=FILE_SIZE_LIMIT="5242880" \
  --dry-run=client -o yaml | \
  kubeseal --controller-name=$CONTROLLER_NAME --controller-namespace=$CONTROLLER_NS -o yaml > config/plane-storage-sealedsecret.yaml

echo "✅ Created: config/plane-storage-sealedsecret.yaml"

echo ""
echo "✨ Sealed secrets created successfully!"
echo "   - Commit these files to git"
echo "   - Sync the ArgoCD application"
