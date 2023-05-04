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
    az2_size       = "0"
    az3_size       = "0"
    min_size       = "0"
    max_size       = "3"
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
    single_nat_gateway = true
  }
}
