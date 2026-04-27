# Top-level Terraform layout for the production AWS deploy of Jarvis.
#
# Components:
#   - VPC with public + private subnets across 3 AZs (terraform-aws-modules/vpc)
#   - EKS cluster with a managed node group   (terraform-aws-modules/eks)
#   - One ECR repository per service so CI can push images
#
# This is intentionally not applied by default; running `terraform plan`
# against a configured backend is enough to demonstrate the IaC piece for the
# class. To actually deploy:
#   cd infra/terraform
#   terraform init
#   terraform plan -out plan.tfplan
#   terraform apply plan.tfplan

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.13"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr
  azs  = var.azs

  # /20 each: ~4k IPs in private (for pods/nodes), ~4k in public (for LBs)
  private_subnets = [for i, _ in var.azs : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets  = [for i, _ in var.azs : cidrsubnet(var.vpc_cidr, 4, i + 8)]

  enable_nat_gateway   = true
  single_nat_gateway   = true # cheap; flip to false for prod-grade HA
  enable_dns_hostnames = true

  # Required tags so EKS can discover subnets for ELB autoprovisioning.
  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.24"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access           = true  # tighten this in prod
  enable_cluster_creator_admin_permissions = false # restricted IAM user cannot call EKS access-entry APIs; bootstrap admin is patched in for this throwaway demo

  # Keep this throwaway demo compatible with the restricted class AWS IAM user.
  # The account does not permit KMS key creation/tagging, custom IAM policy
  # creation, or CloudWatch log-group tag inspection.
  cluster_enabled_log_types    = []
  cluster_encryption_config    = {}
  create_kms_key               = false
  create_cloudwatch_log_group  = false
  enable_auto_mode_custom_tags = false
  enable_irsa                  = false

  # The class AWS user cannot call eks:DescribeAddonVersions/CreateAddon.
  # EKS still bootstraps the core self-managed add-ons at cluster creation;
  # Postgres persistence is disabled in AWS values so the EBS CSI add-on is not required.
  cluster_addons = {}

  eks_managed_node_groups = {
    default = {
      ami_type       = "AL2_x86_64"
      instance_types = [var.node_instance_type]
      min_size       = 1
      desired_size   = var.node_desired_size
      max_size       = 4
    }
  }
}

# One ECR repository per microservice. CI pushes here on `main`.
locals {
  services = ["jarvis-web", "jarvis-auth", "jarvis-notes"]
}

resource "aws_ecr_repository" "service" {
  for_each = toset(local.services)
  name     = each.value

  image_scanning_configuration {
    scan_on_push = true
  }

  # Force https:// + KMS-managed encryption (defaults are fine for a class demo).
  image_tag_mutability = "IMMUTABLE"
}

resource "aws_ecr_lifecycle_policy" "service" {
  for_each   = aws_ecr_repository.service
  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 30 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 30
      }
      action = { type = "expire" }
    }]
  })
}
