#!/usr/bin/env bash
# demo-reset.sh — returns the cluster and values file to a clean v1.0.0/blue
# stable state so any demo can be run fresh from the beginning.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

VALUES=environments/dev/jarvis-web.values.yaml
ROLLOUT=jarvis-web-jarvis-web
NAMESPACE=jarvis

echo "Aborting any in-progress rollout..."
kubectl argo rollouts abort "$ROLLOUT" -n "$NAMESPACE" 2>/dev/null || true

echo "Resetting $VALUES → v1.0.0 (blue)..."
sed -i.bak \
  -e 's/tag: v2\.0\.0/tag: v1.0.0/' \
  -e 's/tag: v3\.0\.0-broken/tag: v1.0.0/' \
  -e 's/color: "#f97316"/color: "#1f6feb"/' \
  -e 's/color: "#dc2626"/color: "#1f6feb"/' \
  -e 's/name: orange/name: blue/' \
  -e 's/name: red/name: blue/' \
  -e 's/failMode: true/failMode: false/' \
  "$VALUES"
rm -f "$VALUES.bak"

echo "Applying v1.0.0 via Helm..."
helm upgrade --install jarvis-web charts/jarvis-web \
  --namespace "$NAMESPACE" \
  -f "$VALUES" \
  --force-conflicts

echo "Clearing degraded state with retry (instant-completes since desired == stable)..."
kubectl argo rollouts retry rollout "$ROLLOUT" -n "$NAMESPACE" 2>/dev/null || true

echo "Waiting for rollout to reach Healthy/Stable..."
kubectl argo rollouts status "$ROLLOUT" -n "$NAMESPACE" --timeout 60s

echo
echo "Done. Cluster is clean at v1.0.0 (blue). Ready to run any demo."
kubectl argo rollouts get rollout "$ROLLOUT" -n "$NAMESPACE"
