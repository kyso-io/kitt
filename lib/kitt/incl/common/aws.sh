#!/bin/sh
# ----
# File:        common/aws.sh
# Description: Auxiliary functions to work with aws.
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_AWS_SH="1"

# ---------
# Variables
# ---------

# For now fixed values, will make configurable later

export DEFAULT_EKS_EFS_REGION="eu-north-1"
export DEFAULT_EKS_EFS_POLICY_NAME="AmazonEKS_EFS_CSI_Driver_Policy"
export DEFAULT_EKS_EFS_NAME="kyso-efs-filesystem"
export DEFAULT_EKS_EFS_INGRESS_RULE="kyso-efs-eks-ingress-rule"
export DEFAULT_EKS_EFS_SG_NAME="EfsSecurityGroup"
export DEFAULT_EKS_EFS_SG_DESC="EKS EFS Access Security Group"

export DEFAULT_VELERO_REGION="eu-north-1"
export DEFAULT_VELERO_BUCKET="kyso-saas-velero"
export DEFAULT_VELERO_USER="velero"
export DEFAULT_VELERO_POLICY_NAME="velero"

# --------
# Includes
# --------

if [ -d "$INCL_DIR" ]; then
  # shellcheck source=./io.sh
  [ "$INCL_COMMON_IO_SH" = "1" ] || . "$INCL_DIR/common/io.sh"
fi

# ---------
# Functions
# ---------

# Initial versions, will generalise later

# EKS/EFS

# Functions from https://docs.aws.amazon.com/eks/latest/userguide/efs-csi.html

aws_add_eks_efs_policy() {
  _tmpl="$1"
  _policy_name="$DEFAULT_EKS_EFS_POLICY_NAME"
  if [ -f "$_tmpl" ]; then
    _account_id="$(aws sts get-caller-identity --query "Account" --output text)"
    _policy_id="$(
      aws iam get-policy \
        --policy-arn "arn:aws:iam::$_account_id:policy/$_policy_name" \
        --query 'Policy.PolicyId' \
        --output text
    )"
    if [ "$_policy_id" = "None" ]; then
      old_dir="$(pwd)"
      tmp_dir="$(mktemp -d)"
      cp "$_tmpl" "$tmp_dir/iam-policy-example.json"
      cd "$tmp_dir"
      aws iam create-policy \
        --policy-name "$_policy_name" \
        --policy-document "file://iam-policy-example.json"
      cd "$old_dir"
      rm -rf "$tmp_dir"
    else
      echo "Policy '$_policy_name' already exist with id '$_policy_id'"
    fi
  else
    echo "Missing eks-efs-policy template '$_tmpl'"
    exit 1
  fi
}

aws_add_eks_efs_service_account() {
  _cluster="$1"
  _account_id="$(aws sts get-caller-identity --query "Account" --output text)"
  _policy="$DEFAULT_EKS_EFS_POLICY_NAME"
  _region="$DEFAULT_EKS_EFS_REGION"
  # Make sure we have an iam-oidc-provider available
  eksctl utils associate-iam-oidc-provider --region="$_region" \
    --cluster="$_cluster" --approve
  # Create the service account
  eksctl create iamserviceaccount \
    --cluster "$_cluster" \
    --namespace kube-system \
    --name efs-csi-controller-sa \
    --attach-policy-arn "arn:aws:iam::$_account_id:policy/$_policy" \
    --approve \
    --region "$_region"
}

