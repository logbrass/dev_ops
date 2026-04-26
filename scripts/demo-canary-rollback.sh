#!/usr/bin/env bash
# demo-canary-rollback.sh — failure-path canary that auto-rolls back.
#
# Bumps to v3.0.0-broken (FAIL_MODE=true → service returns 5xx). Argo Rollouts
# pauses at 20%, runs the success-rate AnalysisTemplate, sees it fail, and
# rolls back to the previous stable revision automatically — no human touches
# the cluster.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

VALUES=environments/dev/jarvis-web.values.yaml

sed -i.bak \
  -e 's/tag: v1.0.0/tag: v3.0.0-broken/' \
  -e 's/tag: v2.0.0/tag: v3.0.0-broken/' \
  -e 's/color: "#1f6feb"/color: "#dc2626"/' \
  -e 's/color: "#f97316"/color: "#dc2626"/' \
  -e 's/name: blue/name: red/' \
  -e 's/name: orange/name: red/' \
  -e 's/failMode: false/failMode: true/' \
  "$VALUES"
rm -f "$VALUES.bak"

echo "Updated $VALUES → v3.0.0-broken (red, FAIL_MODE=true)"

if [[ "${GITOPS:-0}" == "1" ]]; then
  git add "$VALUES"
  git commit -m "(intentionally broken) jarvis-web → v3.0.0-broken"
  git push
else
  helm upgrade --install jarvis-web charts/jarvis-web \
    --namespace jarvis \
    -f "$VALUES"
fi

echo
echo "Watching rollout — expect AnalysisRun to fail and the rollout to abort"
echo "automatically, returning all traffic to the previous stable version."
echo
exec kubectl argo rollouts get rollout jarvis-web-jarvis-web -n jarvis --watch
