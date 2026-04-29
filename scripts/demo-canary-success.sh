#!/usr/bin/env bash
# demo-canary-success.sh — happy-path canary rollout.
#
# Bumps environments/dev/jarvis-web.values.yaml from v1.0.0/blue to v2.0.0/orange,
# applies it via Helm (or `git push`s if you set GITOPS=1 to use Argo CD), and
# tails the rollout so the audience sees pods flip color in real time.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

VALUES=environments/dev/jarvis-web.values.yaml

# Patch the values file in place (tag + theme). yq isn't a hard dep — fall
# back to sed for portability since the file shape is known.
sed -i.bak \
  -e 's/tag: v1.0.0/tag: v2.0.0/' \
  -e 's/tag: v3.0.0-broken/tag: v2.0.0/' \
  -e 's/color: "#1f6feb"/color: "#f97316"/' \
  -e 's/color: "#dc2626"/color: "#f97316"/' \
  -e 's/name: blue/name: orange/' \
  -e 's/name: red/name: orange/' \
  -e 's/failMode: true/failMode: false/' \
  "$VALUES"
rm -f "$VALUES.bak"

echo "Updated $VALUES → v2.0.0 (orange)"
diff <(git show HEAD:"$VALUES" 2>/dev/null || true) "$VALUES" || true

if [[ "${GITOPS:-0}" == "1" ]]; then
  echo
  echo "GITOPS=1 set. Committing and pushing for Argo CD to pick up..."
  git add "$VALUES"
  git commit -m "promote jarvis-web v1.0.0 → v2.0.0"
  git push
else
  echo
  echo "Applying directly via Helm..."
  # --force-conflicts: helm 4 uses server-side apply; argo-rollouts owns the
  # rollout's live spec.strategy.canary.steps and the stable/canary Service
  # selectors after the first install, so we have to take ownership back here.
  helm upgrade --install jarvis-web charts/jarvis-web \
    --namespace jarvis \
    -f "$VALUES" \
    --force-conflicts

  # If the previous rollout was aborted/degraded (e.g. after the failure demo),
  # helm upgrade updates the spec but Argo Rollouts won't progress until retried.
  ROLLOUT_STATUS=$(kubectl get rollout jarvis-web-jarvis-web -n jarvis \
    -o jsonpath='{.status.phase}' 2>/dev/null || true)
  if [[ "$ROLLOUT_STATUS" == "Degraded" ]]; then
    echo "Rollout is in Degraded state — retrying to clear aborted status..."
    kubectl argo rollouts retry rollout jarvis-web-jarvis-web -n jarvis
  fi
fi

echo
echo "Watching rollout. Refresh http://jarvis-web.local — you'll see a mix"
echo "of blue and orange pages as the canary progresses (20% → 50% → 80% → 100%)."
echo
exec kubectl argo rollouts get rollout jarvis-web-jarvis-web -n jarvis --watch
