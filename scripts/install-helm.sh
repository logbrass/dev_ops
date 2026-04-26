#!/usr/bin/env bash
# install-helm.sh — direct Helm deploy (no GitOps). Useful for offline demos
# and for verifying the charts in isolation before exercising Argo CD.
#
# Reads from environments/dev/*.values.yaml so the same values files are used
# whether you go through Helm or Argo CD.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

step() { printf "\n\033[1;36m==> %s\033[0m\n" "$*"; }

kubectl create namespace jarvis --dry-run=client -o yaml | kubectl apply -f -

step "Installing Postgres (bitnami chart, namespace=jarvis)"
helm repo add bitnami https://charts.bitnami.com/bitnami >/dev/null 2>&1 || true
helm repo update >/dev/null
helm upgrade --install jarvis-postgres bitnami/postgresql \
  --namespace jarvis \
  --version 15.5.20 \
  --set auth.username=jarvis \
  --set auth.password=password \
  --set auth.database=jarvis \
  --set primary.persistence.size=1Gi \
  --wait --timeout 5m

step "Installing jarvis-auth"
helm upgrade --install jarvis-auth charts/jarvis-auth \
  --namespace jarvis \
  -f environments/dev/jarvis-auth.values.yaml \
  --set env.DATABASE_URL="postgresql://jarvis:password@jarvis-postgres-postgresql:5432/jarvis"

step "Installing jarvis-notes"
helm upgrade --install jarvis-notes charts/jarvis-notes \
  --namespace jarvis \
  -f environments/dev/jarvis-notes.values.yaml \
  --set env.DATABASE_URL="postgresql://jarvis:password@jarvis-postgres-postgresql:5432/jarvis"

step "Installing jarvis-web (Argo Rollouts canary)"
helm upgrade --install jarvis-web charts/jarvis-web \
  --namespace jarvis \
  -f environments/dev/jarvis-web.values.yaml

step "Loading Grafana dashboard"
kubectl -n monitoring create configmap jarvis-canary-dashboard \
  --from-file=monitoring/dashboards/jarvis-canary.json \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n monitoring label --overwrite cm/jarvis-canary-dashboard grafana_dashboard=1

step "Waiting for rollout"
kubectl -n jarvis wait --for=condition=Available --timeout=120s \
  deploy/jarvis-auth-jarvis-auth deploy/jarvis-notes-jarvis-notes 2>/dev/null || true

cat <<EOF

\033[1;32m✔ apps deployed.\033[0m

Open http://jarvis-web.local in your browser — you should see a blue page
labeled "Jarvis v1.0.0".

To roll out v2.0.0 (orange):
  ./scripts/demo-canary-success.sh

To trigger an automatic rollback (red v3 → broken):
  ./scripts/demo-canary-rollback.sh
EOF
