#!/bin/sh
# ----
# File:        addons/vpa.sh
# Description: Functions to install and remove vpa for goldilocks from a cluster
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022-2023 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_ADDONS_VPA_SH="1"

# ---------
# Variables
# ---------

# CMND_DSC="vpa: manage the cluster vpa deployment"

# Fixed values
export VPA_NAMESPACE="vpa"
export VPA_HELM_REPO_NAME="fairwinds-stable"
export VPA_HELM_REPO_URL="https://charts.fairwinds.com/stable"
export VPA_HELM_CHART="$VPA_HELM_REPO_NAME/vpa"
export VPA_HELM_RELEASE="vpa"

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

addons_vpa_export_variables() {
  [ -z "$__addons_vpa_export_variables" ] || return 0
  # Directories
  export VPA_TMPL_DIR="$TMPL_DIR/addons/vpa"
  export VPA_HELM_DIR="$CLUST_HELM_DIR/vpa"
  # Templates
  export VPA_HELM_VALUES_TMPL="$VPA_TMPL_DIR/values.yaml"
  # Files
  export VPA_HELM_VALUES_YAML="$VPA_HELM_DIR/values.yaml"
  # Set variable to avoid loading variables twice
  __addons_vpa_export_variables="1"
}

addons_vpa_check_directories() {
  for _d in $VPA_HELM_DIR; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

addons_vpa_clean_directories() {
  # Try to remove empty dirs, except if they contain secrets
  for _d in $VPA_HELM_DIR; do
    if [ -d "$_d" ]; then
      rmdir "$_d" 2>/dev/null || true
    fi
  done
}

addons_vpa_install() {
  addons_vpa_export_variables
  addons_vpa_check_directories
  _addon="vpa"
  _ns="$VPA_NAMESPACE"
  _repo_name="$VPA_HELM_REPO_NAME"
  _repo_url="$VPA_HELM_REPO_URL"
  _values_tmpl="$VPA_HELM_VALUES_TMPL"
  _values_yaml="$VPA_HELM_VALUES_YAML"
  _release="$VPA_HELM_RELEASE"
  _chart="$VPA_HELM_CHART"
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

addons_vpa_remove() {
  addons_vpa_export_variables
  _addon="vpa"
  _ns="$VPA_NAMESPACE"
  _values_yaml="$VPA_HELM_VALUES_YAML"
  _release="$VPA_HELM_RELEASE"
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
  addons_vpa_clean_directories
}

addons_vpa_status() {
  addons_vpa_export_variables
  _addon="vpa"
  _ns="$VPA_NAMESPACE"
  _release="$VPA_HELM_RELEASE"
  if find_namespace "$_ns"; then
    kubectl get all,endpoints,ingress,secrets -n "$_ns" \
      -l "release=$_release"
  else
    echo "Namespace '$_ns' for '$_addon' not found!"
  fi
}

addons_vpa_summary() {
  addons_vpa_export_variables
  _addon="vpa"
  _ns="$VPA_NAMESPACE"
  _release="$VPA_HELM_RELEASE"
  print_helm_summary "$_ns" "$_addon" "$_release"
}

addons_vpa_command() {
  case "$1" in
    install) addons_vpa_install ;;
    remove) addons_vpa_remove ;;
    status) addons_vpa_status ;;
    summary) addons_vpa_summary ;;
    *) echo "Unknown vpa subcommand '$1'"; exit 1 ;;
  esac
}

addons_vpa_command_list() {
  echo "install remove status summary"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
