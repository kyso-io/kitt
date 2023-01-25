#!/bin/sh
# ----
# File:        ctools/eks.sh
# Description: Functions to manage eks cluster deployments with kitt.
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022-2023 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_CTOOLS_EKS_SH="1"

# ---------
# Variables
# ---------

# CMND_DSC="eks: manage eks cluster deployments with this tool"

# EKS defaults
export APP_DEFAULT_CLUSTER_REGION="eu-north-1"
APP_DEFAULT_CLUSTER_AVAILABILITY_ZONES="eu-north-1a,eu-north-1b,eu-north-1c"
export APP_DEFAULT_CLUSTER_AVAILABILITY_ZONES
export APP_DEFAULT_CLUSTER_EKS_MNG1="mng1"
export APP_DEFAULT_CLUSTER_EKS_MNG1_AZ="eu-north-1a"
export APP_DEFAULT_CLUSTER_EKS_MNG2="mng2"
export APP_DEFAULT_CLUSTER_EKS_MNG2_AZ="eu-north-1b"
export APP_DEFAULT_CLUSTER_EKS_MNG3="mng3"
export APP_DEFAULT_CLUSTER_EKS_MNG3_AZ="eu-north-1c"
export APP_DEFAULT_CLUSTER_EKS_INSTANCE_TYPE="m5.large"
export APP_DEFAULT_CLUSTER_EKS_VOLUME_SIZE="80"
export APP_DEFAULT_CLUSTER_EKS_MIN_WORKERS="0"
export APP_DEFAULT_CLUSTER_EKS_MAX_WORKERS="3"
export APP_DEFAULT_CLUSTER_EKS_NUM_WORKERS_MNG1="1"
export APP_DEFAULT_CLUSTER_EKS_NUM_WORKERS_MNG2="0"
export APP_DEFAULT_CLUSTER_EKS_NUM_WORKERS_MNG3="0"
export APP_DEFAULT_CLUSTER_EFS_FILESYSTEMID=""
export APP_DEFAULT_CLUSTER_EKS_VERSION="1.23"
export APP_DEFAULT_CLUSTER_AWS_EBS_FS_TYPE="ext4"
export APP_DEFAULT_CLUSTER_AWS_EBS_TYPE="gp2"

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
  # Variables
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
  [ "$CLUSTER_EKS_MNG1" ] || CLUSTER_EKS_MNG1="${APP_DEFAULT_CLUSTER_EKS_MNG1}"
  export CLUSTER_EKS_MNG1
  [ "$CLUSTER_EKS_MNG1_AZ" ] ||
    CLUSTER_EKS_MNG1_AZ="${APP_DEFAULT_CLUSTER_EKS_MNG1_AZ}"
  export CLUSTER_EKS_MNG1_AZ
  [ "$CLUSTER_EKS_MNG2" ] || CLUSTER_EKS_MNG2="${APP_DEFAULT_CLUSTER_EKS_MNG2}"
  export CLUSTER_EKS_MNG2
  [ "$CLUSTER_EKS_MNG2_AZ" ] ||
    CLUSTER_EKS_MNG2_AZ="${APP_DEFAULT_CLUSTER_EKS_MNG2_AZ}"
  export CLUSTER_EKS_MNG2_AZ
  [ "$CLUSTER_EKS_MNG3" ] || CLUSTER_EKS_MNG3="${APP_DEFAULT_CLUSTER_EKS_MNG3}"
  export CLUSTER_EKS_MNG3
  [ "$CLUSTER_EKS_MNG3_AZ" ] ||
    CLUSTER_EKS_MNG3_AZ="${APP_DEFAULT_CLUSTER_EKS_MNG3_AZ}"
  export CLUSTER_EKS_MNG3_AZ
  [ "$CLUSTER_EKS_INSTANCE_TYPE" ] ||
    CLUSTER_EKS_INSTANCE_TYPE="${APP_DEFAULT_CLUSTER_EKS_INSTANCE_TYPE}"
  export CLUSTER_EKS_INSTANCE_TYPE
  [ "$CLUSTER_EKS_VOLUME_SIZE" ] ||
    CLUSTER_EKS_VOLUME_SIZE="${APP_DEFAULT_CLUSTER_EKS_VOLUME_SIZE}"
  export CLUSTER_EKS_VOLUME_SIZE
  [ "$CLUSTER_MAX_WORKERS" ] ||
    CLUSTER_MAX_WORKERS="${APP_DEFAULT_CLUSTER_EKS_MAX_WORKERS}"
  export CLUSTER_MAX_WORKERS
  [ "$CLUSTER_MIN_WORKERS" ] ||
    CLUSTER_MIN_WORKERS="${APP_DEFAULT_CLUSTER_EKS_MIN_WORKERS}"
  export CLUSTER_MIN_WORKERS
  [ "$CLUSTER_NUM_WORKERS_MNG1" ] ||
    CLUSTER_NUM_WORKERS_MNG1="${APP_DEFAULT_CLUSTER_EKS_NUM_WORKERS_MNG1}"
  export CLUSTER_NUM_WORKERS_MNG1
  [ "$CLUSTER_NUM_WORKERS_MNG2" ] ||
    CLUSTER_NUM_WORKERS_MNG2="${APP_DEFAULT_CLUSTER_EKS_NUM_WORKERS_MNG2}"
  export CLUSTER_NUM_WORKERS_MNG2
  [ "$CLUSTER_NUM_WORKERS_MNG3" ] ||
    CLUSTER_NUM_WORKERS_MNG3="${APP_DEFAULT_CLUSTER_EKS_NUM_WORKERS_MNG3}"
  export CLUSTER_NUM_WORKERS_MNG3
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
  export EKS_TMPL_DIR="$TMPL_DIR/eks"
  # Templates
  export EKS_CONFIG_TMPL="$EKS_TMPL_DIR/cluster.yaml"
  # Generated files
  export EKS_CONFIG_YAML="$CLUST_EKS_DIR/cluster.yaml"
  # set variable to avoid running the function twice
  __ctool_eks_export_variables="1"
}

