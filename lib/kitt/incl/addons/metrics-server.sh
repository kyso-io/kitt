#!/bin/sh
# ----
# File:        addons/metrics-server.sh
# Description: Functions to install and remove the metrics-server from a cluster
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022-2023 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_ADDONS_METRICS_SERVER_SH="1"

# ---------
# Variables
# ---------

# CMND_DSC="metrics-server: manage the cluster metrics-server deployment (eks)"

# Fixed values
export METRICS_SERVER_NAMESPACE="kube-system"
export METRICS_SERVER_HELM_REPO_NAME="metrics-server"
METRICS_SERVER_HELM_REPO_URL="https://kubernetes-sigs.github.io/metrics-server"
export METRICS_SERVER_HELM_REPO_URL
export METRICS_SERVER_HELM_CHART="$METRICS_SERVER_HELM_REPO_NAME/metrics-server"
export METRICS_SERVER_HELM_RELEASE="metrics-server"

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

addons_metrics_server_export_variables() {
  [ -z "$__addons_metrics_server_export_variables" ] || return 0
  # Directories
  export METRICS_SERVER_TMPL_DIR="$TMPL_DIR/addons/metrics-server"
  export METRICS_SERVER_HELM_DIR="$CLUST_HELM_DIR/metrics-server"
  # Templates
  export METRICS_SERVER_HELM_VALUES_TMPL="$METRICS_SERVER_TMPL_DIR/values.yaml"
  # Files
  export METRICS_SERVER_HELM_VALUES_YAML="$METRICS_SERVER_HELM_DIR/values.yaml"
  # Set variable to avoid loading variables twice
  __addons_metrics_server_export_variables="1"
}

addons_metrics_server_check_directories() {
  for _d in $METRICS_SERVER_HELM_DIR; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

addons_metrics_server_clean_directories() {
  # Try to remove empty dirs, except if they contain secrets
  for _d in $METRICS_SERVER_HELM_DIR; do
    if [ -d "$_d" ]; then
      rmdir "$_d" 2>/dev/null || true
    fi
  done
}

addons_metrics_server_install() {
  addons_metrics_server_export_variables
  addons_metrics_server_check_directories
  _addon="metrics-server"
  _ns="$METRICS_SERVER_NAMESPACE"
  _repo_name="$METRICS_SERVER_HELM_REPO_NAME"
  _repo_url="$METRICS_SERVER_HELM_REPO_URL"
  _values_tmpl="$METRICS_SERVER_HELM_VALUES_TMPL"
  _values_yaml="$METRICS_SERVER_HELM_VALUES_YAML"
  _release="$METRICS_SERVER_HELM_RELEASE"
  _chart="$METRICS_SERVER_HELM_CHART"
  header "Installing '$_addon'"
  # Check helm repo
  check_helm_repo "$_repo_name" "$_repo_url"
  # Create namespace if needed
  if ! find_namespace "$_ns"; then
    create_namespace "$_ns"
  fi
  # Values for the chart
  cp "$_values_tmpl" "$_values_yaml"
  # Update or install chart
  helm_upgrade "$_ns" "$_values_yaml" "$_release" "$_chart" "" "$_release"
  footer
}

addons_metrics_server_remove() {
  addons_metrics_server_export_variables
  _addon="metrics-server"
  _ns="$METRICS_SERVER_NAMESPACE"
  _values_yaml="$METRICS_SERVER_HELM_VALUES_YAML"
  _release="$METRICS_SERVER_HELM_RELEASE"
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
  addons_metrics_server_clean_directories
}

addons_metrics_server_status() {
  addons_metrics_server_export_variables
  _addon="metrics-server"
  _ns="$METRICS_SERVER_NAMESPACE"
  _release="$METRICS_SERVER_HELM_RELEASE"
  if find_namespace "$_ns"; then
    kubectl get all,endpoints,ingress,secrets -n "$_ns" \
      -l "release=$_release"
  else
    echo "Namespace '$_ns' for '$_addon' not found!"
  fi
}

addons_metrics_server_summary() {
  addons_metrics_server_export_variables
  _addon="metrics-server"
  _ns="$METRICS_SERVER_NAMESPACE"
  _release="$METRICS_SERVER_HELM_RELEASE"
  print_helm_summary "$_ns" "$_addon" "$_release"
}

addons_metrics_server_command() {
  case "$1" in
    install) addons_metrics_server_install ;;
    remove) addons_metrics_server_remove ;;
    status) addons_metrics_server_status ;;
    summary) addons_metrics_server_summary ;;
    *) echo "Unknown metrics-server subcommand '$1'"; exit 1 ;;
  esac
}

addons_metrics_server_command_list() {
  echo "install remove status summary"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
