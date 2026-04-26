# Terraform — AWS production target

Provisioning for an EKS-based deploy of Jarvis. Mirrors what `bootstrap.sh`
gives you locally on Minikube, but on real AWS infra:

| Resource | Module | Purpose |
| --- | --- | --- |
| VPC + 3-AZ subnets | `terraform-aws-modules/vpc` | network for everything below |
| EKS control plane + managed node group | `terraform-aws-modules/eks` | runs Argo CD, Argo Rollouts, Prometheus, Grafana, jarvis-* |
| ECR repository per service | `aws_ecr_repository` | CI pushes images here |

The whole module is read by `terraform validate` and `terraform plan` in CI
and by hand. It is not applied by default — for a class demo we only need to
demonstrate the IaC piece, and applying creates real AWS spend.

## Use it

```bash
# Configure AWS creds first (env vars or `aws configure`)
cd infra/terraform
terraform init
terraform plan -out plan.tfplan
terraform apply plan.tfplan          # only do this if you actually want to spend money
aws eks update-kubeconfig --name jarvis --region us-east-1
```

After `terraform apply`, point Argo CD at the new cluster, push images to the
output ECR URLs, and the rest of the GitOps flow works the same as on
Minikube.
