terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Project     = var.project_name
      Owner       = var.owner
    }
  }
}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

# provider "helm" {
#   kubernetes {
#     host                   = data.aws_eks_cluster.cluster.endpoint
#     cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
#     token                  = data.aws_eks_cluster_auth.cluster.token
#   }
# }

locals {
  cluster_name = "${var.environment}-${var.project_name}-eks"

  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
    ManagedBy   = "Terraform"
  }
}

module "vpc" {
  source = "../../modules/vpc"

  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  cluster_name       = local.cluster_name
  az_count           = var.az_count
  enable_nat_gateway = var.enable_nat_gateway
  enable_flow_logs   = var.enable_flow_logs

  tags = local.common_tags
}

module "eks" {
  source = "../../modules/eks"

  cluster_name              = local.cluster_name
  cluster_version           = var.cluster_version
  vpc_id                    = module.vpc.vpc_id
  private_subnet_ids        = module.vpc.private_subnet_ids
  public_subnet_ids         = module.vpc.public_subnet_ids
  endpoint_private_access   = var.endpoint_private_access
  endpoint_public_access    = var.endpoint_public_access
  public_access_cidrs       = var.public_access_cidrs
  enabled_cluster_log_types = var.enabled_cluster_log_types

  tags = local.common_tags

  depends_on = [module.vpc]
}

module "node_group_on_demand" {
  source = "../../modules/node-groups"

  cluster_name              = module.eks.cluster_id
  node_group_name           = "${local.cluster_name}-on-demand"
  subnet_ids                = module.vpc.private_subnet_ids
  kubernetes_version        = var.cluster_version
  desired_size              = var.on_demand_desired_size
  min_size                  = var.on_demand_min_size
  max_size                  = var.on_demand_max_size
  instance_types            = var.on_demand_instance_types
  capacity_type             = "ON_DEMAND"
  disk_size                 = var.disk_size
  vpc_id                    = module.vpc.vpc_id
  cluster_security_group_id = module.eks.cluster_security_group_id

  labels = {
    role          = "general"
    environment   = var.environment
    capacity-type = "on-demand"
  }

  tags = local.common_tags

  depends_on = [module.eks]
}

module "node_group_spot" {
  source = "../../modules/node-groups"

  cluster_name              = module.eks.cluster_id
  node_group_name           = "${local.cluster_name}-spot"
  subnet_ids                = module.vpc.private_subnet_ids
  kubernetes_version        = var.cluster_version
  desired_size              = var.spot_desired_size
  min_size                  = var.spot_min_size
  max_size                  = var.spot_max_size
  instance_types            = var.spot_instance_types
  capacity_type             = "SPOT"
  disk_size                 = var.disk_size
  vpc_id                    = module.vpc.vpc_id
  cluster_security_group_id = module.eks.cluster_security_group_id

  labels = {
    role          = "worker"
    environment   = var.environment
    capacity-type = "spot"
  }

  taints = [
    {
      key    = "spot"
      value  = "true"
      effect = "NO_SCHEDULE"
    }
  ]

  tags = local.common_tags

  depends_on = [module.eks]
}

# resource "helm_release" "metrics_server" {
#   name       = "metrics-server"
#   repository = "https://kubernetes-sigs.github.io/metrics-server/"
#   chart      = "metrics-server"
#   namespace  = "kube-system"
#   version    = "3.11.0"

#   set {
#     name  = "args[0]"
#     value = "--kubelet-insecure-tls"
#   }

#   depends_on = [module.eks]
# }

# resource "helm_release" "cluster_autoscaler" {
#   name       = "cluster-autoscaler"
#   repository = "https://kubernetes.github.io/autoscaler"
#   chart      = "cluster-autoscaler"
#   namespace  = "kube-system"
#   version    = "9.29.3"

#   set {
#     name  = "autoDiscovery.clusterName"
#     value = module.eks.cluster_id
#   }

#   set {
#     name  = "awsRegion"
#     value = var.aws_region
#   }

#   set {
#     name  = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
#     value = module.eks.cluster_autoscaler_role_arn
#   }

#   set {
#     name  = "extraArgs.balance-similar-node-groups"
#     value = "true"
#   }

#   set {
#     name  = "extraArgs.skip-nodes-with-system-pods"
#     value = "false"
#   }

#   depends_on = [module.node_group_on_demand]
# }

# resource "helm_release" "aws_load_balancer_controller" {
#   name       = "aws-load-balancer-controller"
#   repository = "https://aws.github.io/eks-charts"
#   chart      = "aws-load-balancer-controller"
#   namespace  = "kube-system"
#   version    = "1.6.2"

#   set {
#     name  = "clusterName"
#     value = module.eks.cluster_id
#   }

#   set {
#     name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
#     value = module.eks.aws_load_balancer_controller_role_arn
#   }

#   set {
#     name  = "region"
#     value = var.aws_region
#   }

#   set {
#     name  = "vpcId"
#     value = module.vpc.vpc_id
#   }

#   depends_on = [module.node_group_on_demand]
# }

