# EKS Cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = aws_vpc.main.id
  subnet_ids = concat(aws_subnet.private[*].id, aws_subnet.public[*].id)

  # Cluster endpoint configuration
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  # Enable EKS addons
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  # EKS Managed Node Group - Master Node (Single Node)
  eks_managed_node_groups = {
    master = {
      name            = "${var.cluster_name}-master"
      instance_types  = [var.master_node_instance_type]
      min_size        = 1
      max_size        = 1
      desired_size    = 1
      capacity_type   = "ON_DEMAND"

      labels = {
        role = "master"
      }

      tags = merge(
        var.tags,
        {
          Name = "${var.cluster_name}-master-node"
        }
      )
    }

    # Worker Node Group
    workers = {
      name            = "${var.cluster_name}-workers"
      instance_types  = [var.worker_node_instance_type]
      min_size        = var.worker_node_min_size
      max_size        = var.worker_node_max_size
      desired_size    = var.worker_node_desired_size
      capacity_type   = "ON_DEMAND"

      labels = {
        role = "worker"
      }

      tags = merge(
        var.tags,
        {
          Name = "${var.cluster_name}-worker-node"
        }
      )
    }
  }

  # IRSA (IAM Roles for Service Accounts)
  enable_irsa = true

  tags = var.tags
}

# Data source for current AWS region
data "aws_region" "current" {}

# Outputs
output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "kubeconfig_command" {
  description = "Command to update kubeconfig"
  value       = "aws eks update-kubeconfig --region ${data.aws_region.current.name} --name ${module.eks.cluster_name}"
}

