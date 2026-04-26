# Bootstrap

This directory holds the install manifests for the controllers that run inside
the cluster. They are applied directly by `scripts/bootstrap.sh` (not by Argo
CD itself, since Argo CD doesn't exist yet at that point).

| Tool | Purpose |
| --- | --- |
| Argo CD | Reconciles the contents of `gitops/apps/` into the cluster. |
| Argo Rollouts | Owns the `Rollout` and `AnalysisTemplate` CRs that drive canary delivery. |

We install both via their official upstream manifests pinned to a known-good
release.
