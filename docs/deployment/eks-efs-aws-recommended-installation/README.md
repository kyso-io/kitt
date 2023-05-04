# Installation instructions

These instructions describe how to install Kyso and the required infrastructure at AWS, using EKS and EFS. This is the **production recommended installation**.

The following diagrams summarizes the global system architecture

![Systems diagram](./images/diagram.png)
<div><small><i>Figure 1. Global system architecture</i></small></div>

<hr/>

![Detailed systems diagram](./images/diagram-2.png)
<div><small><i>Figure 2. Pods interconnection and relationships</i></small></div>

<hr/>

These instructions were tested on Ubuntu and Debian operating systems. Minor adjustments would be needed if the operating system is different.

# Installation of required tools

See [Installation of required tools](../src/required-tools.md)

# Infrastructure provisioning with Terraform

Kyso provides **kitt**, a CLI tool that eases the generation (and execution) of the terraform scripts which provisions the infrastructure in AWS. If you prefer to generate and execute by yourself the terraform scripts, please move to [Appendix 1. Terraform scripts examples](#appendix-1-terraform-scripts-examples) section, use it as a template and add manually your information (users, regions, etc.).

> 💡 We recommend you to use **kitt** ;)

If you are using **kitt**, continue reading and follow the next steps.

1. Login into aws CLI with an account with enough permissions (administrator)

> 💡 terraform and kitt uses aws cli under the hood

2. Run the following kitt command to configure the variables related to the EKS cluster, and adjust them depending on your needs.

```shell
./kitt.sh clust config update
...
-------------------------------------
Update configuration? (Yes/No) [No]: Yes
Configuring cluster 'default'
-------------------------------------
When reading values an empty string or spaces keep the default value.
To adjust the value to an empty string use a single - or edit the file.
-------------------------------------
Cluster kind? (eks|ext|k3d) []: eks
Cluster Kubectl Context []: terraform-test
Cluster DNS Domain []: terraform-test.kyso.io
Keep cluster data in git (Yes/No) []: Yes 
Force SSL redirect on ingress (Yes/No) []: Yes
Cluster Ingress Replicas []: 1
Add pull secrets to namespaces (Yes/No) []: Yes
Use basic auth (Yes/No) []: Yes
Use SOPS (Yes/No) []: No
Cluster admins (comma separated list of AWS usernames) []: sto,fjbarrena
EKS Version []: 1.25
Cluster Region []: eu-north-1
Cluster EKS Instance Types []: m5a.large,m6a.large,m5.large,m6i.large
Cluster EKS Volume Size []: 80
Cluster Min Workers []: 0
Cluster Max Workers []: 3
Cluster Workers in AZ1 []: 1
Cluster Workers in AZ2 []: 0
Cluster Workers in AZ3 []: 0
Cluster CDIR Prefix []: 10.23
Cluster EFS fileSystemId []: 
Save updated configuration? (Yes/No) [Yes]: Yes
-------------------------------------
Configuration saved to '/home/admin/kitt-data/clusters/default/config'
-------------------------------------
Remote registry configuration not found, configuring it now!
Configuring remote registry
-------------------------------------
Registry NAME []: registry.kyso.io
Registry URL []: registry.kyso.io
Registry USER []: <PUT_HERE_CREDENTIALS_PROVIDED>
Registry PASS []: <PUT_HERE_CREDENTIALS_PROVIDED>
-------------------------------------
Configuration saved to '/home/admin/kitt-data/clusters/default/secrets/registry.sops.env'
-------------------------------------
```
> 💡 These values are used to generate terraform scripts

3. Then, execute the following command to create the EKS cluster

```shell
./kitt.sh clust eks install
```
> 💡 This process needs several minutes, depending on the number of workers, instance types, etc. 

