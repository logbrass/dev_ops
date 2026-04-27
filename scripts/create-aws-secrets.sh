#!/usr/bin/env bash
# Create the Kubernetes Secrets needed by the AWS demo environment.
#
# Nothing secret is stored in git. By default this script generates fresh
# credentials. You can also supply POSTGRES_PASSWORD and/or JWT_SECRET_KEY in
# the environment if you need deterministic values:
#
#   POSTGRES_PASSWORD=... JWT_SECRET_KEY=... ./scripts/create-aws-secrets.sh
#
# The generated/applied secrets are:
#   monitoring/jarvis-postgres-secret: password, postgres-password, replication-password
#   jarvis/jarvis-auth-secret:        DATABASE_URL, JWT_SECRET_KEY
#   jarvis/jarvis-notes-secret:       DATABASE_URL

set -euo pipefail

AWS_REGION=${AWS_REGION:-us-east-1}
APP_NAMESPACE=${APP_NAMESPACE:-jarvis}
PLATFORM_NAMESPACE=${PLATFORM_NAMESPACE:-monitoring}
POSTGRES_SERVICE=${POSTGRES_SERVICE:-jarvis-platform-postgresql.monitoring.svc.cluster.local}
POSTGRES_USER=${POSTGRES_USER:-jarvis}
POSTGRES_DB=${POSTGRES_DB:-jarvis}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-$(openssl rand -hex 24)}
POSTGRES_ADMIN_PASSWORD=${POSTGRES_ADMIN_PASSWORD:-$(openssl rand -hex 24)}
POSTGRES_REPLICATION_PASSWORD=${POSTGRES_REPLICATION_PASSWORD:-$(openssl rand -hex 24)}
JWT_SECRET_KEY=${JWT_SECRET_KEY:-$(openssl rand -hex 32)}

DATABASE_URL="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_SERVICE}:5432/${POSTGRES_DB}"

kubectl create namespace "$APP_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl create namespace "$PLATFORM_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - >/dev/null

kubectl -n "$PLATFORM_NAMESPACE" create secret generic jarvis-postgres-secret \
  --from-literal=password="$POSTGRES_PASSWORD" \
  --from-literal=postgres-password="$POSTGRES_ADMIN_PASSWORD" \
  --from-literal=replication-password="$POSTGRES_REPLICATION_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f - >/dev/null

kubectl -n "$APP_NAMESPACE" create secret generic jarvis-auth-secret \
  --from-literal=DATABASE_URL="$DATABASE_URL" \
  --from-literal=JWT_SECRET_KEY="$JWT_SECRET_KEY" \
  --dry-run=client -o yaml | kubectl apply -f - >/dev/null

kubectl -n "$APP_NAMESPACE" create secret generic jarvis-notes-secret \
  --from-literal=DATABASE_URL="$DATABASE_URL" \
  --dry-run=client -o yaml | kubectl apply -f - >/dev/null

cat <<EOF
✔ AWS demo Kubernetes Secrets applied.

Namespaces:
  $PLATFORM_NAMESPACE/jarvis-postgres-secret
  $APP_NAMESPACE/jarvis-auth-secret
  $APP_NAMESPACE/jarvis-notes-secret

No secret values were written to disk.
EOF
