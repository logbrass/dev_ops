#!/usr/bin/env bash
# install-argocd.sh — bootstraps the GitOps flow.
#
# Prerequisite: this repo must be pushed to GitHub (or any git remote Argo CD
# can reach) and REPO_URL must be set to its HTTPS clone URL.
#
# Once applied, Argo CD will start reconciling the contents of gitops/apps/
# into the cluster automatically.

set -euo pipefail

if [[ -z "${REPO_URL:-}" ]]; then
  echo "REPO_URL env var is required, e.g.:"
  echo "  REPO_URL=https://github.com/cis1912/dev_ops.git $0"
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

step() { printf "\n\033[1;36m==> %s\033[0m\n" "$*"; }

step "Patching gitops/apps/*.yaml repoURL → $REPO_URL"
TMP=$(mktemp -d)
for f in gitops/apps/*.yaml; do
  sed "s|https://github.com/cis1912/dev_ops.git|$REPO_URL|g" "$f" > "$TMP/$(basename "$f")"
done

step "Applying root Application (App-of-Apps)"
kubectl -n argocd apply -f "$TMP/root.yaml"

cat <<EOF

\033[1;32m✔ Argo CD root application applied.\033[0m

Argo CD will now sync the rest of the apps. Watch progress:

  kubectl -n argocd get applications
  argocd app list   # if you have the argocd CLI installed
EOF
