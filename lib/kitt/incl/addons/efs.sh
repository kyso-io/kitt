#!/bin/sh
# ----
# File:        addons/efs.sh
# Description: Functions to install and remove the efs-csi-driver from a cluster
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022-2023 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_ADDONS_EFS_SH="1"

# ---------
# Variables
# ---------

# CMND_DSC="efs: install or remove the efs-csi-driver on a cluster (eks)"

# Fixed values
export EFS_NAMESPACE="kube-system"
export EFS_HELM_REPO_NAME="aws-efs-csi-driver"
export EFS_HELM_REPO_URL="https://kubernetes-sigs.github.io/aws-efs-csi-driver"
export EFS_HELM_CHART="$EFS_HELM_REPO_NAME/aws-efs-csi-driver"
export EFS_HELM_RELEASE="efs-csi-driver"

# --------
# Includes
# --------

if [ -d "$INCL_DIR" ]; then
  # shellcheck source=../common.sh
  [ "$INCL_COMMON_SH" = "1" ] || . "$INCL_DIR/common.sh"
  # shellcheck source=../ctools/eks.sh
  [ "$INCL_CTOOLS_EKS_SH" = "1" ] || . "$INCL_DIR/ctools/eks.sh"
fi

# ---------
# Functions
# ---------

addons_efs_export_variables() {
  [ -z "$__addons_efs_export_variables" ] || return 0
  # Load EKS variables
  ctool_eks_export_variables
  # Directories
  export EFS_TMPL_DIR="$TMPL_DIR/addons/efs"
  export EFS_HELM_DIR="$CLUST_HELM_DIR/efs"
  export EFS_KUBECTL_DIR="$CLUST_KUBECTL_DIR/efs"
  # Templates
  export EFS_HELM_VALUES_TMPL="$EFS_TMPL_DIR/values.yaml"
  # Files
  export EFS_HELM_VALUES_YAML="$EFS_HELM_DIR/values.yaml"
  # Set variable to avoid loading variables twice
  __addons_efs_export_variables="1"
}

addons_efs_check_directories() {
  for _d in "$EFS_HELM_DIR" "$EFS_KUBECTL_DIR"; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

addons_efs_clean_directories() {
  # Try to remove empty dirs, except if they contain secrets
  for _d in "$EFS_HELM_DIR" "$EFS_KUBECTL_DIR"; do
    if [ -d "$_d" ]; then
      rmdir "$_d" 2>/dev/null || true
    fi
  done
}

addons_efs_createfs() {
  addons_efs_export_variables
  _orig_efs_filesystemid="$CLUSTER_EFS_FILESYSTEMID"
  aws_add_eks_efs_filesystem "$CLUSTER_NAME" "$CLUSTER_REGION"
  if [ "$_orig_efs_filesystemid" = "$CLUSTER_EFS_FILESYSTEMID" ]; then
    echo "The filesystem '$CLUSTER_EFS_FILESYSTEMID' already exists!"
  else
    echo "The new filesystem id is '$CLUSTER_EFS_FILESYSTEMID'"
    if [ -f "$CLUSTER_CONFIG" ]; then
      read_bool "Save updated configuration?" "Yes"
    else
      READ_VALUE="Yes"
    fi
    if is_selected "${READ_VALUE}"; then
      ctool_eks_check_directories
      ctool_eks_print_variables | stdout_to_file "$CLUSTER_CONFIG"
    fi
  fi
}

addons_efs_install() {
  addons_efs_export_variables
  # Abort if there is no EKS_CLUSTER_EFS_FILESYSTEMID
  if [ -z "$CLUSTER_EFS_FILESYSTEMID" ]; then
    cat <<EOF
Can't setup the EFS dynamic provisioner without an EFS File system ID.

Create it with the 'createfs' subcommand and update the cluster configuration.
EOF
    exit 1
  fi
  addons_efs_check_directories
  _addon="efs"
  _ns="$EFS_NAMESPACE"
  _repo_name="$EFS_HELM_REPO_NAME"
  _repo_url="$EFS_HELM_REPO_URL"
  _release="$EFS_HELM_RELEASE"
  _chart="$EFS_HELM_CHART"
  _values_tmpl="$EFS_HELM_VALUES_TMPL"
  _values_yaml="$EFS_HELM_VALUES_YAML"
  header "Installing '$_addon'"
  # Check helm repo
  check_helm_repo "$_repo_name" "$_repo_url"
  # Create values.yaml
  sed \
    -e "s%__CLUSTER_NAME__%$CLUSTER_NAME%g" \
    -e "s%__EFS_FILESYSTEMID__%$CLUSTER_EFS_FILESYSTEMID%" \
    -e "s%__AWS_ACCOUNT_ID__%$_aws_account_id%g" \
    "$_values_tmpl" >"$_values_yaml"
  # Update or install chart
  helm_upgrade "$_ns" "$_values_yaml" "$_release" "$_chart"
  footer
}

addons_efs_remove() {
  addons_efs_export_variables
  _addon="efs"
  _ns="$EFS_NAMESPACE"
  _release="$EFS_HELM_RELEASE"
  _values_yaml="$EFS_HELM_VALUES_YAML"
  helm uninstall -n "$_ns" "$_release" || true
  if [ -f "$_values_yaml" ]; then
    rm -f "$_values_yaml"
  fi
  addons_efs_clean_directories
}

addons_efs_status() {
  addons_efs_export_variables
  _addon="efs"
  _ns="$EFS_NAMESPACE"
  if find_namespace "$_ns"; then
    kubectl get pod -n "$_ns" -l "app.kubernetes.io/name=aws-efs-csi-driver"
  else
    echo "Namespace '$_ns' for '$_addon' not found!"
  fi
}

addons_efs_summary() {
  addons_efs_export_variables
  _addon="efs"
  _ns="$EFS_NAMESPACE"
  _release="$EFS_HELM_RELEASE"
  print_helm_summary "$_ns" "$_addon" "$_release"
}

addons_efs_command() {
  case "$1" in
    createfs) addons_efs_createfs ;;
    install) addons_efs_install ;;
    remove) addons_efs_remove ;;
    status) addons_efs_status ;;
    summary) addons_efs_summary ;;
    *) echo "Unknown efs subcommand '$1'"; exit 1 ;;
  esac
}

addons_efs_command_list() {
  echo "createfs install remove status summary"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
