module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = var.aws_config["cluster_name"]
  cluster_version = var.aws_config["cluster_version"]
  enable_irsa     = true

  cluster_endpoint_private_access = true
  # Disable public access if using a VPN
  cluster_endpoint_public_access  = true

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
  }

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.intra_subnets

  # EKS Managed Node Group(s)

  # Defaults
  eks_managed_node_group_defaults = {
    min_size       = var.eks_mng["min_size"]
    max_size       = var.eks_mng["max_size"]
    instance_types = var.eks_mng["instance_types"]
    disk_size      = var.eks_mng["disk_size"]
    capacity_type  = "ON_DEMAND"
  }

  eks_managed_node_groups = {
    az1_node_group = {
      desired_size = var.eks_mng["az1_size"]
      subnet_ids = [module.vpc.private_subnets[0]]
    }
    az2_node_group = {
      desired_size = var.eks_mng["az2_size"]
      subnet_ids = [module.vpc.private_subnets[1]]
    }
    az3_node_group = {
      desired_size = var.eks_mng["az3_size"]
      subnet_ids = [module.vpc.private_subnets[2]]
    }
  }

  # extend node-to-node security group rules
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }

    ingress_cluster_all = {
      description                   = "Cluster to node all ports/protocols"
      protocol                      = "-1"
      from_port                     = 0
      to_port                       = 0
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }

  cluster_security_group_additional_rules = {
    ingress_apiserver_private = {
      description = "VPC CIDR to EKS API Server"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      type        = "ingress"
      cidr_blocks = [var.vpc["cidr"]]
    }
  }

  # aws-auth configmap
  manage_aws_auth_configmap = true

  aws_auth_accounts = var.aws_auth_accounts
  aws_auth_users = var.aws_auth_users
  kms_key_administrators = var.kms_key_administrators

  tags = {
    Environment = var.project_info["env"]
    Provisioner = var.project_info["provisioning"]
  }
}
