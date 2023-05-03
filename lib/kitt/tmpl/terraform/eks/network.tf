module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  name = var.vpc["name"]
  cidr = var.vpc["cidr"]

  azs             = var.vpc["azs"]
  private_subnets = [
    for k, v in var.vpc["azs"]: cidrsubnet(var.vpc["cidr"], 4, k)
  ]
  public_subnets  = [
    for k, v in var.vpc["azs"]: cidrsubnet(var.vpc["cidr"], 4, k + 3)
  ]
#  intra_subnets   = [
#    for k, v in var.vpc["azs"]: cidrsubnet(var.vpc["cidr"], 4, k + 6)
#  ]

  enable_nat_gateway     = true
  enable_vpn_gateway     = false
  single_nat_gateway     = var.vpc["single_nat_gateway"]
  one_nat_gateway_per_az = true
  enable_dns_hostnames   = true

  reuse_nat_ips = false

  enable_ipv6            = false
  create_egress_only_igw = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}
