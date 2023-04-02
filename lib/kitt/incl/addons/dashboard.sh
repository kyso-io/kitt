#!/bin/sh

# ----
# File:        addons/dashboard.sh
# Description: Functions to manage the dashboard deployment on a k8s cluster
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022-2023 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_ADDONS_DASHBOARD_SH="1"

# ---------
# Variables
# ---------

# CMND_DSC="dashboard: manage the cluster k8s dashboard deployment (info)"

# Fixed values
export DASHBOARD_NAMESPACE="kubernetes-dashboard"
export DASHBOARD_HELM_REPO_NAME="kubernetes-dashboard"
export DASHBOARD_HELM_REPO_URL="https://kubernetes.github.io/dashboard/"
export DASHBOARD_HELM_CHART="$DASHBOARD_HELM_REPO_NAME/kubernetes-dashboard"
export DASHBOARD_HELM_RELEASE="dashboard"
export DASHBOARD_BASIC_AUTH_NAME="basic-auth"
export DASHBOARD_BASIC_AUTH_USER="k3d-dash"

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

addons_dashboard_export_variables() {
  [ -z "$__addons_dashboard_export_variables" ] || return 0
  # Directories
  export DASHBOARD_TMPL_DIR="$TMPL_DIR/addons/dashboard"
  export DASHBOARD_HELM_DIR="$CLUST_HELM_DIR/dashboard"
  export DASHBOARD_KUBECTL_DIR="$CLUST_KUBECTL_DIR/dashboard"
  export DASHBOARD_SECRETS_DIR="$CLUST_SECRETS_DIR/dashboard"
  # Templates
  export DASHBOARD_HELM_VALUES_TMPL="$DASHBOARD_TMPL_DIR/values.yaml"
  export DASHBOARD_INGRESS_TMPL="$DASHBOARD_TMPL_DIR/ingress.yaml"
  # Files
  export DASHBOARD_HELM_VALUES_YAML="$DASHBOARD_HELM_DIR/values.yaml"
  export DASHBOARD_INGRESS_YAML="$DASHBOARD_KUBECTL_DIR/ingress.yaml"
  export DASHBOARD_TOKEN="$DASHBOARD_SECRETS_DIR/token${SOPS_EXT}.txt"
  export DASHBOARD_AUTH_FILE="$DASHBOARD_SECRETS_DIR/basic_auth${SOPS_EXT}.txt"
  export DASHBOARD_AUTH_YAML="$DASHBOARD_KUBECTL_DIR/basic-auth${SOPS_EXT}.yaml"
  # Set variable to avoid loading variables twice
  __addons_dashboard_export_variables="1"
}

addons_dashboard_check_directories() {
  for _d in "$DASHBOARD_HELM_DIR"  "$DASHBOARD_KUBECTL_DIR" \
    "$DASHBOARD_SECRETS_DIR"; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

addons_dashboard_clean_directories() {
  # Try to remove empty dirs, except if they contain secrets
  for _d in "$DASHBOARD_HELM_DIR"  "$DASHBOARD_KUBECTL_DIR" \
    "$DASHBOARD_SECRETS_DIR"; do
    if [ -d "$_d" ]; then
      rmdir "$_d" 2>/dev/null || true
    fi
  done
}

addons_dashboard_install() {
  addons_dashboard_export_variables
  addons_dashboard_check_directories
  _addon="dashboard"
  _ns="$DASHBOARD_NAMESPACE"
  _repo_name="$DASHBOARD_HELM_REPO_NAME"
  _repo_url="$DASHBOARD_HELM_REPO_URL"
  _values_tmpl="$DASHBOARD_HELM_VALUES_TMPL"
  _values_yaml="$DASHBOARD_HELM_VALUES_YAML"
  _release="$DASHBOARD_HELM_RELEASE"
  _chart="$DASHBOARD_HELM_CHART"
  _ingress_tmpl="$DASHBOARD_INGRESS_TMPL"
  _ingress_yaml="$DASHBOARD_INGRESS_YAML"
  if is_selected "$CLUSTER_USE_BASIC_AUTH"; then
    _auth_name="$DASHBOARD_BASIC_AUTH_NAME"
    _auth_user="$DASHBOARD_BASIC_AUTH_USER"
    _auth_file="$DASHBOARD_AUTH_FILE"
  else
    _auth_name=""
    _auth_user=""
    _auth_file=""
  fi
  _auth_yaml="$DASHBOARD_AUTH_YAML"
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
    auth_file_update "$_auth_user" "$_auth_file"
    create_htpasswd_secret_yaml "$_ns" "$_auth_name" "$_auth_file" "$_auth_yaml"
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
  # Create service account for the dashboard
  kubectl create serviceaccount dashboard-admin || true
  # Bind the dashboard-admin service account to the cluster-admin role
  kubectl create clusterrolebinding dashboard-admin \
    --clusterrole=cluster-admin \
    --serviceaccount=default:dashboard-admin || true
  # Wait for installation to complete
  kubectl rollout status deployment --timeout="$ROLLOUT_STATUS_TIMEOUT" \
    -n "$_ns" "dashboard-kubernetes-dashboard"
  # Save token
  dashboard_admin_secret="$(
    kubectl get serviceaccount dashboard-admin \
      -o jsonpath="{.secrets[0].name}"
  )"
  dashboard_admin_token="$(
    kubectl get secret "$dashboard_admin_secret" \
      -o jsonpath="{.data.token}" | base64 --decode
  )"
  : >"$DASHBOARD_TOKEN"
  chmod 0600 "$DASHBOARD_TOKEN"
  echo "$dashboard_admin_token" | stdout_to_file "$DASHBOARD_TOKEN"
  # Display auth information
  header "Information to access the dashboard"
  if is_selected "$CLUSTER_USE_BASIC_AUTH"; then
    echo "Basic auth data is on the file: '$_auth_file'"
  fi
  echo "The dashboard token is on: '$DASHBOARD_TOKEN'"
  footer
}

