#!/bin/sh
# ----
# File:        common/aws.sh
# Description: Auxiliary functions to work with aws.
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022-2023 Kyso Inc.
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_AWS_SH="1"

# ---------
# Variables
# ---------

# For now fixed values, will make configurable later
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

# Queries to get account data
aws_get_account_id() {
  aws sts get-caller-identity --query 'Account' --output text
}

# Queries to get role data
aws_get_role_arn() {
  if [ "$1" ]; then
    aws iam get-role --query 'Role.Arn' --output text --role "$1"
  fi
}

# Queries to get user data
aws_get_user_arn() {
  if [ "$1" ]; then
    aws iam get-user --query 'User.Arn' --output text --user "$1"
  else
    aws iam get-user --query 'User.Arn' --output text
  fi
}

aws_get_user_name() {
  if [ "$1" ]; then
    aws iam get-user --query 'User.UserName' --output text --user "$1"
  else
    aws iam get-user --query 'User.UserName' --output text
  fi
}

# Check if a bucket exists
aws_s3_bucket_exists() {
  if [ "$1" ] && aws s3api head-bucket --bucket "$1" 2>/dev/null; then
    return 0
  else
    return 1
  fi
}

# VELERO

# Functions from https://github.com/vmware-tanzu/velero-plugin-for-aws#setup

aws_create_velero_bucket() {
  _region="$1"
  _bucket="$DEFAULT_VELERO_BUCKET"
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
  _region="$1"
  _outf="$2"
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
REGION=$_region
S3_URL=
S3_PUBLIC_URL=
EOF
  stdout_to_file "$_outf" <"$tmp_dir/s3.env"
  rm -rf "$tmp_dir"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
