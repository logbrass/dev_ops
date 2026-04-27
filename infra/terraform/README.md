# Terraform — AWS EKS target

Provisioning for the EKS-based deploy of Jarvis. It mirrors what
`bootstrap.sh` gives you locally on Minikube, but on real AWS infrastructure.

| Resource | Module | Purpose |
| --- | --- | --- |
| VPC + 3-AZ subnets | `terraform-aws-modules/vpc` | network for everything below |
| EKS control plane + managed node group | `terraform-aws-modules/eks` | runs Argo CD, Argo Rollouts, Prometheus, Grafana, jarvis-* |
| ECR repository per service | `aws_ecr_repository` | stores the demo images |

The module is read by `terraform validate` and `terraform plan` in CI and by
hand. Applying creates real AWS spend.

## Current demo cluster

The class/demo AWS cluster already exists and should not be destroyed or
recreated for the canary demo.

| Item | Value |
| --- | --- |
| AWS account | `733717814278` |
| Region | `us-east-1` |
| EKS cluster | `jarvis` |
| Public app URL | `http://aa180030810ff47df9c684a09112c3fc-c8482971d4afdc73.elb.us-east-1.amazonaws.com` |

Current ECR demo images:

```text
733717814278.dkr.ecr.us-east-1.amazonaws.com/jarvis-web:v1.0.0
733717814278.dkr.ecr.us-east-1.amazonaws.com/jarvis-web:v2.0.0
733717814278.dkr.ecr.us-east-1.amazonaws.com/jarvis-web:v3.0.0-broken
733717814278.dkr.ecr.us-east-1.amazonaws.com/jarvis-auth:initial
733717814278.dkr.ecr.us-east-1.amazonaws.com/jarvis-notes:initial
```

For the current demoware path, Terraform changes are not required. The demo is
values-driven GitOps: commit changes to `environments/aws/jarvis-web.values.yaml`
and let Argo CD / Argo Rollouts handle sync, canary analysis, promotion, and
abort.

## Use it for a fresh AWS environment

Only run `apply` if you intentionally want to create or modify AWS resources.

```bash
# Configure AWS creds first: env vars, SSO, or `aws configure`.
cd infra/terraform
terraform init
terraform plan -out plan.tfplan
terraform apply plan.tfplan          # creates/changes real AWS resources
aws eks update-kubeconfig --name jarvis --region us-east-1
```

After `terraform apply`, install the controllers, create runtime secrets
out-of-band with `./scripts/create-aws-secrets.sh`, point Argo CD at this repo,
push images to the output ECR URLs, and use the same GitOps flow as the live
demo cluster.