ctool_eks_check_directories() {
  cluster_check_directories
  for _d in $CLUST_EKS_DIR; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

ctool_eks_read_variables() {
  # Read common cluster variables
  cluster_read_variables
  # Read eks specific settings
  read_value "EKS Version" "${CLUSTER_EKS_VERSION}"
  CLUSTER_EKS_VERSION=${READ_VALUE}
  read_value "Cluster Region" "${CLUSTER_REGION}"
  CLUSTER_REGION=${READ_VALUE}
  read_value "Cluster Availability Zones" "${CLUSTER_AVAILABILITY_ZONES}"
  CLUSTER_AVAILABILITY_ZONES=${READ_VALUE}
  read_value "Cluster EKS Node Group 1" "${CLUSTER_EKS_MNG1}"
  CLUSTER_EKS_MNG1=${READ_VALUE}
  read_value "Cluster EKS Node Group 1 Availability Zone" \
    "${CLUSTER_EKS_MNG1_AZ}"
  CLUSTER_EKS_MNG1_AZ=${READ_VALUE}
  read_value "Cluster EKS Node Group 2" "${CLUSTER_EKS_MNG2}"
  CLUSTER_EKS_MNG2=${READ_VALUE}
  read_value "Cluster EKS Node Group 2 Availability Zone" \
    "${CLUSTER_EKS_MNG2_AZ}"
  CLUSTER_EKS_MNG2_AZ=${READ_VALUE}
  read_value "Cluster EKS Node Group 3" "${CLUSTER_EKS_MNG3}"
  CLUSTER_EKS_MNG3=${READ_VALUE}
  read_value "Cluster EKS Node Group 3 Availability Zone" \
    "${CLUSTER_EKS_MNG3_AZ}"
  CLUSTER_EKS_MNG3_AZ=${READ_VALUE}
  read_value "Cluster EKS Instance Type" "${CLUSTER_EKS_INSTANCE_TYPE}"
  CLUSTER_EKS_INSTANCE_TYPE=${READ_VALUE}
  read_value "Cluster EKS Volume Size" "${CLUSTER_EKS_VOLUME_SIZE}"
  CLUSTER_EKS_VOLUME_SIZE=${READ_VALUE}
  read_value "Cluster Min Workers" "${CLUSTER_MIN_WORKERS}"
  CLUSTER_MIN_WORKERS=${READ_VALUE}
  read_value "Cluster Max Workers" "${CLUSTER_MAX_WORKERS}"
  CLUSTER_MAX_WORKERS=${READ_VALUE}
  read_value \
    "MNG1 Workers (between $CLUSTER_MIN_WORKERS & $CLUSTER_MAX_WORKERS)" \
    "${CLUSTER_NUM_WORKERS_MNG1}"
  CLUSTER_NUM_WORKERS_MNG1=${READ_VALUE}
  read_value \
    "MNG2 Workers (between $CLUSTER_MIN_WORKERS & $CLUSTER_MAX_WORKERS)" \
    "${CLUSTER_NUM_WORKERS_MNG2}"
  CLUSTER_NUM_WORKERS_MNG2=${READ_VALUE}
  read_value \
    "MNG3 Workers (between $CLUSTER_MIN_WORKERS & $CLUSTER_MAX_WORKERS)" \
    "${CLUSTER_NUM_WORKERS_MNG3}"
  CLUSTER_NUM_WORKERS_MNG3=${READ_VALUE}
  read_value "Cluster EFS fileSystemId" "${CLUSTER_EFS_FILESYSTEMID}"
  CLUSTER_EFS_FILESYSTEMID=${READ_VALUE}

}

ctool_eks_print_variables() {
  # Print common cluster variables
  cluster_print_variables
  # Print eks variables
  cat <<EOF
EKS_VERSION=$CLUSTER_EKS_VERSION
# AWS Region to use for the EKS deployment
REGION=$CLUSTER_REGION
# AWS Availability Zones to use for the EKS deployment
AVAILABILITY_ZONES=$CLUSTER_AVAILABILITY_ZONES
# Name of the EKS node group 1
EKS_MNG1=$CLUSTER_EKS_MNG1
# EKS node group 1 Availability Zone
EKS_MNG1_AZ=$CLUSTER_EKS_MNG1_AZ
# Name of the EKS node group 2
EKS_MNG2=$CLUSTER_EKS_MNG2
# EKS node group 2 Availability Zone
EKS_MNG2_AZ=$CLUSTER_EKS_MNG2_AZ
# Name of the EKS node group 3
EKS_MNG3=$CLUSTER_EKS_MNG3
# EKS node group 3 Availability Zone
EKS_MNG3_AZ=$CLUSTER_EKS_MNG3_AZ
# EKS Instance Type
EKS_INSTANCE_TYPE=$CLUSTER_EKS_INSTANCE_TYPE
# EKS Nodes Volume Size
EKS_VOLUME_SIZE=$CLUSTER_EKS_VOLUME_SIZE
# Minimum Number of ECS nodes to launch as workers
MIN_WORKERS=$CLUSTER_MIN_WORKERS
# Maximum Number of ECS nodes to launch as workers
MAX_WORKERS=$CLUSTER_MAX_WORKERS
# Number of ECS nodes to launch as workers for MNG1
NUM_WORKERS_MNG1=$CLUSTER_NUM_WORKERS_MNG1
# Number of ECS nodes to launch as workers for MNG2
NUM_WORKERS_MNG2=$CLUSTER_NUM_WORKERS_MNG2
# Number of ECS nodes to launch as workers for MNG3
NUM_WORKERS_MNG3=$CLUSTER_NUM_WORKERS_MNG3
# EFS filesystem to use for dynamic volumes
EFS_FILESYSTEMID=$CLUSTER_EFS_FILESYSTEMID
EOF
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

eks_get_cluster_vpcid() {
  _cluster="$1"
  eks_get_cluster_json "$_cluster" | jq -r ".[0].ResourcesVpcConfig.VpcId"
}

# Installation related functions
ctool_eks_install() {
  _cluster="$1"
  ctool_eks_export_variables "$_cluster"
  # Get cluster information
  cluster_status="$(eks_get_cluster_status)"
  # Create the cluster if it does not exist
  if [ "$cluster_status" ]; then
    header "EKS cluster '${CLUSTER_NAME}' already exist"
    echo "The cluster status is '${cluster_status}'"
  else
    ctool_eks_check_directories
    header "Creating EKS cluster '${CLUSTER_NAME}'"
    sed \
      -e "s%__CLUSTER_NAME__%$CLUSTER_NAME%g" \
      -e "s%__EKS_VERSION__%$CLUSTER_EKS_VERSION%g" \
      -e "s%__CLUSTER_REGION__%$CLUSTER_REGION%g" \
      -e "s%__CLUSTER_AVAILABILITY_ZONES__%$CLUSTER_AVAILABILITY_ZONES%g" \
      -e "s%__CLUSTER_EKS_MNG1__%$CLUSTER_EKS_MNG1%g" \
      -e "s%__CLUSTER_EKS_MNG1_AZ__%$CLUSTER_EKS_MNG1_AZ%g" \
      -e "s%__CLUSTER_EKS_MNG2__%$CLUSTER_EKS_MNG2%g" \
      -e "s%__CLUSTER_EKS_MNG2_AZ__%$CLUSTER_EKS_MNG2_AZ%g" \
      -e "s%__CLUSTER_EKS_MNG3__%$CLUSTER_EKS_MNG3%g" \
      -e "s%__CLUSTER_EKS_MNG3_AZ__%$CLUSTER_EKS_MNG3_AZ%g" \
      -e "s%__CLUSTER_EKS_INSTANCE_TYPE__%$CLUSTER_EKS_INSTANCE_TYPE%g" \
      -e "s%__CLUSTER_EKS_VOLUME_SIZE__%$CLUSTER_EKS_VOLUME_SIZE%g" \
      -e "s%__CLUSTER_NUM_WORKERS_MNG1__%$CLUSTER_NUM_WORKERS_MNG1%g" \
      -e "s%__CLUSTER_NUM_WORKERS_MNG2__%$CLUSTER_NUM_WORKERS_MNG2%g" \
      -e "s%__CLUSTER_NUM_WORKERS_MNG3__%$CLUSTER_NUM_WORKERS_MNG3%g" \
      -e "s%__CLUSTER_MAX_WORKERS__%$CLUSTER_MAX_WORKERS%g" \
      -e "s%__CLUSTER_MIN_WORKERS__%$CLUSTER_MIN_WORKERS%g" \
      "$EKS_CONFIG_TMPL" >"$EKS_CONFIG_YAML"
    eksctl create cluster --ssh-access --config-file="$EKS_CONFIG_YAML"
  fi
  footer
  kubectx "$KUBECTL_CONTEXT"
  kubectl cluster-info
  footer
}

ctool_eks_remove() {
  _cluster="$1"
  ctool_eks_export_variables "$_cluster"
  # Remove old cluster?
  if [ -f "$EKS_CONFIG_YAML" ]; then
    # Get cluster status
    cluster_status="$(eks_get_cluster_status)"
    if [ "$cluster_status" ]; then
      read_value "Delete cluster '${CLUSTER_NAME}' (status '$cluster_status')" \
        "Yes"
      if is_selected "${READ_VALUE}"; then
        header "Deleting EKS cluster '${CLUSTER_NAME}'"
        eksctl delete cluster --config-file="$EKS_CONFIG_YAML"
        rm -f "$EKS_CONFIG_YAML"
      fi
      cluster_remove_directories
    else
      rm -f "$EKS_CONFIG_YAML"
    fi
  fi
}

ctool_eks_scale() {
  _cluster="$1"
  ctool_eks_export_variables "$_cluster"
  eksctl scale nodegroup --cluster="$CLUSTER_NAME" \
    --name="$CLUSTER_EKS_MNG1" --nodes-min="$CLUSTER_MIN_WORKERS" \
    --nodes-max="$CLUSTER_MAX_WORKERS" --nodes="$CLUSTER_NUM_WORKERS_MNG1"
  eksctl scale nodegroup --cluster="$CLUSTER_NAME" \
    --name="$CLUSTER_EKS_MNG2" --nodes-min="$CLUSTER_MIN_WORKERS" \
    --nodes-max="$CLUSTER_MAX_WORKERS" --nodes="$CLUSTER_NUM_WORKERS_MNG2"
  eksctl scale nodegroup --cluster="$CLUSTER_NAME" \
    --name="$CLUSTER_EKS_MNG3" --nodes-min="$CLUSTER_MIN_WORKERS" \
    --nodes-max="$CLUSTER_MAX_WORKERS" --nodes="$CLUSTER_NUM_WORKERS_MNG3"
}

ctool_eks_status() {
  _cluster="$1"
  eks_get_cluster_status "$_cluster"
}

ctool_eks_command() {
  _command="$1"
  _cluster="$2"
  case "$_command" in
    install) ctool_eks_install "$_cluster" ;;
    remove) ctool_eks_remove "$_cluster" ;;
    scale) ctool_eks_scale "$_cluster" ;;
    status) ctool_eks_status "$_cluster" ;;
    *) echo "Unknown eks subcommand '$_command'"; exit 1 ;;
  esac
}

ctool_eks_command_list() {
  echo "install remove scale status"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=3
