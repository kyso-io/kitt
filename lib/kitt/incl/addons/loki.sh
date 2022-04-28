#!/bin/sh
# ----
# File:        addons/loki.sh
# Description: Functions to install and remove loki from a cluster
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_ADDONS_LOKI_SH="1"

# ---------
# Variables
# ---------

# CMND_DSC="loki: manage the cluster loki deployment (monitoring)"

# Fixed values
export LOKI_NAMESPACE="monitoring"
export LOKI_HELM_REPO_NAME="grafana"
export LOKI_HELM_REPO_URL="https://grafana.github.io/helm-charts"
export LOKI_HELM_CHART="$LOKI_HELM_REPO_NAME/loki"
export LOKI_HELM_RELEASE="loki"

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

addon_loki_export_variables() {
  [ -z "$_addon_loki_export_variables" ] || return 0
  # Directories
  export LOKI_TMPL_DIR="$TMPL_DIR/addons/loki"
  export LOKI_HELM_DIR="$CLUST_HELM_DIR/loki"
  # Templates
  export LOKI_HELM_VALUES_TMPL="$LOKI_TMPL_DIR/values.yaml"
  # Files
  export LOKI_HELM_VALUES_YAML="$LOKI_HELM_DIR/values.yaml"
  # Set variable to avoid loading variables twice
  _addon_loki_export_variables="1"
}

addon_loki_check_directories() {
  for _d in $LOKI_HELM_DIR; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

addon_loki_clean_directories() {
  # Try to remove empty dirs, except if they contain secrets
  for _d in $LOKI_HELM_DIR; do
    if [ -d "$_d" ]; then
      rmdir "$_d" 2>/dev/null || true
    fi
  done
}

addon_loki_install() {
  addon_loki_export_variables
  addon_loki_check_directories
  _addon="loki"
  _ns="$LOKI_NAMESPACE"
  _repo_name="$LOKI_HELM_REPO_NAME"
  _repo_url="$LOKI_HELM_REPO_URL"
  _values_tmpl="$LOKI_HELM_VALUES_TMPL"
  _values_yaml="$LOKI_HELM_VALUES_YAML"
  _release="$LOKI_HELM_RELEASE"
  _chart="$LOKI_HELM_CHART"
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
  helm_upgrade "$_ns" "$_values_yaml" "$_release" "$_chart"
  footer
}

addon_loki_remove() {
  addon_loki_export_variables
  _addon="loki"
  _ns="$LOKI_NAMESPACE"
  _values_yaml="$LOKI_HELM_VALUES_YAML"
  _release="$LOKI_HELM_RELEASE"
  if find_namespace "$_ns"; then
    header "Removing '$_addon' objects"
    # Uninstall chart
    if [ -f "$_values_yaml" ]; then
      helm uninstall -n "$_ns" "$_release" || true
      rm -f "$_values_yaml"
    fi
    # Delete namespace if there are no charts deployed
    if [ -z "$(helm list -n "$_ns" -q)" ]; then
      delete_namespace "$_ns"
    fi
    footer
  else
    echo "Namespace '$_ns' for '$_addon' not found!"
  fi
  addon_loki_clean_directories
}

addon_loki_status() {
  addon_loki_export_variables
  _addon="loki"
  _ns="$LOKI_NAMESPACE"
  _release="$LOKI_HELM_RELEASE"
  if find_namespace "$_ns"; then
    kubectl get all,endpoints,ingress,secrets -n "$_ns" \
      -l "release=$_release"
  else
    echo "Namespace '$_ns' for '$_addon' not found!"
  fi
}

addon_loki_summary() {
  addon_loki_export_variables
  _addon="loki"
  _ns="$LOKI_NAMESPACE"
  _release="$LOKI_HELM_RELEASE"
  print_helm_summary "$_ns" "$_addon" "$_release"
}

addon_loki_command() {
  case "$1" in
    install) addon_loki_install ;;
    remove) addon_loki_remove ;;
    status) addon_loki_status ;;
    summary) addon_loki_summary ;;
    *) echo "Unknown loki subcommand '$1'"; exit 1 ;;
  esac
}

addon_loki_command_list() {
  echo "install remove status summary"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
