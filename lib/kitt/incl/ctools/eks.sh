#!/bin/sh
# ----
# File:        ctools/eks.sh
# Description: Functions to manage eks cluster deployments with kitt.
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022 Sergio Talens-Oliag <sto@kyso.io>
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
export APP_DEFAULT_CLUSTER_EKS_NODEGROUP="mng01"
export APP_DEFAULT_CLUSTER_EKS_NODEGROUP_AZ="eu-north-1a"
export APP_DEFAULT_CLUSTER_EKS_INSTANCE_TYPE="m5.large"
export APP_DEFAULT_CLUSTER_EKS_VOLUME_SIZE="80"
export APP_DEFAULT_CLUSTER_EKS_MIN_WORKERS="1"
export APP_DEFAULT_CLUSTER_EKS_MAX_WORKERS="9"
export APP_DEFAULT_CLUSTER_EKS_NUM_WORKERS="3"
export APP_DEFAULT_CLUSTER_EFS_FILESYSTEMID=""
export APP_DEFAULT_CLUSTER_EKS_VERSION="1.22"
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
  [ "$CLUSTER_EKS_NODEGROUP" ] ||
    CLUSTER_EKS_NODEGROUP="${APP_DEFAULT_CLUSTER_EKS_NODEGROUP}"
  export CLUSTER_EKS_NODEGROUP
  [ "$CLUSTER_EKS_NODEGROUP_AZ" ] ||
    CLUSTER_EKS_NODEGROUP_AZ="${APP_DEFAULT_CLUSTER_EKS_NODEGROUP_AZ}"
  export CLUSTER_EKS_NODEGROUP_AZ
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
  [ "$CLUSTER_NUM_WORKERS" ] ||
    CLUSTER_NUM_WORKERS="${APP_DEFAULT_CLUSTER_EKS_NUM_WORKERS}"
  export CLUSTER_NUM_WORKERS
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
  export AWS_EBS_STORAGECLASS_TMPL="$EKS_TMPL_DIR/storageclass-aws-ebs.yaml"
  # Generated files
  export EKS_CONFIG_YAML="$CLUST_EKS_DIR/cluster.yaml"
  AWS_EBS_STORAGECLASS_YAML="$CLUST_KUBECTL_DIR/storageclass-aws-ebs.yaml"
  export AWS_EBS_STORAGECLASS_YAML
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
  read_value "Cluster DNS Domain" "${CLUSTER_DOMAIN}"
  CLUSTER_DOMAIN=${READ_VALUE}
  read_value "EKS Version" "${CLUSTER_EKS_VERSION}"
  CLUSTER_EKS_VERSION=${READ_VALUE}
  read_value "Cluster Region" "${CLUSTER_REGION}"
  CLUSTER_REGION=${READ_VALUE}
  read_value "Cluster Availability Zones" "${CLUSTER_AVAILABILITY_ZONES}"
  CLUSTER_AVAILABILITY_ZONES=${READ_VALUE}
  read_value "Cluster EKS Node Group" "${CLUSTER_EKS_NODEGROUP}"
  CLUSTER_EKS_NODEGROUP=${READ_VALUE}
  read_value "Cluster EKS Node Group Availability Zone" \
    "${CLUSTER_EKS_NODEGROUP_AZ}"
  CLUSTER_EKS_NODEGROUP_AZ=${READ_VALUE}
  read_value "Cluster EKS Instance Type" "${CLUSTER_EKS_INSTANCE_TYPE}"
  CLUSTER_EKS_INSTANCE_TYPE=${READ_VALUE}
  read_value "Cluster EKS Volume Size" "${CLUSTER_EKS_VOLUME_SIZE}"
  CLUSTER_EKS_VOLUME_SIZE=${READ_VALUE}
  read_value "Cluster Min Workers" "${CLUSTER_MIN_WORKERS}"
  CLUSTER_MIN_WORKERS=${READ_VALUE}
  read_value "Cluster Max Workers" "${CLUSTER_MAX_WORKERS}"
  CLUSTER_MAX_WORKERS=${READ_VALUE}
  read_value \
    "Cluster Workers (between $CLUSTER_MIN_WORKERS & $CLUSTER_MAX_WORKERS)" \
    "${CLUSTER_NUM_WORKERS}"
  CLUSTER_NUM_WORKERS=${READ_VALUE}
  read_value "Cluster EFS fileSystemId" "${CLUSTER_EFS_FILESYSTEMID}"
  CLUSTER_EFS_FILESYSTEMID=${READ_VALUE}
  read_value "Cluster Ingress Replicas" "${CLUSTER_INGRESS_REPLICAS}"
  CLUSTER_INGRESS_REPLICAS=${READ_VALUE}
  read_bool "Force SSL redirect on ingress" "${CLUSTER_FORCE_SSL_REDIRECT}"
  CLUSTER_FORCE_SSL_REDIRECT=${READ_VALUE}
  read_bool "Keep cluster data in git" "${CLUSTER_DATA_IN_GIT}"
  CLUSTER_DATA_IN_GIT=${READ_VALUE}
  read_bool "Add pull secrets to namespaces" "${CLUSTER_PULL_SECRETS_IN_NS}"
  CLUSTER_PULL_SECRETS_IN_NS=${READ_VALUE}
  read_bool "Use basic auth" "${CLUSTER_USE_BASIC_AUTH}"
  CLUSTER_USE_BASIC_AUTH=${READ_VALUE}
  read_bool "Use SOPS" "${CLUSTER_USE_SOPS}"
  CLUSTER_USE_SOPS=${READ_VALUE}
  if is_selected "$CLUSTER_USE_SOPS"; then
    export SOPS_EXT="${APP_DEFAULT_SOPS_EXT}"
  else
    export SOPS_EXT=""
  fi
}