> ℹ️ Terraform stores the state of the deployment in S3 and DynamoDB as explained in the [official documentation](https://developer.hashicorp.com/terraform/language/settings/backends/s3)

4. Once finished, your local kubernetes context will be changed to the new EKS cluster

> 💡 If that don't happens, run the command `./kitt.sh clust eks kubeconfig` to switch to the new EKS cluster context

5. Check that effectively the kubectl context changed to your new EKS cluster running the following command:

```shell
kubectl get nodes
```

6. Then, create the **efs** filesystem

```shell
./kitt.sh addons efs createfs
...
The new filesystem id is 'fs-99999999999999'
Save updated configuration? (Yes/No) [Yes]: yes
```

> 💡 **IMPORTANT**. Execute the command until it don't fail. Sometimes the operation takes too much time, exceeding the timers and provoking a failure. As the **command is idempotent**, you can securely execute it as may times as you need until it finishes successfully


6. Now, install all the addons required into the cluster, executing:

```shell
./kitt.sh addons eks-all install
```

> 💡 The minimal addons required for kyso are: **ingress**, **ebs** and **efs**



# Install kyso

See [Install Kyso](../src/kyso.md)

# Appendix 1. Terraform scripts examples

Files available [here](./terraform/)

## variables.tf

```terraform
# Variables
variable "project_info" {
  type = map(string)
  default = {
    env          = "tftest"
    project_name = "kyso"
    provisioning = "Terraform"
  }
}

variable "aws_config" {
  type = map(string)
  default = {
    cluster_name = "tftest"
    cluster_version = "1.25"
    region = "eu-west-1"
  }
}

variable "aws_auth_accounts" {
  type = list(string)
  default = [
    "999999999999"
  ]
}

variable "aws_auth_users" {
  type = list(object({
    userarn  = string
    username = string
    groups   = list(string)
  }))
  default = [
    {
      userarn  = "arn:aws:iam::999999999999:user/user1"
      username = "sto"
      groups   = ["system:masters"]
    },
    {
      userarn  = "arn:aws:iam::999999999999:user/user2"
      username = "fjbarrena"
      groups   = ["system:masters"]
    },
  ]
}

variable "kms_key_administrators" {
  type = list(string)
  default = [
    "arn:aws:iam::999999999999:user/user1",
    "arn:aws:iam::999999999999:user/user2",
  ]
}

variable "eks_mng" {
  type = object({
    az1_size       = string
    az2_size       = string
    az3_size       = string
    min_size       = string
    max_size       = string
    disk_size      = string
    instance_types = list(string)
  })
  default = {
    az1_size       = "1"
    # If az2_size and az3_size is 0 means not going to use
    # availability zones
    az2_size       = "0"
    az3_size       = "0"
    min_size       = "0"
    max_size       = "3"
    # for EBS (mongodb, elasticsearch)
    disk_size      = "80"
    instance_types = [
      "m5a.large",
      "m6a.large",
      "m5.large",
      "m6i.large",
    ]
  }
}

# We asume that are always using three availability zones on the CLUSTER_REGION
# and the same subnets for now, will change in the future if needed
variable "vpc" {
  type = object({
    name               = string
    azs                = list(string)
    cidr               = string
    single_nat_gateway = bool
  })
  default = {
    name               = "tftest"
    azs                = [
      "eu-west-1a",
      "eu-west-1b",
      "eu-west-1c",
    ]
    cidr               = "10.23.0.0/16"
    # true if only going to use a single availability zone.
    # false if going to use more than a single az
    single_nat_gateway = true
  }
}
```

## config.tf


```terraform
terraform {
  backend "s3" {
    bucket = "kyso-tftest-terraform-858604803370"
    key    = "tftest/eks.tfstate"
    region = "eu-west-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.62.0"
    }

    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "2.19.0"
    }
  }
}

provider "aws" {
  region = var.aws_config["region"]
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed where Terraform is executed
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}
```

## eks.tf

```terraform
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
    aws-ebs-csi-driver = {
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
```
## network.tf

```terraform
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
```

## outputs.tf

```terraform
output "private_subnets" {
  value       = module.vpc.private_subnets
  description = "Private subnet ids"
}
```


## eks_oidc_roles.tf

```terraform
# OIDC ROLES FOR SA
# ref: https://github.com/terraform-aws-modules/terraform-aws-iam/blob/v5.1.0/examples/iam-role-for-service-accounts-eks/main.tf

##
# EBS CSI DRIVER
##
module "ebs_csi_driver" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name = "${var.aws_config["cluster_name"]}-ebs-csi-driver"

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa", "kube-system:ebs-csi-node-sa"]
    }
  }

  role_policy_arns = {
    ebs_csi_driver_policy = aws_iam_policy.ebs_csi_driver_policy.arn
  }

  tags = var.project_info
}

resource "aws_iam_policy" "ebs_csi_driver_policy" {
  name        = "${var.aws_config["cluster_name"]}-ebs-csi-driver-policy"
  description = "Policy for the EBS CSI driver"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateSnapshot",
        "ec2:AttachVolume",
        "ec2:DetachVolume",
        "ec2:ModifyVolume",
        "ec2:DescribeAvailabilityZones",
        "ec2:DescribeInstances",
        "ec2:DescribeSnapshots",
        "ec2:DescribeTags",
        "ec2:DescribeVolumes",
        "ec2:DescribeVolumesModifications"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateTags"
      ],
      "Resource": [
        "arn:aws:ec2:*:*:volume/*",
        "arn:aws:ec2:*:*:snapshot/*"
      ],
      "Condition": {
        "StringEquals": {
          "ec2:CreateAction": [
            "CreateVolume",
            "CreateSnapshot"
          ]
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DeleteTags"
      ],
      "Resource": [
        "arn:aws:ec2:*:*:volume/*",
        "arn:aws:ec2:*:*:snapshot/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateVolume"
      ],
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "aws:RequestTag/ebs.csi.aws.com/cluster": "true"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateVolume"
      ],
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "aws:RequestTag/CSIVolumeName": "*"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DeleteVolume"
      ],
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "ec2:ResourceTag/ebs.csi.aws.com/cluster": "true"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DeleteVolume"
      ],
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "ec2:ResourceTag/CSIVolumeName": "*"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DeleteVolume"
      ],
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "ec2:ResourceTag/kubernetes.io/created-for/pvc/name": "*"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DeleteSnapshot"
      ],
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "ec2:ResourceTag/CSIVolumeSnapshotName": "*"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DeleteSnapshot"
      ],
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "ec2:ResourceTag/ebs.csi.aws.com/cluster": "true"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
          "kms:Decrypt",
          "kms:GenerateDataKeyWithoutPlaintext",
          "kms:CreateGrant"
      ],
      "Resource": "*"
    }
  ]
}
EOF

  tags = var.project_info
}

##
# EFS CSI DRIVER
##
module "efs_csi_driver" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name = "${var.aws_config["cluster_name"]}-efs-csi-driver"

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:efs-csi-controller-sa", "kube-system:efs-csi-node-sa"]
    }
  }

  role_policy_arns = {
    efs_csi_driver_policy = aws_iam_policy.efs_csi_driver_policy.arn
  }

  tags = var.project_info
}

resource "aws_iam_policy" "efs_csi_driver_policy" {
  name        = "${var.aws_config["cluster_name"]}-efs-csi-driver-policy"
  description = "Policy for the EFS CSI driver"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "elasticfilesystem:DescribeAccessPoints",
        "elasticfilesystem:DescribeFileSystems",
        "elasticfilesystem:DescribeMountTargets",
        "ec2:DescribeAvailabilityZones"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "elasticfilesystem:CreateAccessPoint"
      ],
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "aws:RequestTag/efs.csi.aws.com/cluster": "true"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "elasticfilesystem:TagResource"
      ],
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "aws:ResourceTag/efs.csi.aws.com/cluster": "true"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": "elasticfilesystem:DeleteAccessPoint",
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:ResourceTag/efs.csi.aws.com/cluster": "true"
        }
      }
    }
  ]
}
EOF

  tags = var.project_info
}

###
# CERT-MANAGER AND EXTERNAL-DNS
###
module "route53_access" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name = "${var.aws_config["cluster_name"]}-route53-access"

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["cert-manager:cert-manager", "kube-system:external-dns"]
    }
  }

  role_policy_arns = {
    route53_policy = aws_iam_policy.route53_policy.arn
  }

  tags = var.project_info
}

resource "aws_iam_policy" "route53_policy" {
  name        = "${var.aws_config["cluster_name"]}-route53-policy"
  description = "Policy for the Route53 process"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "route53:GetChange",
      "Resource": "arn:aws:route53:::change/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "route53:ChangeResourceRecordSets"
      ],
      "Resource": "arn:aws:route53:::hostedzone/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "route53:ListHostedZonesByName",
        "route53:ListHostedZones",
        "route53:ListResourceRecordSets"
      ],
      "Resource": "*"
    }
  ]
}
EOF

  tags = var.project_info
}

##
# CLUSTER AUTOSCALER
##
module "cluster_autoscaler" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name = "${var.aws_config["cluster_name"]}-cluster-autoscaler"

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:cluster-autoscaler-aws-cluster-autoscaler"]
    }
  }

  role_policy_arns = {
    cluster_autoscaler_policy = aws_iam_policy.cluster_autoscaler_policy.arn
  }

  tags = var.project_info
}

resource "aws_iam_policy" "cluster_autoscaler_policy" {
  name        = "${var.aws_config["cluster_name"]}-cluster-autoscaler-policy"
  description = "Policy for the Cluster Autoscaler process"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:DescribeAutoScalingInstances",
        "autoscaling:DescribeLaunchConfigurations",
        "autoscaling:DescribeScalingActivities",
        "autoscaling:DescribeTags",
        "ec2:DescribeInstanceTypes",
        "ec2:DescribeLaunchTemplateVersions"
      ],
      "Resource": ["*"]
    },
    {
      "Effect": "Allow",
      "Action": [
        "autoscaling:SetDesiredCapacity",
        "autoscaling:TerminateInstanceInAutoScalingGroup",
        "ec2:DescribeImages",
        "ec2:GetInstanceTypesFromInstanceRequirements",
        "eks:DescribeNodegroup"
      ],
      "Resource": ["*"]
    }
  ]
}
EOF

  tags = var.project_info
}
``` 