#!/usr/bin/env bash
# bootstrap.sh — one-command setup for the Jarvis GitOps canary demo.
#
# Idempotent: safe to re-run. Does the following:
#   1. Start a Minikube cluster with enough resources for the stack
#   2. Enable the NGINX ingress addon (Argo Rollouts uses it for traffic split)
#   3. Build the three jarvis-web image tags (v1.0.0, v2.0.0, v3.0.0-broken)
#      and load them into the Minikube node so we don't need a registry
#   4. Build the Jarvis backend images (auth, notes) the same way
#   5. Install Argo Rollouts controller (CRDs + operator)
#   6. Install Argo CD (CRDs + operator)
#   7. Install kube-prometheus-stack via Helm (Prometheus + Grafana + Operator)
#
# After this script finishes, run scripts/install-helm.sh to deploy the apps.
# If you want full GitOps, push this repo to GitHub and run install-argocd.sh.

set -euo pipefail

MINIKUBE_PROFILE=${MINIKUBE_PROFILE:-jarvis}
MINIKUBE_CPUS=${MINIKUBE_CPUS:-4}
MINIKUBE_MEMORY=${MINIKUBE_MEMORY:-6g}
ARGO_ROLLOUTS_VERSION=${ARGO_ROLLOUTS_VERSION:-v1.7.2}
ARGOCD_VERSION=${ARGOCD_VERSION:-v2.13.1}
KPS_VERSION=${KPS_VERSION:-65.5.1}

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

step() { printf "\n\033[1;36m==> %s\033[0m\n" "$*"; }
ok()   { printf "\033[1;32m✔\033[0m %s\n" "$*"; }

step "Checking prerequisites"
for bin in docker minikube kubectl helm; do
  command -v "$bin" >/dev/null || { echo "missing: $bin"; exit 1; }
done
docker info >/dev/null 2>&1 || { echo "Docker daemon not running. Start Docker Desktop and retry."; exit 1; }
ok "tooling ok"

step "Starting Minikube ($MINIKUBE_PROFILE, ${MINIKUBE_CPUS} CPUs, ${MINIKUBE_MEMORY} RAM)"
if ! minikube -p "$MINIKUBE_PROFILE" status >/dev/null 2>&1; then
  minikube start -p "$MINIKUBE_PROFILE" \
    --cpus="$MINIKUBE_CPUS" --memory="$MINIKUBE_MEMORY" \
    --driver=docker
fi
minikube -p "$MINIKUBE_PROFILE" addons enable ingress
minikube -p "$MINIKUBE_PROFILE" addons enable metrics-server || true
kubectl config use-context "$MINIKUBE_PROFILE"
ok "cluster up: $(kubectl config current-context)"

step "Building jarvis-web images (v1 blue, v2 orange, v3 broken)"
# Each tag uses the same Dockerfile; the version/color/fail-mode are passed in
# via env vars at deploy time (see charts/jarvis-web/templates/rollout.yaml).
docker build -t jarvis-web:v1.0.0       app/jarvis-web
docker tag    jarvis-web:v1.0.0          jarvis-web:v2.0.0
docker tag    jarvis-web:v1.0.0          jarvis-web:v3.0.0-broken
ok "built jarvis-web:v1.0.0, v2.0.0, v3.0.0-broken"

step "Building Jarvis backend images (auth, notes)"
docker build -t jarvis-auth:latest  -f app/jarvis-backend/services/auth/Dockerfile  app/jarvis-backend
docker build -t jarvis-notes:latest -f app/jarvis-backend/services/notes/Dockerfile app/jarvis-backend
ok "built jarvis-auth:latest, jarvis-notes:latest"

step "Loading images into Minikube node (no registry needed for the demo)"
for img in jarvis-web:v1.0.0 jarvis-web:v2.0.0 jarvis-web:v3.0.0-broken \
           jarvis-auth:latest jarvis-notes:latest; do
  minikube -p "$MINIKUBE_PROFILE" image load "$img"
done
ok "images loaded"

step "Installing Argo Rollouts $ARGO_ROLLOUTS_VERSION"
kubectl create namespace argo-rollouts --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argo-rollouts \
  -f "https://github.com/argoproj/argo-rollouts/releases/download/${ARGO_ROLLOUTS_VERSION}/install.yaml"
kubectl rollout status -n argo-rollouts deploy/argo-rollouts --timeout=120s
ok "argo-rollouts ready"

step "Installing Argo CD $ARGOCD_VERSION"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"
kubectl rollout status -n argocd deploy/argocd-server --timeout=180s
ok "argo-cd ready"

step "Installing kube-prometheus-stack $KPS_VERSION (Prometheus + Grafana)"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update >/dev/null
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --version "$KPS_VERSION" \
  --set defaultRules.create=false \
  --set alertmanager.enabled=false \
  --set nodeExporter.enabled=false \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.ruleSelectorNilUsesHelmValues=false \
  --set grafana.adminPassword=admin \
  --set grafana.defaultDashboardsEnabled=false \
  --set grafana.sidecar.dashboards.enabled=true \
  --set grafana.sidecar.dashboards.searchNamespace=ALL \
  --wait --timeout 5m
ok "prometheus + grafana ready"

INGRESS_IP=$(minikube -p "$MINIKUBE_PROFILE" ip)
if [[ "${SKIP_HOSTS:-0}" == "1" ]]; then
  ok "SKIP_HOSTS=1 set — skipping /etc/hosts edit. Manually run:"
  echo "    echo \"$INGRESS_IP jarvis-web.local\" | sudo tee -a /etc/hosts"
else
  step "Adding /etc/hosts entry for jarvis-web.local (sudo prompt may appear)"
  if ! grep -q "jarvis-web.local" /etc/hosts; then
    echo "$INGRESS_IP jarvis-web.local" | sudo tee -a /etc/hosts >/dev/null
    ok "added $INGRESS_IP jarvis-web.local to /etc/hosts"
  else
    ok "/etc/hosts already has jarvis-web.local"
  fi
fi

cat <<EOF

\033[1;32m========================================\033[0m
\033[1;32m  Bootstrap complete.\033[0m
\033[1;32m========================================\033[0m

Next steps:

  # Deploy the apps via Helm (default — works offline):
  ./scripts/install-helm.sh

  # Or, after pushing this repo to GitHub, deploy via Argo CD GitOps:
  REPO_URL=https://github.com/<you>/dev_ops.git ./scripts/install-argocd.sh

Quick links once installed:

  Jarvis web :  http://jarvis-web.local
  Argo CD    :  kubectl -n argocd port-forward svc/argocd-server 8083:443
                user: admin
                pass: \$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)
  Grafana    :  kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
                user: admin / pass: admin
  Argo Rollouts dashboard:
                kubectl argo rollouts dashboard
EOF
