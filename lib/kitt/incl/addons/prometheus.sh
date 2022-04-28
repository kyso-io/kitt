#!/bin/sh
# ----
# File:        addons/prometheus.sh
# Description: Functions to install and remove prometheus from a cluster
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_ADDONS_PROMETHEUS_SH="1"

# ---------
# Variables
# ---------

# CMND_DSC="prometheus: manage the cluster prometheus deployment (monitoring)"

# Fixed values
export PROMETHEUS_NAMESPACE="monitoring"
export PROMETHEUS_HELM_REPO_NAME="prometheus-community"
export \
  PROMETHEUS_HELM_REPO_URL="https://prometheus-community.github.io/helm-charts"
export PROMETHEUS_HELM_CHART="$PROMETHEUS_HELM_REPO_NAME/kube-prometheus-stack"
export PROMETHEUS_HELM_RELEASE="prometheus"
export PROMETHEUS_BASIC_AUTH_NAME="basic-auth"
export PROMETHEUS_BASIC_AUTH_USER="k3d-mon"

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

addon_prometheus_export_variables() {
  [ -z "$_addon_prometheus_export_variables" ] || return 0
  # Directories
  export PROMETHEUS_TMPL_DIR="$TMPL_DIR/addons/prometheus"
  export PROMETHEUS_HELM_DIR="$CLUST_HELM_DIR/prometheus"
  export PROMETHEUS_KUBECTL_DIR="$CLUST_KUBECTL_DIR/prometheus"
  export PROMETHEUS_SECRETS_DIR="$CLUST_SECRETS_DIR/prometheus"
  # Templates
  export PROMETHEUS_HELM_VALUES_TMPL="$PROMETHEUS_TMPL_DIR/values.yaml"
  export PROMETHEUS_INGRESS_TMPL="$PROMETHEUS_TMPL_DIR/ingress.yaml"
  # Files
  export PROMETHEUS_HELM_VALUES_YAML="$PROMETHEUS_HELM_DIR/values.yaml"
  export PROMETHEUS_INGRESS_YAML="$PROMETHEUS_KUBECTL_DIR/ingress.yaml"
  PROMETHEUS_AUTH_FILE="$PROMETHEUS_SECRETS_DIR/basic_auth${SOPS_EXT}.txt"
  export PROMETHEUS_AUTH_FILE
  PROMETHEUS_AUTH_YAML="$PROMETHEUS_KUBECTL_DIR/basic-auth${SOPS_EXT}.yaml"
  export PROMETHEUS_AUTH_YAML
  GRAFANA_ADMIN_PASS="$PROMETHEUS_SECRETS_DIR/grafana_admin_pass${SOPS_EXT}.txt"
  export GRAFANA_ADMIN_PASS
  # Set variable to avoid loading variables twice
  _addon_prometheus_export_variables="1"
}

addon_prometheus_check_directories() {
  for _d in "$PROMETHEUS_HELM_DIR"  "$PROMETHEUS_KUBECTL_DIR" \
    "$PROMETHEUS_SECRETS_DIR"; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

addon_prometheus_clean_directories() {
  # Try to remove empty dirs, except if they contain secrets
  for _d in "$PROMETHEUS_HELM_DIR" "$PROMETHEUS_KUBECTL_DIR" \
    "$PROMETHEUS_SECRETS_DIR"; do
    if [ -d "$_d" ]; then
      rmdir "$_d" 2>/dev/null || true
    fi
  done
}

addon_prometheus_install() {
  addon_prometheus_export_variables
  addon_prometheus_check_directories
  _addon="prometheus"
  _ns="$PROMETHEUS_NAMESPACE"
  _repo_name="$PROMETHEUS_HELM_REPO_NAME"
  _repo_url="$PROMETHEUS_HELM_REPO_URL"
  _values_tmpl="$PROMETHEUS_HELM_VALUES_TMPL"
  _values_yaml="$PROMETHEUS_HELM_VALUES_YAML"
  _release="$PROMETHEUS_HELM_RELEASE"
  _chart="$PROMETHEUS_HELM_CHART"
  _ingress_tmpl="$PROMETHEUS_INGRESS_TMPL"
  _ingress_yaml="$PROMETHEUS_INGRESS_YAML"
  if is_selected "$CLUSTER_USE_BASIC_AUTH"; then
    _auth_name="$PROMETHEUS_BASIC_AUTH_NAME"
    _auth_user="$PROMETHEUS_BASIC_AUTH_USER"
    _auth_file="$PROMETHEUS_AUTH_FILE"
  else
    _auth_name=""
    _auth_user=""
    _auth_file=""
  fi
  _auth_yaml="$PROMETHEUS_AUTH_YAML"
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
  # Create htpasswd for ingress if needed or remove the yaml if present
  if [ "$_auth_name" ]; then
    create_htpasswd_secret_yaml "$_ns" "$_auth_name" "$_auth_user" \
      "$_auth_file" "$_auth_yaml"
  else
    kubectl_delete "$_auth_yaml" || true
  fi
  # Create ingress definition
  create_addon_ingress_yaml "$_ns" "$_ingress_tmpl" "$_ingress_yaml" \
    "$_auth_name" "$_release"
  # Apply the YAML files
  for _yaml in "$_auth_yaml" "$_ingress_yaml"; do
    kubectl_apply "$_yaml"
  done
  footer
}

addon_prometheus_remove() {
  addon_prometheus_export_variables
  _addon="prometheus"
  _ns="$PROMETHEUS_NAMESPACE"
  _ingress_name="$PROMETHEUS_BASIC_AUTH_NAME"
  _ingress_yaml="$PROMETHEUS_INGRESS_YAML"
  _values_yaml="$PROMETHEUS_HELM_VALUES_YAML"
  _release="$PROMETHEUS_HELM_RELEASE"
  _auth_yaml="$PROMETHEUS_AUTH_YAML"
  if find_namespace "$_ns"; then
    header "Removing '$_addon' objects"
    # Delete ingress definition
    kubectl_delete "$_ingress_yaml" || true
    # Delete htpasswd secret
    kubectl_delete "$_auth_yaml" || true
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
  addon_prometheus_clean_directories
}

addon_prometheus_status() {
  addon_prometheus_export_variables
  _addon="prometheus"
  _ns="$PROMETHEUS_NAMESPACE"
  _release="$PROMETHEUS_HELM_RELEASE"
  if find_namespace "$_ns"; then
    kubectl get all,endpoints,ingress,secrets -n "$_ns" \
      -l "release=$_release"
  else
    echo "Namespace '$_ns' for '$_addon' not found!"
  fi
}

addon_prometheus_summary() {
  addon_prometheus_export_variables
  _addon="prometheus"
  _ns="$PROMETHEUS_NAMESPACE"
  _release="$PROMETHEUS_HELM_RELEASE"
  print_helm_summary "$_ns" "$_addon" "$_release"
}

addon_prometheus_command() {
  case "$1" in
    install) addon_prometheus_install ;;
    remove) addon_prometheus_remove ;;
    status) addon_prometheus_status ;;
    summary) addon_prometheus_summary ;;
    *) echo "Unknown prometheus subcommand '$1'"; exit 1 ;;
  esac
}

addon_prometheus_command_list() {
  echo "install remove status summary"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
