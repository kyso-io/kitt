#!/bin/sh
# ----
# File:        addons/promtail.sh
# Description: Functions to install and remove promtail from a cluster
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022-2023 Kyso Inc.
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_ADDONS_PROMTAIL_SH="1"

# ---------
# Variables
# ---------

# CMND_DSC="promtail: manage the cluster promtail deployment (monitoring)"

# Fixed values
export PROMTAIL_NAMESPACE="monitoring"
export PROMTAIL_HELM_REPO_NAME="grafana"
export PROMTAIL_HELM_REPO_URL="https://grafana.github.io/helm-charts"
export PROMTAIL_HELM_CHART="$PROMTAIL_HELM_REPO_NAME/promtail"
export PROMTAIL_HELM_RELEASE="promtail"

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

addons_promtail_export_variables() {
  [ -z "$_addons_promtail_export_variables" ] || return 0
  # Directories
  export PROMTAIL_TMPL_DIR="$TMPL_DIR/addons/promtail"
  export PROMTAIL_HELM_DIR="$CLUST_HELM_DIR/promtail"
  # Templates
  export PROMTAIL_HELM_VALUES_TMPL="$PROMTAIL_TMPL_DIR/values.yaml"
  # Files
  export PROMTAIL_HELM_VALUES_YAML="$PROMTAIL_HELM_DIR/values.yaml"
  # Set variable to avoid loading variables twice
  _addons_promtail_export_variables="1"
}

addons_promtail_check_directories() {
  for _d in $PROMTAIL_HELM_DIR; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

addons_promtail_clean_directories() {
  # Try to remove empty dirs, except if they contain secrets
  for _d in $PROMTAIL_HELM_DIR; do
    if [ -d "$_d" ]; then
      rmdir "$_d" 2>/dev/null || true
    fi
  done
}

addons_promtail_install() {
  addons_promtail_export_variables
  addons_promtail_check_directories
  _addon="promtail"
  _ns="$PROMTAIL_NAMESPACE"
  _repo_name="$PROMTAIL_HELM_REPO_NAME"
  _repo_url="$PROMTAIL_HELM_REPO_URL"
  _values_tmpl="$PROMTAIL_HELM_VALUES_TMPL"
  _values_yaml="$PROMTAIL_HELM_VALUES_YAML"
  _release="$PROMTAIL_HELM_RELEASE"
  _chart="$PROMTAIL_HELM_CHART"
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

addons_promtail_remove() {
  addons_promtail_export_variables
  _addon="promtail"
  _ns="$PROMTAIL_NAMESPACE"
  _values_yaml="$PROMTAIL_HELM_VALUES_YAML"
  _release="$PROMTAIL_HELM_RELEASE"
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
  addons_promtail_clean_directories
}

addons_promtail_status() {
  addons_promtail_export_variables
  _addon="promtail"
  _ns="$PROMTAIL_NAMESPACE"
  if find_namespace "$_ns"; then
    kubectl get all,endpoints,ingress,secrets -n "$_ns" \
      -l "app.kubernetes.io/name=$_addon"
  else
    echo "Namespace '$_ns' for '$_addon' not found!"
  fi
}

addons_promtail_summary() {
  addons_promtail_export_variables
  _addon="promtail"
  _ns="$PROMTAIL_NAMESPACE"
  _release="$PROMTAIL_HELM_RELEASE"
  print_helm_summary "$_ns" "$_addon" "$_release"
}

addons_promtail_command() {
  case "$1" in
    install) addons_promtail_install ;;
    remove) addons_promtail_remove ;;
    status) addons_promtail_status ;;
    summary) addons_promtail_summary ;;
    *) echo "Unknown promtail subcommand '$1'"; exit 1 ;;
  esac
}

addons_promtail_command_list() {
  echo "install remove status summary"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
