# Bootstrap

This directory holds the install manifests for the controllers that run inside
the cluster. They are applied directly by `scripts/bootstrap.sh` for local
Minikube, or by the AWS setup process, not by Argo CD itself because Argo CD
does not exist yet at that point.

| Tool | Purpose |
| --- | --- |
| Argo CD | Reconciles the contents of `gitops/apps/` into the cluster. |
| Argo Rollouts | Owns the `Rollout`, `AnalysisTemplate`, and traffic shifting logic that drive canary delivery. |

We install both via their official upstream manifests pinned to a known-good
release.

## App-of-Apps bootstrap

After Argo CD is installed, bootstrap the app tree with:

```bash
kubectl apply -f gitops/apps/root.yaml
```

`gitops/apps/root.yaml` points Argo CD at:

```text
https://github.com/logbrass/dev_ops.git
```

and recursively applies the child Applications in `gitops/apps/`:

| Application | Destination namespace | Chart | Values file |
| --- | --- | --- | --- |
| `jarvis-platform` | `monitoring` | `charts/jarvis-platform` | `../../environments/aws/jarvis-platform.values.yaml` |
| `jarvis-auth` | `jarvis` | `charts/jarvis-auth` | `../../environments/aws/jarvis-auth.values.yaml` |
| `jarvis-notes` | `jarvis` | `charts/jarvis-notes` | `../../environments/aws/jarvis-notes.values.yaml` |
| `jarvis-web` | `jarvis` | `charts/jarvis-web` | `../../environments/aws/jarvis-web.values.yaml` |

Verify with:

```bash
kubectl -n argocd get applications
kubectl -n argocd get application jarvis-web
kubectl -n jarvis get rollout jarvis-web-jarvis-web
```

A healthy AWS demo state shows `jarvis-root`, `jarvis-platform`, `jarvis-auth`,
`jarvis-notes`, and `jarvis-web` as `Synced` / `Healthy`.

## Private repo caveat

Argo CD runs inside the cluster and does not inherit your laptop's GitHub
credentials. If this repo is private, `jarvis-root` will fail with an
`authentication required` comparison error until repository credentials are
added to Argo CD out-of-band. Do not commit GitHub tokens or SSH keys.

The current low-risk AWS demo path assumes Argo CD can read this repo and that
changes are made by committing edits to `environments/aws/jarvis-web.values.yaml`.
