#!/bin/sh
# ----
# File:        ctools/eks.sh
# Description: Functions to manage eks deployments with terraform & kitt.
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022-2023 Kyso Inc.
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_CTOOLS_EKS_SH="1"

# ---------
# Variables
# ---------

# CMND_DSC="eks: manage eks cluster deployments with terraform and this tool"

# EKS defaults
export APP_DEFAULT_CLUSTER_REGION="eu-north-1"
_eks_instance_types="m5a.large,m6a.large,m5.large,m6i.large"
export APP_DEFAULT_CLUSTER_EKS_INSTANCE_TYPES="$_eks_instance_types"
export APP_DEFAULT_CLUSTER_EKS_VOLUME_SIZE="80"
export APP_DEFAULT_CLUSTER_EKS_MIN_WORKERS="0"
export APP_DEFAULT_CLUSTER_EKS_MAX_WORKERS="3"
export APP_DEFAULT_CLUSTER_EKS_WORKERS_AZ1="1"
export APP_DEFAULT_CLUSTER_EKS_WORKERS_AZ2="0"
export APP_DEFAULT_CLUSTER_EKS_WORKERS_AZ3=""
export APP_DEFAULT_CLUSTER_EFS_FILESYSTEMID=""
export APP_DEFAULT_CLUSTER_EKS_VERSION="1.25"
export APP_DEFAULT_CLUSTER_CDIR_PREFIX="10.23"
export APP_DEFAULT_CLUSTER_AWS_EBS_FS_TYPE="ext4"
export APP_DEFAULT_CLUSTER_AWS_EBS_TYPE="gp3"

# --------
# Includes
# --------

if [ -d "$INCL_DIR" ]; then
  # shellcheck source=../common.sh
  [ "$INCL_COMMON_SH" = "1" ] || . "$INCL_DIR/common.sh"
fi

# ---------
# Functions
# ---------

