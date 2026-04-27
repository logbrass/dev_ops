# Jarvis AWS Canary Rollout Demo Runbook

This runbook demonstrates values-driven GitOps canary rollouts for `jarvis-web` on the AWS EKS cluster.

## Cluster/demo facts

- Cluster: `jarvis` in `us-east-1`
- App namespace: `jarvis`
- Monitoring namespace: `monitoring`
- Public URL: `http://aa180030810ff47df9c684a09112c3fc-c8482971d4afdc73.elb.us-east-1.amazonaws.com`
- GitOps repo URL in Argo CD: `https://github.com/logbrass/dev_ops.git`
- Values file to change: `environments/aws/jarvis-web.values.yaml`
- Runtime secrets are created out-of-band with `./scripts/create-aws-secrets.sh`; do not commit secrets.

## One-time checks

```bash
aws eks --region us-east-1 update-kubeconfig --name jarvis
kubectl get nodes
kubectl -n argocd get applications
kubectl -n jarvis get rollout,pods,svc,ingress
kubectl -n monitoring get pods
kubectl -n monitoring get secret jarvis-postgres-secret
kubectl -n jarvis get secret jarvis-auth-secret jarvis-notes-secret
```

If Argo CD Applications are missing, bootstrap the app-of-apps:

```bash
kubectl apply -f gitops/apps/root.yaml
kubectl -n argocd get applications
kubectl -n argocd get application jarvis-web
kubectl -n jarvis get rollout jarvis-web-jarvis-web
```

The repo is currently public so Argo CD can read it without credentials. If the repo is made private again and `jarvis-root` shows `authentication required`, configure Argo CD repo credentials out-of-band. Do not put tokens in this repository. After credentials are configured, refresh/sync `jarvis-root` or wait for Argo CD reconciliation.

## Baseline state: v1 blue

`environments/aws/jarvis-web.values.yaml` should contain:

```yaml
image:
  repository: 733717814278.dkr.ecr.us-east-1.amazonaws.com/jarvis-web
  tag: v1.0.0

theme:
  color: "#1f6feb"
  name: blue

failMode: false
```

Commit and push this baseline if needed:

```bash
git checkout -b demo/reset-to-blue || git checkout demo/reset-to-blue
# edit environments/aws/jarvis-web.values.yaml to the baseline above
git add environments/aws/jarvis-web.values.yaml
git commit -m "Reset jarvis-web AWS demo to blue v1"
git push origin HEAD
```

Watch until the rollout is healthy:

```bash
kubectl -n jarvis get rollout jarvis-web-jarvis-web -w
# or, if installed:
kubectl argo rollouts get rollout jarvis-web-jarvis-web -n jarvis --watch
```

## Generate demo traffic

Keep this running in a separate terminal during canary rollouts, especially the broken rollout:

```bash
LB=aa180030810ff47df9c684a09112c3fc-c8482971d4afdc73.elb.us-east-1.amazonaws.com
while true; do
  curl -s "http://$LB/" > /dev/null
  sleep 0.5
done
```

Validate Prometheus has app traffic and that the success-rate query returns a value:

```bash
kubectl -n monitoring exec prometheus-kube-prometheus-stack-prometheus-0 -c prometheus -- \
  wget -qO- 'http://localhost:9090/api/v1/query?query=http_requests_total'

kubectl -n monitoring exec prometheus-kube-prometheus-stack-prometheus-0 -c prometheus -- \
  wget -qO- 'http://localhost:9090/api/v1/query?query=sum(rate(http_requests_total%7Bjob%3D~%22jarvis-web-jarvis-web-(stable%7Ccanary)%22%2Chandler%3D%22%2F%22%2Cstatus!~%225..%22%7D%5B1m%5D))%20%2F%20sum(rate(http_requests_total%7Bjob%3D~%22jarvis-web-jarvis-web-(stable%7Ccanary)%22%2Chandler%3D%22%2F%22%7D%5B1m%5D))'
```

## Successful canary: v2 orange

Edit `environments/aws/jarvis-web.values.yaml`:

```yaml
image:
  tag: v2.0.0

theme:
  color: "#f97316"
  name: orange

failMode: false
```

Commit and push:

```bash
git add environments/aws/jarvis-web.values.yaml
git commit -m "Promote jarvis-web AWS demo to orange v2"
git push origin HEAD
```

Expected behavior:

1. Argo CD syncs the changed Helm values.
2. Argo Rollouts canaries `20% -> analysis -> 50% -> analysis -> 80% -> promotion`.
3. During the rollout, repeated refreshes show a mix of blue v1 and orange v2 according to the current canary weight. After promotion, the public app becomes orange and reports `v2.0.0`.

Watch:

```bash
kubectl -n argocd get application jarvis-web
kubectl -n jarvis get rollout jarvis-web-jarvis-web -w
kubectl -n jarvis get analysisrun
```

## Broken canary: v3 red

Keep the traffic loop running, then edit `environments/aws/jarvis-web.values.yaml`:

```yaml
image:
  tag: v3.0.0-broken

theme:
  color: "#dc2626"
  name: red

failMode: true
```

Commit and push:

```bash
git add environments/aws/jarvis-web.values.yaml
git commit -m "Demo broken jarvis-web red v3 canary"
git push origin HEAD
```

Expected behavior:

1. Argo CD syncs the changed values.
2. Argo Rollouts sends a small percentage of traffic to the red canary.
3. The canary returns HTTP 500 for `/`.
4. Prometheus analysis fails below the success-rate threshold.
5. Argo Rollouts aborts the rollout and keeps traffic on the previous stable ReplicaSet.

Inspect failures:

```bash
kubectl -n jarvis get rollout jarvis-web-jarvis-web -w
kubectl -n jarvis get analysisrun
kubectl -n jarvis describe analysisrun <analysisrun-name>
kubectl -n jarvis describe rollout jarvis-web-jarvis-web
```

## Cleanup/reset after the broken demo

Argo Rollouts aborts bad traffic, but it does **not** revert Git. Push a corrective commit back to the desired stable version.

Reset to v2 orange:

```yaml
image:
  tag: v2.0.0

theme:
  color: "#f97316"
  name: orange

failMode: false
```

Or reset to v1 blue:

```yaml
image:
  tag: v1.0.0

theme:
  color: "#1f6feb"
  name: blue

failMode: false
```

Then commit and push:

```bash
git add environments/aws/jarvis-web.values.yaml
git commit -m "Reset jarvis-web AWS demo after broken canary"
git push origin HEAD
```
