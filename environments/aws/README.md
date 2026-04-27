# AWS demo environment

These values are safe to commit. They intentionally do **not** contain database
passwords, JWT signing keys, or full `DATABASE_URL` values.

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

Then deploy with Helm or let Argo CD sync the charts.
