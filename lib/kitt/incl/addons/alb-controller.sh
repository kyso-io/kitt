#!/bin/sh
# ----
# File:        addons/alb-controller.sh
# Description: Functions to install and remove the alb-controller from a cluster
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022-2023 Kyso Inc.
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_ADDONS_ALB_CONTROLLER_SH="1"

# ---------
# Variables
# ---------

# CMND_DSC="alb-controller: manage the cluster alb-controller deployment (eks)"

# Fixed values
export ALB_CONTROLLER_NAMESPACE="kube-system"
export ALB_CONTROLLER_HELM_REPO_NAME="eks"
ALB_CONTROLLER_HELM_REPO_URL="https://aws.github.io/eks-charts"
export ALB_CONTROLLER_HELM_REPO_URL
export ALB_CONTROLLER_HELM_CHART="$ALB_CONTROLLER_HELM_REPO_NAME/aws-load-balancer-controller"
export ALB_CONTROLLER_HELM_RELEASE="alb-controller"
export ALB_REPLICA_COUNT="1"

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

addons_alb_controller_export_variables() {
  [ -z "$__addons_alb_controller_export_variables" ] || return 0
  # Directories
  export ALB_CONTROLLER_TMPL_DIR="$TMPL_DIR/addons/alb-controller"
  export ALB_CONTROLLER_HELM_DIR="$CLUST_HELM_DIR/alb-controller"
  # Templates
  export ALB_CONTROLLER_HELM_VALUES_TMPL="$ALB_CONTROLLER_TMPL_DIR/values.yaml"
  # Files
  export ALB_CONTROLLER_HELM_VALUES_YAML="$ALB_CONTROLLER_HELM_DIR/values.yaml"
  # Set variable to avoid loading variables twice
  __addons_alb_controller_export_variables="1"
}

addons_alb_controller_check_directories() {
  for _d in $ALB_CONTROLLER_HELM_DIR; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

addons_alb_controller_clean_directories() {
  # Try to remove empty dirs, except if they contain secrets
  for _d in $ALB_CONTROLLER_HELM_DIR; do
    if [ -d "$_d" ]; then
      rmdir "$_d" 2>/dev/null || true
    fi
  done
}

addons_alb_controller_install() {
  addons_alb_controller_export_variables
  addons_alb_controller_check_directories
  _addon="alb-controller"
  _ns="$ALB_CONTROLLER_NAMESPACE"
  _repo_name="$ALB_CONTROLLER_HELM_REPO_NAME"
  _repo_url="$ALB_CONTROLLER_HELM_REPO_URL"
  _values_tmpl="$ALB_CONTROLLER_HELM_VALUES_TMPL"
  _values_yaml="$ALB_CONTROLLER_HELM_VALUES_YAML"
  _release="$ALB_CONTROLLER_HELM_RELEASE"
  _chart="$ALB_CONTROLLER_HELM_CHART"
  header "Installing '$_addon'"
  # Check helm repo
  check_helm_repo "$_repo_name" "$_repo_url"
  # Create namespace if needed
  if ! find_namespace "$_ns"; then
    create_namespace "$_ns"
  fi
  # Get the AWS account id
  _aws_account_id="$(aws_get_account_id)"
  # Replace values for the chart
  sed \
    -e "s%__CLUSTER_NAME__%$CLUSTER_NAME%" \
    -e "s%__AWS_ACCOUNT_ID__%$_aws_account_id%g" \
    -e "s%__REPLICA_COUNT__%$ALB_REPLICA_COUNT%" \
    "$_values_tmpl" >"$_values_yaml"
  # Update or install chart
  helm_upgrade "$_ns" "$_values_yaml" "$_release" "$_chart" "" "$_release"
  footer
}

addons_alb_controller_remove() {
  addons_alb_controller_export_variables
  _addon="alb-controller"
  _ns="$ALB_CONTROLLER_NAMESPACE"
  _values_yaml="$ALB_CONTROLLER_HELM_VALUES_YAML"
  _release="$ALB_CONTROLLER_HELM_RELEASE"
  if find_namespace "$_ns"; then
    header "Removing '$_addon' objects"
    # Uninstall chart
    if [ -f "$_values_yaml" ]; then
      helm uninstall -n "$_ns" "$_release" || true
      rm -f "$_values_yaml"
    fi
    footer
  else
    echo "Namespace '$_ns' for '$_addon' not found!"
  fi
  addons_alb_controller_clean_directories
}

addons_alb_controller_logs() {
  addons_alb_controller_export_variables
  _addon="alb-controller"
  _ns="$ALB_CONTROLLER_NAMESPACE"
  _release="$ALB_CONTROLLER_HELM_RELEASE"
  if find_namespace "$_ns"; then
    kubectl logs -n "$_ns" -l "app.kubernetes.io/name=aws-load-balancer-controller"
  else
    echo "Namespace '$_ns' for '$_addon' not found!"
  fi
}
addons_alb_controller_status() {
  addons_alb_controller_export_variables
  _addon="alb-controller"
  _ns="$ALB_CONTROLLER_NAMESPACE"
  _release="$ALB_CONTROLLER_HELM_RELEASE"
  if find_namespace "$_ns"; then
    kubectl get all -n "$_ns" -l "app.kubernetes.io/name=aws-load-balancer-controller"
  else
    echo "Namespace '$_ns' for '$_addon' not found!"
  fi
}

addons_alb_controller_summary() {
  addons_alb_controller_export_variables
  _addon="alb-controller"
  _ns="$ALB_CONTROLLER_NAMESPACE"
  _release="$ALB_CONTROLLER_HELM_RELEASE"
  print_helm_summary "$_ns" "$_addon" "$_release"
}

addons_alb_controller_command() {
  case "$1" in
    install) addons_alb_controller_install ;;
    remove) addons_alb_controller_remove ;;
    logs) addons_alb_controller_logs ;;
    status) addons_alb_controller_status ;;
    summary) addons_alb_controller_summary ;;
    *) echo "Unknown alb-controller subcommand '$1'"; exit 1 ;;
  esac
}

addons_alb_controller_command_list() {
  echo "install remove logs status summary"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
