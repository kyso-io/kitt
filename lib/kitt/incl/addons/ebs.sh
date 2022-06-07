#!/bin/sh
# ----
# File:        addons/ebs.sh
# Description: Functions to install and remove the ebs-csi-driver from a cluster
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_ADDONS_EBS_SH="1"

# ---------
# Variables
# ---------

# CMND_DSC="ebs: install or remove the ebs-csi-driver on a cluster (eks)"

# Fixed values
export EBS_NAMESPACE="kube-system"
export EBS_HELM_REPO_NAME="aws-ebs-csi-driver"
export EBS_HELM_REPO_URL="https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
export EBS_HELM_CHART="$EBS_HELM_REPO_NAME/aws-ebs-csi-driver"
export EBS_HELM_RELEASE="ebs-csi-driver"

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

addon_ebs_export_variables() {
  [ -z "$__addon_ebs_export_variables" ] || return 0
  # Load EKS variables
  ctool_eks_export_variables
  # Directories
  export EBS_TMPL_DIR="$TMPL_DIR/addons/ebs"
  export EBS_HELM_DIR="$CLUST_HELM_DIR/ebs"
  export EBS_KUBECTL_DIR="$CLUST_KUBECTL_DIR/ebs"
  # Templates
  export EBS_EKS_EBS_POLICY_TMPL="$EBS_TMPL_DIR/iam-policy-example.json"
  export EBS_HELM_VALUES_TMPL="$EBS_TMPL_DIR/values.yaml"
  export EBS_STORAGECLASS_TMPL="$EBS_TMPL_DIR/storageclass.yaml"
  # Files
  export EBS_HELM_VALUES_YAML="$EBS_HELM_DIR/values.yaml"
  export EBS_STORAGECLASS_YAML="$EBS_KUBECTL_DIR/storageclass.yaml"
  # Set variable to avoid loading variables twice
  __addon_ebs_export_variables="1"
}

addon_ebs_check_directories() {
  for _d in "$EBS_HELM_DIR" "$EBS_KUBECTL_DIR"; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

addon_ebs_clean_directories() {
  # Try to remove empty dirs, except if they contain secrets
  for _d in "$EBS_HELM_DIR" "$EBS_KUBECTL_DIR"; do
    if [ -d "$_d" ]; then
      rmdir "$_d" 2>/dev/null || true
    fi
  done
}

addon_ebs_install() {
  addon_ebs_export_variables
  addon_ebs_check_directories
  _addon="ebs"
  _ns="$EBS_NAMESPACE"
  _repo_name="$EBS_HELM_REPO_NAME"
  _repo_url="$EBS_HELM_REPO_URL"
  _release="$EBS_HELM_RELEASE"
  _chart="$EBS_HELM_CHART"
  _values_tmpl="$EBS_HELM_VALUES_TMPL"
  _values_yaml="$EBS_HELM_VALUES_YAML"
  header "Installing '$_addon'"
  # Check helm repo
  check_helm_repo "$_repo_name" "$_repo_url"
  # Add EKS_EFS Policy
  aws_add_eks_ebs_policy "$EBS_EKS_EBS_POLICY_TMPL"
  # Add role and attach it to the previous Policy
  aws_add_eks_ebs_service_account "$CLUSTER_NAME"
  # Copy values tmpl to values.yaml
  cp "$_values_tmpl" "$_values_yaml"
  # Update or install chart
  helm_upgrade "$_ns" "$_values_yaml" "$_release" "$_chart"
  # Add storageclass
  cp "$EBS_STORAGECLASS_TMPL" "$EBS_STORAGECLASS_YAML"
  kubectl_apply "$EBS_STORAGECLASS_YAML"
  footer
}

addon_ebs_remove() {
  addon_ebs_export_variables
  _addon="ebs"
  _ns="$EBS_NAMESPACE"
  _release="$EBS_HELM_RELEASE"
  _values_yaml="$EBS_HELM_VALUES_YAML"
  helm uninstall -n "$_ns" "$_release" || true
  if [ -f "$_values_yaml" ]; then
    rm -f "$_values_yaml"
  fi
  kubectl_delete "$EBS_STORAGECLASS_YAML" || true
  addon_ebs_clean_directories
}

addon_ebs_status() {
  addon_ebs_export_variables
  _addon="ebs"
  _ns="$EBS_NAMESPACE"
  if find_namespace "$_ns"; then
    kubectl get pod -n "$_ns" -l "app.kubernetes.io/name=aws-ebs-csi-driver"
  else
    echo "Namespace '$_ns' for '$_addon' not found!"
  fi
}

addon_ebs_summary() {
  addon_ebs_export_variables
  _addon="ebs"
  _ns="$EBS_NAMESPACE"
  _release="$EBS_HELM_RELEASE"
  print_helm_summary "$_ns" "$_addon" "$_release"
}

addon_ebs_command() {
  case "$1" in
    install) addon_ebs_install ;;
    remove) addon_ebs_remove ;;
    status) addon_ebs_status ;;
    summary) addon_ebs_summary ;;
    *) echo "Unknown ebs subcommand '$1'"; exit 1 ;;
  esac
}

addon_ebs_command_list() {
  echo "install remove status summary"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