ctool_eks_export_variables() {
  # Check if we need to run the function
  [ -z "$__ctool_eks_export_variables" ] || return 0
  _cluster="$1"
  cluster_export_variables "$_cluster"
  # Get AWS values
  _aws_account_id="$(aws_get_account_id)"
  if [ -z "$_aws_account_id" ]; then
    echo "Can't find the aws account, call 'aws configure help'"
    exit 1
  fi
  _aws_user_name="$(aws_get_user_name)"
  export AWS_ACCOUNT_ID="$_aws_account_id"
  export AWS_USER_NAME="$_aws_user_name"
  # Variables
  [ "$CLUSTER_ADMINS" ] || CLUSTER_ADMINS="${AWS_USER_NAME}"
  export CLUSTER_ADMINS
  [ "$CLUSTER_DOMAIN" ] || CLUSTER_DOMAIN="${APP_DEFAULT_CLUSTER_DOMAIN}"
  export CLUSTER_DOMAIN
  [ "$CLUSTER_EKS_VERSION" ] ||
    CLUSTER_EKS_VERSION="${APP_DEFAULT_CLUSTER_EKS_VERSION}"
  export CLUSTER_EKS_VERSION
  [ "$CLUSTER_REGION" ] || CLUSTER_REGION="${APP_DEFAULT_CLUSTER_REGION}"
  export CLUSTER_REGION
  [ "$CLUSTER_AVAILABILITY_ZONES" ] ||
    CLUSTER_AVAILABILITY_ZONES="${APP_DEFAULT_CLUSTER_AVAILABILITY_ZONES}"
  export CLUSTER_AVAILABILITY_ZONES
  [ "$CLUSTER_EKS_INSTANCE_TYPES" ] ||
    CLUSTER_EKS_INSTANCE_TYPES="${APP_DEFAULT_CLUSTER_EKS_INSTANCE_TYPES}"
  export CLUSTER_EKS_INSTANCE_TYPES
  [ "$CLUSTER_EKS_VOLUME_SIZE" ] ||
    CLUSTER_EKS_VOLUME_SIZE="${APP_DEFAULT_CLUSTER_EKS_VOLUME_SIZE}"
  export CLUSTER_EKS_VOLUME_SIZE
  [ "$CLUSTER_MAX_WORKERS" ] ||
    CLUSTER_MAX_WORKERS="${APP_DEFAULT_CLUSTER_EKS_MAX_WORKERS}"
  export CLUSTER_MAX_WORKERS
  [ "$CLUSTER_MIN_WORKERS" ] ||
    CLUSTER_MIN_WORKERS="${APP_DEFAULT_CLUSTER_EKS_MIN_WORKERS}"
  export CLUSTER_MIN_WORKERS
  [ "$CLUSTER_WORKERS_AZ1" ] ||
    CLUSTER_WORKERS_AZ1="${APP_DEFAULT_CLUSTER_EKS_WORKERS_AZ1}"
  export CLUSTER_WORKERS_AZ1
  [ "$CLUSTER_WORKERS_AZ2" ] ||
    CLUSTER_WORKERS_AZ2="${APP_DEFAULT_CLUSTER_EKS_WORKERS_AZ2}"
  export CLUSTER_WORKERS_AZ2
  [ "$CLUSTER_WORKERS_AZ3" ] ||
    CLUSTER_WORKERS_AZ3="${APP_DEFAULT_CLUSTER_EKS_WORKERS_AZ3}"
  export CLUSTER_WORKERS_AZ3
  [ "$CLUSTER_CDIR_PREFIX" ] ||
    CLUSTER_CDIR_PREFIX="${APP_DEFAULT_CLUSTER_CDIR_PREFIX}"
  export CLUSTER_CDIR_PREFIX
  [ "$CLUSTER_EFS_FILESYSTEMID" ] ||
    CLUSTER_EFS_FILESYSTEMID="${APP_DEFAULT_CLUSTER_EFS_FILESYSTEMID}"
  export CLUSTER_EFS_FILESYSTEMID
  [ "$CLUSTER_AWS_EBS_FS_TYPE" ] ||
    CLUSTER_AWS_EBS_FS_TYPE="${APP_DEFAULT_CLUSTER_AWS_EBS_FS_TYPE}"
  export CLUSTER_AWS_EBS_FS_TYPE
  [ "$CLUSTER_AWS_EBS_TYPE" ] ||
    CLUSTER_AWS_EBS_TYPE="${APP_DEFAULT_CLUSTER_AWS_EBS_TYPE}"
  export CLUSTER_AWS_EBS_TYPE
  # Directories
  export TERRAFORM_TMPL_DIR="$TMPL_DIR/terraform"
  export TF_EKS_TMPL_DIR="$TERRAFORM_TMPL_DIR/eks"
  export TF_STATE_TMPL_DIR="$TERRAFORM_TMPL_DIR/state"
  export CLUST_TF_EKS_DIR="$CLUST_TERRAFORM_DIR/eks"
  export CLUST_TF_STATE_DIR="$CLUST_TERRAFORM_DIR/state"
  # Files
  export TF_EKS_CONF_TMPL="$TF_EKS_TMPL_DIR/config.tf"
  export TF_EKS_VARS_TMPL="$TF_EKS_TMPL_DIR/variables.tf"
  export TF_EKS_CONFIG="$CLUST_TF_EKS_DIR/config.tf"
  export TF_EKS_VARIABLES="$CLUST_TF_EKS_DIR/variables.tf"
  export TF_STATE_CONF_TMPL="$TF_STATE_TMPL_DIR/config.tf"
  export TF_STATE_VARS_TMPL="$TF_STATE_TMPL_DIR/variables.tf"
  export TF_STATE_CONFIG="$CLUST_TF_STATE_DIR/config.tf"
  export TF_STATE_VARIABLES="$CLUST_TF_STATE_DIR/variables.tf"
  export TF_STATE_BUCKET_NAME="kyso-$CLUSTER_NAME-terraform-$AWS_ACCOUNT_ID"
  export TF_STATE_TABLE_NAME="kyso-$CLUSTER_NAME-terraform"
  # set variable to avoid running the function twice
  __ctool_eks_export_variables="1"
}