aws_add_eks_efs_filesystem() {
  _cluster="$1"
  _region="$DEFAULT_EKS_EFS_REGION"
  _sg_name="$DEFAULT_EKS_EFS_SG_NAME"
  _sg_desc="$DEFAULT_EKS_EFS_SG_DESC"
  _efs_name="$DEFAULT_EKS_EFS_NAME-$_cluster"
  _efs_eks_ingress_rule="$DEFAULT_EKS_EFS_INGRESS_RULE"
  # Get values
  _vpc_id="$(
    aws eks describe-cluster \
      --name "$_cluster" \
      --query "cluster.resourcesVpcConfig.vpcId" \
      --output text
  )"
  _cidr_range="$(
    aws ec2 describe-vpcs \
      --vpc-ids "$_vpc_id" \
      --query "Vpcs[].CidrBlock" \
      --output text
  )"
  _security_group_id="$(
    aws ec2 describe-security-groups \
      --filters \
        "Name=vpc-id,Values=$_vpc_id"\
        "Name=group-name,Values=$_sg_name" \
      --query "SecurityGroups[*].[GroupId]" \
      --output text
  )"
  # Create security group if missing
  if [ -z "$_security_group_id" ]; then
    _tag_spec="ResourceType=security-group,Tags=[{Key=Name,Value=$_sg_name}]"
    _security_group_id="$(
      aws ec2 create-security-group \
        --group-name "$_sg_name" \
        --description "$_sg_desc" \
        --query "SecurityGroups[*].[GroupId]" \
        --vpc-id "$_vpc_id" \
        --tag-specifications "$_tag_spec" \
        --output text
    )"
  fi
  # Allow inbound connections from the eks cluster
  _efs_eks_ingress_rule_id="$(
    aws ec2 describe-security-group-rules \
      --filter \
        "Name=group-id,Values=$_security_group_id" \
        "Name=tag:Name,Values=$_efs_eks_ingress_rule" \
      --query 'SecurityGroupRules[].SecurityGroupRuleId' \
      --output text
  )"
  if [ -z "$_efs_eks_ingress_rule_id" ]; then
    _tag_spec="ResourceType=security-group-rule"
    _tag_spec="$_tag_spec,Tags=[{Key=Name,Value=$_efs_eks_ingress_rule}]"
    aws ec2 authorize-security-group-ingress \
      --group-id "$_security_group_id" \
      --protocol tcp \
      --port 2049 \
      --tag-specifications "$_tag_spec" \
      --cidr "$_cidr_range"
  else
    echo "Rule to allow EFS access exists with id '$_efs_eks_ingress_rule_id'"
  fi
  # Create fileystem if missing
  _file_system_id=""
  _file_system_ids="$(
    aws efs describe-file-systems \
        --region "$_region" \
        --query "FileSystems[*].[FileSystemId]" \
        --output text
  )"
  for _fid in $_file_system_ids; do
    _name="$(
      aws efs list-tags-for-resource --resource-id "$_fid" |
        jq -r '.Tags[] | select(.Key=="Name") | .Value'
    )"
    if [ "$_name" = "$_efs_name" ]; then
      _file_system_id="$_fid"
      break
    fi
  done
  if [ -z "$_file_system_id" ]; then
    _file_system_id="$(
      aws efs create-file-system \
        --region "$_region" \
        --performance-mode generalPurpose \
        --throughput-mode bursting \
        --encrypted \
        --tags "Key=Name,Value=$_efs_name" \
        --query 'FileSystemId' \
        --output text
    )"
  fi
  # Create mount targets
  _subnet_ids="$(
    aws ec2 describe-subnets \
      --filters "Name=vpc-id,Values=$_vpc_id" \
      --query 'Subnets[*].{SubnetId: SubnetId}' \
      --output text |
      sort -u
  )"
  echo "$_subnet_ids" | while read -r _subnet_id; do
    aws efs create-mount-target \
      --file-system-id "$_file_system_id" \
      --subnet-id "$_subnet_id" \
      --security-groups "$_security_group_id" || true
  done
  export CLUSTER_EFS_FILESYSTEMID="$_file_system_id"
}

# VELERO

# Functions from https://github.com/vmware-tanzu/velero-plugin-for-aws#setup

aws_create_velero_bucket() {
  _bucket="$DEFAULT_VELERO_BUCKET"
  _region="$DEFAULT_VELERO_REGION"
  aws s3api create-bucket --bucket "$_bucket" --region "$_region" \
    --create-bucket-configuration "LocationConstraint=$_region"
}

aws_create_velero_user() {
  _user="$DEFAULT_VELERO_USER"
  aws iam create-user --user-name "$_user"
}

aws_add_velero_user_policy() {
  _tmpl="$1"
  _bucket="$DEFAULT_VELERO_BUCKET"
  _user="$DEFAULT_VELERO_USER"
  _policy="$DEFAULT_VELERO_POLICY_NAME"
  if [ -f "$_tmpl" ]; then
    old_dir="$(pwd)"
    tmp_dir="$(mktemp -d)"
    sed -e "s%__BUCKET__%$_bucket%g" "$_tmpl" >"$tmp_dir/velero-policy.json"
    cd "$tmp_dir"
    aws iam put-user-policy \
      --user-name "$_user" \
      --policy-name "$_policy" \
      --policy-document "file://velero-policy.json"
    cd "$old_dir"
    rm -rf "$tmp_dir"
  else
    echo "Missing velero-policy.json template '$_tmpl'"
    exit 1
  fi
}

aws_create_velero_s3_env() {
  _outf="$1"
  _user="$DEFAULT_VELERO_USER"
  _json="$(aws iam create-access-key --user-name "$_user")"
  _aws_access_key_id="$(echo "$_json" | jq '.AccessKey.AccessKeyId')"
  _aws_secret_access_key="$(echo "$_json" | jq '.AccessKey.SecretAccessKey')"
  tmp_dir="$(mktemp -d)"
  cat >"$tmp_dir/s3.env" <<EOF
USE_MINIO=false
AWS_ACCESS_KEY_ID=$_aws_access_key_id
AWS_SECRET_ACCESS_KEY=$_aws_secret_access_key
BUCKET=$DEFAULT_VELERO_BUCKET
REGION=$DEFAULT_VELERO_REGION
S3_URL=
S3_PUBLIC_URL=
EOF
  stdout_to_file "$_outf" <"$tmp_dir/s3.env"
  rm -rf "$tmp_dir"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
