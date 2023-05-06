# Variables
variable "project_info" {
  type = map(string)
  default = {
    env          = "__CLUSTER_NAME__"
    project_name = "kyso"
    provisioning = "Terraform"
  }
}

variable "aws_config" {
  type = map(string)
  default = {
    cluster_name = "__CLUSTER_NAME__"
    cluster_version = "__CLUSTER_EKS_VERSION__"
    region = "__CLUSTER_REGION__"
  }
}

variable "aws_auth_accounts" {
  type = list(string)
  default = [
    "__AWS_ACCOUNT_ID__"
  ]
}

variable "aws_auth_users" {
  type = list(object({
    userarn  = string
    username = string
    groups   = list(string)
  }))
  default = [
# BEG: AWS_AUTH_USERS
    {
      userarn  = "__AWS_USER_ARN__"
      username = "__AWS_USER_NAME__"
      groups   = ["system:masters"]
    },
# END: AWS_AUTH_USERS
  ]
}

variable "kms_key_administrators" {
  type = list(string)
  default = [
# BEG: KMS_KEY_ADMINISTRATORS
    "__AWS_USER_ARN__",
# END: KMS_KEY_ADMINISTRATORS
  ]
}

variable "eks_mng_defaults" {
  type = object({
    min_size       = string
    max_size       = string
    disk_size      = string
    instance_types = list(string)
  })
  default = {
    min_size       = "__CLUSTER_MIN_WORKERS__"
    max_size       = "__CLUSTER_MAX_WORKERS__"
    disk_size      = "__CLUSTER_EKS_VOLUME_SIZE__"
    instance_types = [
# BEG: EKS_INSTANCE_TYPES
      "__EKS_INSTANCE_TYPE__",
# END: EKS_INSTANCE_TYPES
    ]
  }
}

variable "eks_mng_list" {
  type = list(map(string))
  default = [
    { name: "__AZ1_NAME__", size: "__AZ1_WORKERS__" },
    { name: "__AZ2_NAME__", size: "__AZ2_WORKERS__" },
    { name: "__AZ3_NAME__", size: "__AZ3_WORKERS__" },
  ]
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
    name               = "__CLUSTER_NAME__"
    azs                = [
      "__AZ1_NAME__",
      "__AZ2_NAME__",
      "__AZ3_NAME__",
    ]
    cidr               = "__CLUSTER_CDIR_PREFIX__.0.0/16"
    single_nat_gateway = __SINGLE_NAT_GATEWAY__
  }
}