ctool_eks_check_directories() {
  cluster_check_directories
  for _d in $CLUST_TERRAFORM_DIR; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

ctool_eks_read_variables() {
  # Read common cluster variables
  cluster_read_variables
  # Read list of cluster administrators
  read_value "Cluster admins (comma separated list of AWS usernames)" \
    "${CLUSTER_ADMINS}"
  CLUSTER_ADMINS=${READ_VALUE}
  # Read eks specific settings
  read_value "EKS Version" "${CLUSTER_EKS_VERSION}"
  CLUSTER_EKS_VERSION=${READ_VALUE}
  read_value "Cluster Region" "${CLUSTER_REGION}"
  CLUSTER_REGION=${READ_VALUE}
  read_value "Cluster EKS Instance Types" "${CLUSTER_EKS_INSTANCE_TYPES}"
  CLUSTER_EKS_INSTANCE_TYPES=${READ_VALUE}
  read_value "Cluster EKS Volume Size" "${CLUSTER_EKS_VOLUME_SIZE}"
  CLUSTER_EKS_VOLUME_SIZE=${READ_VALUE}
  read_value "Cluster Min Workers" "${CLUSTER_MIN_WORKERS}"
  CLUSTER_MIN_WORKERS=${READ_VALUE}
  read_value "Cluster Max Workers" "${CLUSTER_MAX_WORKERS}"
  CLUSTER_MAX_WORKERS=${READ_VALUE}
  read_value "Cluster Workers in AZ1" "${CLUSTER_WORKERS_AZ1}"
  CLUSTER_WORKERS_AZ1=${READ_VALUE}
  read_value "Cluster Workers in AZ2" "${CLUSTER_WORKERS_AZ2}"
  CLUSTER_WORKERS_AZ2=${READ_VALUE}
  read_value "Cluster Workers in AZ3" "${CLUSTER_WORKERS_AZ3}"
  CLUSTER_WORKERS_AZ3=${READ_VALUE}
  read_value "Cluster CDIR Prefix" "${CLUSTER_CDIR_PREFIX}"
  CLUSTER_CDIR_PREFIX=${READ_VALUE}
  read_value "Cluster EFS fileSystemId" "${CLUSTER_EFS_FILESYSTEMID}"
  CLUSTER_EFS_FILESYSTEMID=${READ_VALUE}
}

ctool_eks_print_variables() {
  # Print common cluster variables
  cluster_print_variables
  # Print eks variables
  cat <<EOF
# Comma separated list of cluster admins (aws usernames)
ADMINS=$CLUSTER_ADMINS
# EKS Version to use
EKS_VERSION=$CLUSTER_EKS_VERSION
# AWS Region to use for the EKS deployment
REGION=$CLUSTER_REGION
# EC2 Instance types to use with EKS
EKS_INSTANCE_TYPES=$CLUSTER_EKS_INSTANCE_TYPES
# EKS Nodes Volume Size
EKS_VOLUME_SIZE=$CLUSTER_EKS_VOLUME_SIZE
# Minimum Number of ECS nodes to launch as workers
MIN_WORKERS=$CLUSTER_MIN_WORKERS
# Maximum Number of ECS nodes to launch as workers
MAX_WORKERS=$CLUSTER_MAX_WORKERS
# Number of nodes in AZ1 (leave empty to avoid creating the AZ1)
WORKERS_AZ1=$CLUSTER_WORKERS_AZ1
# Number of nodes in AZ2 (leave empty to avoid creating the AZ2)
WORKERS_AZ2=$CLUSTER_WORKERS_AZ2
# Number of nodes in AZ3 (leave empty to avoid creating the AZ3)
WORKERS_AZ3=$CLUSTER_WORKERS_AZ3
# Cluster CDIR prefix (i.e. for 10.0 internal CDIR will be 10.0.0.0/16)
CDIR_PREFIX=$CLUSTER_CDIR_PREFIX
# EFS filesystem to use for dynamic volumes
EFS_FILESYSTEMID=$CLUSTER_EFS_FILESYSTEMID
EOF
}

# Function to create the S3 bucket & DynamoDB table to keep the Terraform state
ctool_eks_setup_tf() {
  _cluster="$1"
  ctool_eks_export_variables "$_cluster"
  [ -d "$CLUST_TF_STATE_DIR" ] || mkdir "$CLUST_TF_STATE_DIR"
  echo ".terraform/" > "$CLUST_TF_STATE_DIR/.gitignore"
  cp -a "$TF_STATE_TMPL_DIR"/*.tf "$CLUST_TF_STATE_DIR/"
  sed \
      -e "s%__CLUSTER_NAME__%$CLUSTER_NAME%g" \
      -e "s%__CLUSTER_REGION__%$CLUSTER_REGION%g" \
      -e "s%__TF_STATE_BUCKET_NAME__%$TF_STATE_BUCKET_NAME%g" \
      -e "s%__TF_STATE_TABLE_NAME__%$TF_STATE_TABLE_NAME%g" \
      "$TF_STATE_VARS_TMPL" >"$TF_STATE_VARIABLES"
  cd "$CLUST_TF_STATE_DIR"
  if ! aws_s3_bucket_exists "$TF_STATE_BUCKET_NAME"; then
    rm -f "$TF_STATE_CONFIG"
    terraform init
    terraform apply
  fi
  # Generate CONFIG file & init and apply again
  sed \
    -e "s%__CLUSTER_NAME__%$CLUSTER_NAME%g" \
    -e "s%__CLUSTER_REGION__%$CLUSTER_REGION%g" \
    -e "s%__TF_STATE_BUCKET_NAME__%$TF_STATE_BUCKET_NAME%g" \
    -e "s%__TF_STATE_TABLE_NAME__%$TF_STATE_TABLE_NAME%g" \
    "$TF_STATE_CONF_TMPL" >"$TF_STATE_CONFIG"
  terraform init
  terraform apply
}

ctool_eks_tf_conf() {
  _cluster="$1"
  ctool_eks_export_variables "$_cluster"
  if ! aws_s3_bucket_exists "$TF_STATE_BUCKET_NAME"; then
    echo "The terraform state bucket does not exist, call 'setup-tf' subcommand"
    exit 1
  fi
  [ -d "$CLUST_TF_EKS_DIR" ] || mkdir "$CLUST_TF_EKS_DIR"
  echo ".terraform/" > "$CLUST_TF_EKS_DIR/.gitignore"
  cp -a "$TF_EKS_TMPL_DIR"/*.tf "$CLUST_TF_EKS_DIR/"
  # AWS_AUTH_USERS
  _aws_auth_users_list="$CLUST_TF_EKS_DIR/aws_auth_users.txt"
  _cmnd="/^ *# BEG: AWS_AUTH_USERS/,/^ *# END: AWS_AUTH_USERS/"
  _cmnd="$_cmnd{/^ *# \(BEG\|END\): AWS_AUTH_USERS/d;p;}"
  _aws_auth_users_text="$(sed -n -e "$_cmnd" "$TF_EKS_VARIABLES")"
  bad_users=""
  for _aws_user_name in $(echo "$CLUSTER_ADMINS" | sed -e 's/,/ /g'); do
    _aws_user_arn="$(aws_get_user_arn "$_aws_user_name")"
    if [ "$_aws_user_arn" ]; then
      echo "$_aws_auth_users_text" |
        sed -e "s%__AWS_USER_ARN__%$_aws_user_arn%g" \
            -e "s%__AWS_USER_NAME__%$_aws_user_name%g"
    else
      bad_users="$_aws_user_name $bad_users"
    fi
  done >"$_aws_auth_users_list"
  if [ "$bad_users" ]; then
    echo "The following AWS users were not found:"
    for _u in $bad_users; do echo "- $_u"; done
    echo "Aborting !!!"
    rm -f "$_aws_auth_users_list"
  fi
  # KMS_KEY_ADMINISTRATORS
  _kms_key_administrators_list="$CLUST_TF_EKS_DIR/kms_key_administrators.txt"
  _cmnd="/^ *# BEG: KMS_KEY_ADMINISTRATORS/,/^ *# END: KMS_KEY_ADMINISTRATORS/"
  _cmnd="$_cmnd{/^ *# \(BEG\|END\): KMS_KEY_ADMINISTRATORS/d;p;}"
  _kms_key_administrators_text="$(sed -n -e "$_cmnd" "$TF_EKS_VARIABLES")"
  for _aws_user_name in $(echo "$CLUSTER_ADMINS" | sed -e 's/,/ /g'); do
    _aws_user_arn="$(aws_get_user_arn "$_aws_user_name")"
    echo "$_kms_key_administrators_text" |
      sed -e "s%__AWS_USER_ARN__%$_aws_user_arn%g"
  done >"$_kms_key_administrators_list"
  # EKS_INSTANCE_TYPES
  _eks_instance_types_list="$CLUST_TF_EKS_DIR/eks_instance_types.txt"
  _cmnd="/^ *# BEG: EKS_INSTANCE_TYPES/,/^ *# END: EKS_INSTANCE_TYPES/"
  _cmnd="$_cmnd{/^ *# \(BEG\|END\): EKS_INSTANCE_TYPES/d;p;}"
  _eks_instance_types_text="$(sed -n -e "$_cmnd" "$TF_EKS_VARIABLES")"
  for _itype in $(echo "$CLUSTER_EKS_INSTANCE_TYPES" | sed -e 's/,/ /g'); do
    echo "$_eks_instance_types_text" |
      sed -e "s%__EKS_INSTANCE_TYPE__%$_itype%g"
  done >"$_eks_instance_types_list"
  # AZ related values
  if [ "$CLUSTER_WORKERS_AZ1" ]; then
    _az1_sed="s%__AZ1_NAME__%${CLUSTER_REGION}a%g"
    _az1_sed="$_az1_sed;s%__AZ1_WORKERS__%$CLUSTER_WORKERS_AZ1%g"
  else
    CLUSTER_WORKERS_AZ1="0"
    _az1_sed="/__AZ1_NAME__/d;/__AZ1_WORKERS__/d"
  fi
  if [ "$CLUSTER_WORKERS_AZ2" ]; then
    _az2_sed="s%__AZ2_NAME__%${CLUSTER_REGION}b%g"
    _az2_sed="$_az2_sed;s%__AZ2_WORKERS__%$CLUSTER_WORKERS_AZ2%g"
  else
    CLUSTER_WORKERS_AZ2="0"
    _az2_sed="/__AZ2_NAME__/d;/__AZ2_WORKERS__/d"
  fi
  if [ "$CLUSTER_WORKERS_AZ3" ]; then
    _az3_sed="s%__AZ3_NAME__%${CLUSTER_REGION}c%g"
    _az3_sed="$_az3_sed;s%__AZ3_WORKERS__%$CLUSTER_WORKERS_AZ3%g"
  else
    CLUSTER_WORKERS_AZ3="0"
    _az3_sed="/__AZ3_NAME__/d;/__AZ3_WORKERS__/d"
  fi
  # If only the AZ1 has workers use a single nat gateway
  if [ "$CLUSTER_WORKERS_AZ1" -gt "0" ] &&
    [ "$CLUSTER_WORKERS_AZ2" -eq "0" ] &&
    [ "$CLUSTER_WORKERS_AZ3" -eq "0" ]; then
    _single_nat_gateway="true"
  else
    _single_nat_gateway="false"
  fi
  # Generate VARIABLES file
  sed \
    -e "s%__AWS_ACCOUNT_ID__%$AWS_ACCOUNT_ID%g" \
    -e "s%__CLUSTER_EKS_VERSION__%$CLUSTER_EKS_VERSION%g" \
    -e "s%__CLUSTER_REGION__%$CLUSTER_REGION%g" \
    -e "s%__CLUSTER_NAME__%$CLUSTER_NAME%g" \
    -e "s%__CLUSTER_MAX_WORKERS__%$CLUSTER_MAX_WORKERS%g" \
    -e "s%__CLUSTER_MIN_WORKERS__%$CLUSTER_MIN_WORKERS%g" \
    -e "s%__CLUSTER_CDIR_PREFIX__%$CLUSTER_CDIR_PREFIX%g" \
    -e "s%__CLUSTER_EKS_VOLUME_SIZE__%$CLUSTER_EKS_VOLUME_SIZE%g" \
    -e "s%__TF_STATE_BUCKET_NAME__%$TF_STATE_BUCKET_NAME%g" \
    -e "s%__SINGLE_NAT_GATEWAY__%$_single_nat_gateway%g" \
    -e "/^ *# END: AWS_AUTH_USERS/r $_aws_auth_users_list" \
    -e "/^ *# BEG: AWS_AUTH_USERS/,/^ *# END: AWS_AUTH_USERS/d" \
    -e "/^ *# END: KMS_KEY_ADMINISTRATORS/r $_kms_key_administrators_list" \
    -e "/^ *# BEG: KMS_KEY_ADMINISTRATORS/,/^ *# END: KMS_KEY_ADMINISTRATORS/d"\
    -e "/^ *# END: EKS_INSTANCE_TYPES/r $_eks_instance_types_list" \
    -e "/^ *# BEG: EKS_INSTANCE_TYPES/,/^ *# END: EKS_INSTANCE_TYPES/d"\
    -e "$_az1_sed" \
    -e "$_az2_sed" \
    -e "$_az3_sed" \
    "$TF_EKS_VARS_TMPL" >"$TF_EKS_VARIABLES"
  rm -f "$_aws_auth_users_list"
  rm -f "$_kms_key_administrators_list"
  rm -f "$_eks_instance_types_list"
  # Generate CONFIG file
  sed \
    -e "s%__CLUSTER_REGION__%$CLUSTER_REGION%g" \
    -e "s%__CLUSTER_NAME__%$CLUSTER_NAME%g" \
    -e "s%__TF_STATE_BUCKET_NAME__%$TF_STATE_BUCKET_NAME%g" \
    "$TF_EKS_CONF_TMPL" >"$TF_EKS_CONFIG"
}

ctool_eks_tf_init() {
  ctool_eks_tf_conf "$1"
  cd "$CLUST_TF_EKS_DIR"
  terraform init
}

ctool_eks_tf_plan() {
  ctool_eks_tf_conf "$1"
  cd "$CLUST_TF_EKS_DIR"
  terraform plan
}

ctool_eks_tf_apply() {
  ctool_eks_tf_conf "$1"
  cd "$CLUST_TF_EKS_DIR"
  terraform apply
}

ctool_eks_tf_destroy() {
  ctool_eks_tf_conf "$1"
  cd "$CLUST_TF_EKS_DIR"
  terraform destroy
}

eks_get_cluster_json() {
  _cluster="$1"
  ctool_eks_export_variables "$_cluster"
  eksctl get cluster -n "${CLUSTER_NAME}" -r "${CLUSTER_REGION}" -o json \
    2>/dev/null || true
}

eks_get_cluster_status() {
  _cluster="$1"
  eks_get_cluster_json "$_cluster" | jq -r ".[0].Status"
}

ctool_eks_scale() {
  _cluster="$1"
  ctool_eks_export_variables "$_cluster"
  eksctl scale nodegroup --cluster="$CLUSTER_NAME" \
    --name="$CLUSTER_EKS_MNG1" --nodes-min="$CLUSTER_MIN_WORKERS" \
    --nodes-max="$CLUSTER_MAX_WORKERS" --nodes="$CLUSTER_AZ1_WORKERS"
  eksctl scale nodegroup --cluster="$CLUSTER_NAME" \
    --name="$CLUSTER_EKS_MNG2" --nodes-min="$CLUSTER_MIN_WORKERS" \
    --nodes-max="$CLUSTER_MAX_WORKERS" --nodes="$CLUSTER_AZ2_WORKERS"
  eksctl scale nodegroup --cluster="$CLUSTER_NAME" \
    --name="$CLUSTER_EKS_MNG3" --nodes-min="$CLUSTER_MIN_WORKERS" \
    --nodes-max="$CLUSTER_MAX_WORKERS" --nodes="$CLUSTER_AZ3_WORKERS"
}

ctool_eks_status() {
  _cluster="$1"
  eks_get_cluster_status "$_cluster"
}

ctool_eks_kubeconfig() {
  _cluster="$1"
  ctool_eks_export_variables "$_cluster"
  aws eks update-kubeconfig --region "$CLUSTER_REGION" --name "$CLUSTER_NAME"
  # Try to switch to the right kubectl context
  KUBECTL_CONTEXT="$(guess_kubectl_context "$CLUSTER_KIND" "$CLUSTER_NAME")"
  kubectx "$KUBECTL_CONTEXT"
  kubectl cluster-info
}

ctool_eks_install() {
  ctool_eks_setup_tf "$1"
  ctool_eks_tf_conf "$1"
  cd "$CLUST_TF_EKS_DIR"
  terraform init
  terraform apply
  ctool_eks_kubeconfig "$1"
}

ctool_eks_remove() {
  if [ -d "$CLUST_TF_EKS_DIR" ]; then
    ctool_eks_tf_conf "$1"
    _opwd="$(pwd)"
    cd "$CLUST_TF_EKS_DIR"
    terraform destroy
    cd "$_opwd"
  fi
  cluster_remove_directories
}

ctool_eks_command() {
  _command="$1"
  _cluster="$2"
  case "$_command" in
    install) ctool_eks_install "$_cluster" ;;
    remove) ctool_eks_remove "$_cluster" ;;
    setup-tf) ctool_eks_setup_tf "$_cluster" ;;
    tf-conf) ctool_eks_tf_conf "$_cluster" ;;
    tf-init) ctool_eks_tf_init "$_cluster" ;;
    tf-plan) ctool_eks_tf_plan "$_cluster" ;;
    tf-apply) ctool_eks_tf_apply "$_cluster" ;;
    tf-destroy) ctool_eks_tf_destroy "$_cluster" ;;
    status) ctool_eks_status "$_cluster" ;;
    scale) ctool_eks_scale "$_cluster" ;;
    kubeconfig) ctool_eks_kubeconfig "$_cluster" ;;
    *) echo "Unknown eks subcommand '$_command'"; exit 1 ;;
  esac
}

ctool_eks_command_list() {
  _commands="install remove status scale kubeconfig"
  _commands="$_commands setup-tf tf-conf tf-init tf-plan tf-apply tf-destroy"
  echo "$_commands"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=3
