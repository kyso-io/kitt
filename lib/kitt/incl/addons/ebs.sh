#!/bin/sh
# ----
# File:        addons/ebs.sh
# Description: Functions to install and remove the ebs-csi-driver from a cluster
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022-2023 Kyso Inc.
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

addons_ebs_export_variables() {
  [ -z "$__addons_ebs_export_variables" ] || return 0
  # Load EKS variables
  ctool_eks_export_variables
  # Directories
  export EBS_TMPL_DIR="$TMPL_DIR/addons/ebs"
  export EBS_HELM_DIR="$CLUST_HELM_DIR/ebs"
  export EBS_KUBECTL_DIR="$CLUST_KUBECTL_DIR/ebs"
  # Templates
  export EBS_HELM_VALUES_TMPL="$EBS_TMPL_DIR/values.yaml"
  # Files
  export EBS_HELM_VALUES_YAML="$EBS_HELM_DIR/values.yaml"
  # Set variable to avoid loading variables twice
  __addons_ebs_export_variables="1"
}

addons_ebs_check_directories() {
  for _d in "$EBS_HELM_DIR" "$EBS_KUBECTL_DIR"; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

addons_ebs_clean_directories() {
  # Try to remove empty dirs, except if they contain secrets
  for _d in "$EBS_HELM_DIR" "$EBS_KUBECTL_DIR"; do
    if [ -d "$_d" ]; then
      rmdir "$_d" 2>/dev/null || true
    fi
  done
}

addons_ebs_install() {
  addons_ebs_export_variables
  addons_ebs_check_directories
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
  # Get the AWS account id
  _aws_account_id="$(aws_get_account_id)"
  # Generate values.yaml
  sed \
    -e "s%__CLUSTER_NAME__%$CLUSTER_NAME%g" \
    -e "s%__AWS_ACCOUNT_ID__%$_aws_account_id%g" \
    "$_values_tmpl" >"$_values_yaml"
  # Update or install chart
  helm_upgrade "$_ns" "$_values_yaml" "$_release" "$_chart"
  # Unset default storage class for gp2
  _annotation='"storageclass.kubernetes.io/is-default-class":"false"'
  _metadata="{\"metadata\": {\"annotations\":{$_annotation}}}"
  kubectl patch storageclass gp2 -p "$_metadata" || true
  footer
}

addons_ebs_remove() {
  addons_ebs_export_variables
  _addon="ebs"
  _ns="$EBS_NAMESPACE"
  _release="$EBS_HELM_RELEASE"
  _values_yaml="$EBS_HELM_VALUES_YAML"
  helm uninstall -n "$_ns" "$_release" || true
  if [ -f "$_values_yaml" ]; then
    rm -f "$_values_yaml"
  fi
  # Make gp2 the default storage class again
  _annotation='"storageclass.kubernetes.io/is-default-class":"true"'
  _metadata="{\"metadata\": {\"annotations\":{$_annotation}}}"
  kubectl patch storageclass gp2 -p "$_metadata" || true
  addons_ebs_clean_directories
}

addons_ebs_status() {
  addons_ebs_export_variables
  _addon="ebs"
  _ns="$EBS_NAMESPACE"
  if find_namespace "$_ns"; then
    kubectl get pod -n "$_ns" -l "app.kubernetes.io/name=aws-ebs-csi-driver"
  else
    echo "Namespace '$_ns' for '$_addon' not found!"
  fi
}

addons_ebs_summary() {
  addons_ebs_export_variables
  _addon="ebs"
  _ns="$EBS_NAMESPACE"
  _release="$EBS_HELM_RELEASE"
  print_helm_summary "$_ns" "$_addon" "$_release"
}

addons_ebs_command() {
  case "$1" in
    install) addons_ebs_install ;;
    remove) addons_ebs_remove ;;
    status) addons_ebs_status ;;
    summary) addons_ebs_summary ;;
    *) echo "Unknown ebs subcommand '$1'"; exit 1 ;;
  esac
}

addons_ebs_command_list() {
  echo "install remove status summary"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
