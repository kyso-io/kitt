terraform {
  backend "s3" {
    bucket = "__TF_STATE_BUCKET_NAME__"
    key    = "__CLUSTER_NAME__/terraform.tfstate"
    region = "__CLUSTER_REGION__"
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
