output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "kubeconfig_command" {
  description = "Run this to wire kubectl up to the new cluster"
  value       = "aws eks --region ${var.region} update-kubeconfig --name ${module.eks.cluster_name}"
}

output "ecr_repositories" {
  description = "Per-service ECR URLs that CI should push to"
  value       = { for k, v in aws_ecr_repository.service : k => v.repository_url }
}
