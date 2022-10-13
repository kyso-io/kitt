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

addons_prometheus_export_variables() {
  [ -z "$_addons_prometheus_export_variables" ] || return 0
  # Directories
  export PROMETHEUS_TMPL_DIR="$TMPL_DIR/addons/prometheus"
  export PROMETHEUS_HELM_DIR="$CLUST_HELM_DIR/prometheus"
  export PROMETHEUS_KUBECTL_DIR="$CLUST_KUBECTL_DIR/prometheus"
  export PROMETHEUS_SECRETS_DIR="$CLUST_SECRETS_DIR/prometheus"
  # Templates
  export PROMETHEUS_HELM_VALUES_TMPL="$PROMETHEUS_TMPL_DIR/values.yaml"
  export PROMETHEUS_INGRESS_TMPL="$PROMETHEUS_TMPL_DIR/ingress.yaml"
  # Files
  PROMETHEUS_HELM_VALUES_YAML="$PROMETHEUS_HELM_DIR/values${SOPS_EXT}.yaml"
  export PROMETHEUS_HELM_VALUES_YAML
  export PROMETHEUS_INGRESS_YAML="$PROMETHEUS_KUBECTL_DIR/ingress.yaml"
  PROMETHEUS_AUTH_FILE="$PROMETHEUS_SECRETS_DIR/basic_auth${SOPS_EXT}.txt"
  export PROMETHEUS_AUTH_FILE
  PROMETHEUS_AUTH_YAML="$PROMETHEUS_KUBECTL_DIR/basic-auth${SOPS_EXT}.yaml"
  export PROMETHEUS_AUTH_YAML
  GRAFANA_ADMIN_PASS="$PROMETHEUS_SECRETS_DIR/grafana_admin_pass${SOPS_EXT}.txt"
  export GRAFANA_ADMIN_PASS
  # Set variable to avoid loading variables twice
  _addons_prometheus_export_variables="1"
}

addons_prometheus_check_directories() {
  for _d in "$PROMETHEUS_HELM_DIR"  "$PROMETHEUS_KUBECTL_DIR" \
    "$PROMETHEUS_SECRETS_DIR"; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

addons_prometheus_clean_directories() {
  # Try to remove empty dirs, except if they contain secrets
  for _d in "$PROMETHEUS_HELM_DIR" "$PROMETHEUS_KUBECTL_DIR" \
    "$PROMETHEUS_SECRETS_DIR"; do
    if [ -d "$_d" ]; then
      rmdir "$_d" 2>/dev/null || true
    fi
  done
}

addons_prometheus_install() {
  addons_prometheus_export_variables
  addons_prometheus_check_directories
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
  if [ -f "$GRAFANA_ADMIN_PASS" ]; then
    _admin_pass="$(file_to_stdout "$GRAFANA_ADMIN_PASS")"
  else
    _admin_pass="$(openssl rand -base64 12 | sed -e 's%+%-%g;s%/%_%g')"
  fi
  sed \
    -e "s%__ADMIN_PASS__%$_admin_pass%" \
    "$_values_tmpl" | stdout_to_file "$_values_yaml"
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
  create_addons_ingress_yaml "$_ns" "$_ingress_tmpl" "$_ingress_yaml" \
    "$_auth_name" "$_release"
  # Apply the YAML files
  for _yaml in "$_auth_yaml" "$_ingress_yaml"; do
    kubectl_apply "$_yaml"
  done
  # Wait for installation to complete
  kubectl rollout status deployment --timeout="$ROLLOUT_STATUS_TIMEOUT" \
    -n "$_ns" "$_release-grafana"
  # Save grafana admin password
  kubectl get secret -n "$_ns" "$_release-grafana" \
    -o jsonpath="{.data.admin-password}" |
    base64 --decode |
    stdout_to_file "$GRAFANA_ADMIN_PASS"
  footer
}

addons_prometheus_remove() {
  addons_prometheus_export_variables
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
  addons_prometheus_clean_directories
}

addons_prometheus_status() {
  addons_prometheus_export_variables
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

addons_prometheus_summary() {
  addons_prometheus_export_variables
  _addon="prometheus"
  _ns="$PROMETHEUS_NAMESPACE"
  _release="$PROMETHEUS_HELM_RELEASE"
  print_helm_summary "$_ns" "$_addon" "$_release"
}

addons_prometheus_uris() {
  addons_prometheus_export_variables
  if is_selected "$CLUSTER_USE_BASIC_AUTH" &&
    [ -f "$PROMETHEUS_AUTH_FILE" ]; then
    _uap="$(file_to_stdout "$PROMETHEUS_AUTH_FILE")"
  else
    _uap=""
  fi
  echo "https://grafana.$CLUSTER_DOMAIN/"
  if [ -f "$GRAFANA_ADMIN_PASS" ]; then
    echo "Grafana 'admin' pass: '$(file_to_stdout "$GRAFANA_ADMIN_PASS")'"
  fi
  for _hostname in "prometheus" "prometheus-alertmanager"; do
    if [ "$_uap" ]; then
      echo "https://$_uap@$_hostname.$CLUSTER_DOMAIN/"
    else
      echo "https://$_hostname.$CLUSTER_DOMAIN/"
    fi
  done
}

addons_prometheus_command() {
  case "$1" in
    install) addons_prometheus_install ;;
    remove) addons_prometheus_remove ;;
    status) addons_prometheus_status ;;
    summary) addons_prometheus_summary ;;
    uris) addons_prometheus_uris ;;
    *) echo "Unknown prometheus subcommand '$1'"; exit 1 ;;
  esac
}

addons_prometheus_command_list() {
  echo "install remove status summary uris"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
