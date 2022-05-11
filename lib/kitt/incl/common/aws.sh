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

# Functions from https://github.com/vmware-tanzu/velero-plugin-for-aws#setup

# Initial versions, will generalise later

# EKS/EFS

aws_add_eks_efs_policy() {
  _tmpl="$1"
  _policy="$DEFAULT_EKS_EFS_POLICY_NAME"
  if [ -f "$_tmpl" ]; then
    old_dir="$(pwd)"
    tmp_dir="$(mktemp -d)"
    cp "$_tmpl" "$tmp_dir/iam-policy-example.json"
    cd "$tmp_dir"
    aws iam create-policy \
      --policy-name "$_policy" \
      --policy-document "file://iam-policy-example.json" || true
    cd "$old_dir"
    rm -rf "$tmp_dir"
  else
    echo "Missing velero-policy.json template '$_tmpl'"
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

# VELERO

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