addons_dashboard_remove() {
  addons_dashboard_export_variables
  _addon="dashboard"
  _ns="$DASHBOARD_NAMESPACE"
  _secrets=""
  _ingress_name="$DASHBOARD_BASIC_AUTH_NAME"
  _ingress_yaml="$DASHBOARD_INGRESS_YAML"
  _values_yaml="$DASHBOARD_HELM_VALUES_YAML"
  _release="$DASHBOARD_HELM_RELEASE"
  _pvc_yaml=""
  _pv_yaml=""
  _auth_yaml="$DASHBOARD_AUTH_YAML"
  if find_namespace "$_ns"; then
    header "Removing '$_addon' objects"
    # Delete secrets
    kubectl_delete "$_secrets" || true
    # Delete ingress definition
    kubectl_delete "$_ingress_yaml" || true
    # Delete htpasswd secret
    kubectl_delete "$_auth_yaml" || true
    # Uninstall chart
    if [ -f "$_values_yaml" ]; then
      helm uninstall -n "$_ns" "$_release" || true
      rm -f "$_values_yaml"
    fi
    # Remove pvc & pv if present
    kubectl_delete "$_pvc_yaml" || true
    kubectl_delete "$_pv_yaml" || true
    # Delete namespace if there are no charts deployed
    if [ -z "$(helm list -n "$_ns" -q)" ]; then
      delete_namespace "$_ns"
    fi
    footer
    kubectl delete serviceaccount dashboard-admin 2>/dev/null || true
    kubectl delete clusterrolebinding dashboard-admin 2>/dev/null || true
  else
    echo "Namespace '$_ns' for '$_addon' not found!"
  fi
  addons_dashboard_clean_directories
}

addons_dashboard_status() {
  addons_dashboard_export_variables
  _addon="dashboard"
  _ns="$DASHBOARD_NAMESPACE"
  if find_namespace "$_ns"; then
    kubectl get all,endpoints,ingress,secrets -n "$_ns"
  else
    echo "Namespace '$_ns' for '$_addon' not found!"
  fi
}

addons_dashboard_summary() {
  addons_dashboard_export_variables
  _addon="dashboard"
  _ns="$DASHBOARD_NAMESPACE"
  _release="$DASHBOARD_HELM_RELEASE"
  print_helm_summary "$_ns" "$_addon" "$_release"
}

addons_dashboard_uris() {
  addons_dashboard_export_variables
  _hostname="dashboard.$CLUSTER_DOMAIN"
  if is_selected "$CLUSTER_USE_BASIC_AUTH" &&
    [ -f "$DASHBOARD_AUTH_FILE" ]; then
    _uap="$(file_to_stdout "$DASHBOARD_AUTH_FILE")"
    echo "https://$_uap@$_hostname/"
  else
    echo "https://$_hostname/"
  fi
}

addons_dashboard_command() {
  case "$1" in
    install) addons_dashboard_install ;;
    remove) addons_dashboard_remove ;;
    status) addons_dashboard_status ;;
    summary) addons_dashboard_summary ;;
    uris) addons_dashboard_uris ;;
    *) echo "Unknown dashboard subcommand '$1'"; exit 1 ;;
  esac
}

addons_dashboard_command_list() {
  echo "install remove status summary uris"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
