# AWS demo environment

These values are safe to commit. They intentionally do **not** contain database
passwords, JWT signing keys, or full `DATABASE_URL` values.

## Live demo target

The AWS demo cluster is already deployed and currently used for the
values-driven GitOps canary demo.

| Item | Value |
| --- | --- |
| AWS account | `733717814278` |
| Region | `us-east-1` |
| EKS cluster | `jarvis` |
| App namespace | `jarvis` |
| Monitoring namespace | `monitoring` |
| Argo CD namespace | `argocd` |
| Argo Rollouts namespace | `argo-rollouts` |
| Ingress namespace | `ingress-nginx` |
| Public app URL | `http://aa180030810ff47df9c684a09112c3fc-c8482971d4afdc73.elb.us-east-1.amazonaws.com` |

Argo CD is expected to read this public GitHub repo at:

```text
https://github.com/logbrass/dev_ops.git
```

The App-of-Apps manifest is `gitops/apps/root.yaml`; child Applications use the
AWS values files in this directory.

## Runtime secrets

Before installing or syncing the AWS environment, create the runtime Kubernetes
Secrets out-of-band:

```bash
aws eks --region us-east-1 update-kubeconfig --name jarvis
./scripts/create-aws-secrets.sh
```

The script creates:

| Namespace | Secret | Keys |
| --- | --- | --- |
| `monitoring` | `jarvis-postgres-secret` | `password`, `postgres-password`, `replication-password` |
| `jarvis` | `jarvis-auth-secret` | `DATABASE_URL`, `JWT_SECRET_KEY` |
| `jarvis` | `jarvis-notes-secret` | `DATABASE_URL` |

You can provide deterministic values without committing them:

```bash
POSTGRES_PASSWORD='...' JWT_SECRET_KEY='...' ./scripts/create-aws-secrets.sh
```

Do not commit real secret values.

## GitOps bootstrap/checks

Verify cluster and Argo CD state:

```bash
aws eks --region us-east-1 update-kubeconfig --name jarvis
kubectl get nodes
kubectl -n argocd get applications
kubectl -n jarvis get rollout,pods,svc,ingress
kubectl -n monitoring get pods
```

If child Applications are missing, bootstrap the root Application:

```bash
kubectl apply -f gitops/apps/root.yaml
kubectl -n argocd get applications
```

A healthy demo setup shows these Applications as `Synced` and `Healthy`:

```text
jarvis-root
jarvis-platform
jarvis-auth
jarvis-notes
jarvis-web
```

If the repo is made private again and `jarvis-root` reports `authentication
required`, configure Argo CD repository credentials out-of-band. Do not commit
GitHub tokens or SSH keys.

## jarvis-web rollout values

The AWS demo is driven by commits to:

```text
environments/aws/jarvis-web.values.yaml
```

Use these known-good targets:

| Demo state | `image.tag` | `theme.color` | `theme.name` | `failMode` |
| --- | --- | --- | --- | --- |
| Baseline/stable | `v1.0.0` | `#1f6feb` | `blue` | `false` |
| Successful canary | `v2.0.0` | `#f97316` | `orange` | `false` |
| Broken canary | `v3.0.0-broken` | `#dc2626` | `red` | `true` |

Available ECR images:

```text
733717814278.dkr.ecr.us-east-1.amazonaws.com/jarvis-web:v1.0.0
733717814278.dkr.ecr.us-east-1.amazonaws.com/jarvis-web:v2.0.0
733717814278.dkr.ecr.us-east-1.amazonaws.com/jarvis-web:v3.0.0-broken
733717814278.dkr.ecr.us-east-1.amazonaws.com/jarvis-auth:initial
733717814278.dkr.ecr.us-east-1.amazonaws.com/jarvis-notes:initial
```

During a canary, refreshing the public URL should show a mix of stable and
canary colors. That is expected: Argo Rollouts sends 20%, then 50%, then 80%,
and finally 100% of traffic to the new version if analysis passes.

See `DEMO_RUNBOOK.md` for the full step-by-step AWS demo script.