ctool_eks_print_variables() {
  cat <<EOF
# KITT EKS Cluster Configuration File
# ---
# Cluster name
NAME=$CLUSTER_NAME
# Cluster kind (one of eks, ext or k3d for now)
KIND=$CLUSTER_KIND
# Public DNS domain used with the cluster ingress by default
DOMAIN=$CLUSTER_DOMAIN
# Version of EKS to use (the default is usually one or two versions behind k8s)
EKS_VERSION=$CLUSTER_EKS_VERSION
# AWS Region to use for the EKS deployment
REGION=$CLUSTER_REGION
# AWS Availability Zones to use for the EKS deployment
AVAILABILITY_ZONES=$CLUSTER_AVAILABILITY_ZONES
# Name of the EKS node group
EKS_NODEGROUP=$CLUSTER_EKS_NODEGROUP
# EKS node group Availability Zone
EKS_NODEGROUP_AZ=$CLUSTER_EKS_NODEGROUP_AZ
# EKS Instance Type
EKS_INSTANCE_TYPE=$CLUSTER_EKS_INSTANCE_TYPE
# EKS Nodes Volume Size
EKS_VOLUME_SIZE=$CLUSTER_EKS_VOLUME_SIZE
# Minimum Number of ECS nodes to launch as workers
MIN_WORKERS=$CLUSTER_MIN_WORKERS
# Maximum Number of ECS nodes to launch as workers
MAX_WORKERS=$CLUSTER_MAX_WORKERS
# Number of ECS nodes to launch as workers
NUM_WORKERS=$CLUSTER_NUM_WORKERS
# EFS filesystem to use for dynamic volumes
EFS_FILESYSTEMID=$CLUSTER_EFS_FILESYSTEMID
# Number of ingress replicas
INGRESS_REPLICAS=$CLUSTER_INGRESS_REPLICAS
# Force SSL redirect on ingress
FORCE_SSL_REDIRECT=$CLUSTER_FORCE_SSL_REDIRECT
# Keep cluster data in git or not
CLUSTER_DATA_IN_GIT=$CLUSTER_DATA_IN_GIT
# Enable to add credentials to namespaces to pull images from a private registry
PULL_SECRETS_IN_NS=$CLUSTER_PULL_SECRETS_IN_NS
# Enable basic auth for sensible services (disable only on dev deployments)
USE_BASIC_AUTH=$CLUSTER_USE_BASIC_AUTH
# Use sops to encrypt files (needs a ~/.sops.yaml file to be useful)
USE_SOPS=$CLUSTER_USE_SOPS
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
      -e "s%__CLUSTER_EKS_NODEGROUP__%$CLUSTER_EKS_NODEGROUP%g" \
      -e "s%__CLUSTER_EKS_NODEGROUP_AZ__%$CLUSTER_EKS_NODEGROUP_AZ%g" \
      -e "s%__CLUSTER_EKS_INSTANCE_TYPE__%$CLUSTER_EKS_INSTANCE_TYPE%g" \
      -e "s%__CLUSTER_EKS_VOLUME_SIZE__%$CLUSTER_EKS_VOLUME_SIZE%g" \
      -e "s%__CLUSTER_NUM_WORKERS__%$CLUSTER_NUM_WORKERS%g" \
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
    --name="$CLUSTER_EKS_NODEGROUP" --nodes-min="$CLUSTER_MIN_WORKERS" \
    --nodes-max="$CLUSTER_MAX_WORKERS" --nodes="$CLUSTER_NUM_WORKERS"
}

ctool_eks_status() {
  _cluster="$1"
  eks_get_cluster_status "$_cluster"
}

ctool_eks_zone_sc_add() {
  _cluster="$1"
  ctool_eks_export_variables "$_cluster"
  _storageclass_tmpl="$AWS_EBS_STORAGECLASS_TMPL"
  _storageclass_yaml="$AWS_EBS_STORAGECLASS_YAML"
  : >"$_storageclass_yaml"
  for _zone in $(echo "$CLUSTER_AVAILABILITY_ZONES" | sed -e 's/,/ /g'); do
    _storageclass_name="$CLUSTER_AWS_EBS_TYPE-$_zone"
    sed \
      -e "s%__STORAGECLASS_NAME__%$_storageclass_name%" \
      -e "s%__FS_TYPE__%$CLUSTER_AWS_EBS_FS_TYPE%" \
      -e "s%__EBS_TYPE__%$CLUSTER_AWS_EBS_TYPE%" \
      -e "s%__ZONE__%$_zone%" \
      "$_storageclass_tmpl" >>"$_storageclass_yaml"
    echo "---" >>"$_storageclass_yaml"
  done
  kubectl_apply "$_storageclass_yaml"
}

ctool_eks_zone_sc_del() {
  _cluster="$1"
  ctool_eks_export_variables "$_cluster"
  _storageclass_yaml="$AWS_EBS_STORAGECLASS_YAML"
  kubectl_delete "$_storageclass_yaml"
}

ctool_eks_command() {
  _command="$1"
  _cluster="$2"
  case "$_command" in
    install) ctool_eks_install "$_cluster" ;;
    remove) ctool_eks_remove "$_cluster" ;;
    scale) ctool_eks_scale "$_cluster" ;;
    status) ctool_eks_status "$_cluster" ;;
    zone-sc-add) ctool_eks_zone_sc_add "$_cluster" ;;
    zone-sc-del) ctool_eks_zone_sc_del "$_cluster" ;;
    *) echo "Unknown eks subcommand '$_command'"; exit 1 ;;
  esac
}

ctool_eks_command_list() {
  echo "install remove scale status zone-sc-add zone-sc-del"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=3
