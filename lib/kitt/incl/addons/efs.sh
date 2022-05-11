#!/bin/sh
# ----
# File:        addons/efs.sh
# Description: Functions to install and remove the efs-csi-driver from a cluster
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022 Sergio Talens-Oliag <sto@kyso.io>
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

addon_efs_export_variables() {
  [ -z "$__addon_efs_export_variables" ] || return 0
  # Load EKS variables
  ctool_eks_export_variables
  # Directories
  export EFS_TMPL_DIR="$TMPL_DIR/addons/efs"
  export EFS_HELM_DIR="$CLUST_HELM_DIR/efs"
  export EFS_KUBECTL_DIR="$CLUST_KUBECTL_DIR/efs"
  # Templates
  export EFS_EKS_EFS_POLICY_TMPL="$EFS_TMPL_DIR/iam-policy-example.json"
  export EFS_HELM_VALUES_TMPL="$EFS_TMPL_DIR/values.yaml"
  export EFS_STORAGECLASS_TMPL="$EFS_TMPL_DIR/storageclass.yaml"
  # Files
  export EFS_HELM_VALUES_YAML="$EFS_HELM_DIR/values.yaml"
  export EFS_STORAGECLASS_YAML="$EFS_KUBECTL_DIR/storageclass.yaml"
  # Set variable to avoid loading variables twice
  __addon_efs_export_variables="1"
}

addon_efs_check_directories() {
  for _d in "$EFS_HELM_DIR" "$EFS_KUBECTL_DIR"; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

addon_efs_clean_directories() {
  # Try to remove empty dirs, except if they contain secrets
  for _d in "$EFS_HELM_DIR" "$EFS_KUBECTL_DIR"; do
    if [ -d "$_d" ]; then
      rmdir "$_d" 2>/dev/null || true
    fi
  done
}

# TODO: Add function to create EFS programatically
# create_efs() {
#   # Load EKS variables
#   ctool_eks_export_variables
#   if [ "$EKS_CLUSTER_EFS_FILESYSTEMID" ]; then
#     echo "There is already a filesystem on the configuration"
#     exit 1
#   fi
#   vpcid="$(eks_cluster_get_vpcid)"
#   if [ "$vpcid" ]; then
#      aws efs create-file-system \
#        --creation-token KysoEFS \
#        --backup \
#        --encrypted \
#        --performance-mode generalPurpose \
#        --throughput-mode bursting \
#        --region "$EKS_CLUSTER_REGION"
#   fi
# }

addon_efs_install() {
  addon_efs_export_variables
  # Abort if there is no EKS_CLUSTER_EFS_FILESYSTEMID
  if [ -z "$CLUSTER_EFS_FILESYSTEMID" ]; then
    cat <<EOF
Can't setup the EFS dynamic provisioner without an EFS File system ID.

Create the EFS from https://console.aws.amazon.com/efs/ on the EKS VPC (for
Kyso go to https://eu-north-1.console.aws.amazon.com/efs?region=eu-north-1#),
get the File system ID and reconfigure EKS on the cluster '$CLUSTER_NAME' to
use it.
EOF
    exit 1
  fi
  addon_efs_check_directories
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
  # Add EKS_EFS Policy
  aws_add_eks_efs_policy "$EFS_EKS_EFS_POLICY_TMPL"
  # Add role and attach it to the previous Policy
  aws_add_eks_efs_service_account "$CLUSTER_NAME"
  # Copy values tmpl to values.yaml
  sed \
    -e "s%__REGION__%$DEFAULT_EKS_EFS_REGION%" \
    "$_values_tmpl" >"$_values_yaml"
  # Update or install chart
  helm_upgrade "$_ns" "$_values_yaml" "$_release" "$_chart"
  # Add storageclass
  sed \
    -e "s%__EFS_FILESYSTEMID__%$CLUSTER_EFS_FILESYSTEMID%" \
    "$EFS_STORAGECLASS_TMPL" >"$EFS_STORAGECLASS_YAML"
  kubectl_apply "$EFS_STORAGECLASS_YAML"
  footer
}

addon_efs_remove() {
  addon_efs_export_variables
  _addon="efs"
  _ns="$EFS_NAMESPACE"
  _release="$EFS_HELM_RELEASE"
  _values_yaml="$EFS_HELM_VALUES_YAML"
  helm uninstall -n "$_ns" "$_release" || true
  if [ -f "$_values_yaml" ]; then
    rm -f "$_values_yaml"
  fi
  kubectl_delete "$EFS_STORAGECLASS_YAML" || true
  addon_efs_clean_directories
}

addon_efs_status() {
  addon_efs_export_variables
  _addon="efs"
  _ns="$EFS_NAMESPACE"
  if find_namespace "$_ns"; then
    kubectl get pod -n "$_ns" -l "app.kubernetes.io/name=aws-efs-csi-driver"
  else
    echo "Namespace '$_ns' for '$_addon' not found!"
  fi
}

addon_efs_summary() {
  addon_efs_export_variables
  _addon="efs"
  _ns="$EFS_NAMESPACE"
  _release="$EFS_HELM_RELEASE"
  print_helm_summary "$_ns" "$_addon" "$_release"
}

addon_efs_command() {
  case "$1" in
    install) addon_efs_install ;;
    remove) addon_efs_remove ;;
    status) addon_efs_status ;;
    summary) addon_efs_summary ;;
    *) echo "Unknown efs subcommand '$1'"; exit 1 ;;
  esac
}

addon_efs_command_list() {
  echo "install remove status summary"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
