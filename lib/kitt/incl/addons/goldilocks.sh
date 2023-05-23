#!/bin/sh
# ----
# File:        addons/goldilocks.sh
# Description: Functions to install and remove goldilocks for goldilocks from a cluster
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022-2023 Kyso Inc.
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_ADDONS_GOLDILOCKS_SH="1"

# ---------
# Variables
# ---------

# CMND_DSC="goldilocks: manage the cluster goldilocks deployment"

# Fixed values
export GOLDILOCKS_NAMESPACE="goldilocks"
export GOLDILOCKS_HELM_REPO_NAME="fairwinds-stable"
export GOLDILOCKS_HELM_REPO_URL="https://charts.fairwinds.com/stable"
export GOLDILOCKS_HELM_CHART="$GOLDILOCKS_HELM_REPO_NAME/goldilocks"
export GOLDILOCKS_HELM_RELEASE="goldilocks"
export GOLDILOCKS_BASIC_AUTH_NAME="basic-auth"
export GOLDILOCKS_BASIC_AUTH_USER="goldi"

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

addons_goldilocks_export_variables() {
  [ -z "$__addons_goldilocks_export_variables" ] || return 0
  # Directories
  export GOLDILOCKS_TMPL_DIR="$TMPL_DIR/addons/goldilocks"
  export GOLDILOCKS_HELM_DIR="$CLUST_HELM_DIR/goldilocks"
  export GOLDILOCKS_KUBECTL_DIR="$CLUST_KUBECTL_DIR/goldilocks"
  export GOLDILOCKS_SECRETS_DIR="$CLUST_SECRETS_DIR/goldilocks"
  # Templates
  export GOLDILOCKS_HELM_VALUES_TMPL="$GOLDILOCKS_TMPL_DIR/values.yaml"
  export GOLDILOCKS_INGRESS_TMPL="$GOLDILOCKS_TMPL_DIR/ingress.yaml"
  # Files
  export GOLDILOCKS_HELM_VALUES_YAML="$GOLDILOCKS_HELM_DIR/values.yaml"
  export GOLDILOCKS_INGRESS_YAML="$GOLDILOCKS_KUBECTL_DIR/ingress.yaml"
  _auth_file="$GOLDILOCKS_SECRETS_DIR/basic_auth${SOPS_EXT}.txt"
  export GOLDILOCKS_AUTH_FILE="$_auth_file"
  _auth_yaml="$GOLDILOCKS_KUBECTL_DIR/basic-auth${SOPS_EXT}.yaml"
  export GOLDILOCKS_AUTH_YAML="$_auth_yaml"
  # Set variable to avoid loading variables twice
  __addons_goldilocks_export_variables="1"
}

addons_goldilocks_check_directories() {
  for _d in "$GOLDILOCKS_HELM_DIR" "$GOLDILOCKS_KUBECTL_DIR" \
    "$GOLDILOCKS_SECRETS_DIR"; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

addons_goldilocks_clean_directories() {
  # Try to remove empty dirs, except if they contain secrets
  for _d in "$GOLDILOCKS_HELM_DIR" "$GOLDILOCKS_KUBECTL_DIR" \
    "$GOLDILOCKS_SECRETS_DIR"; do
    if [ -d "$_d" ]; then
      rmdir "$_d" 2>/dev/null || true
    fi
  done
}

addons_goldilocks_install() {
  addons_goldilocks_export_variables
  addons_goldilocks_check_directories
  _addon="goldilocks"
  _ns="$GOLDILOCKS_NAMESPACE"
  _repo_name="$GOLDILOCKS_HELM_REPO_NAME"
  _repo_url="$GOLDILOCKS_HELM_REPO_URL"
  _values_tmpl="$GOLDILOCKS_HELM_VALUES_TMPL"
  _values_yaml="$GOLDILOCKS_HELM_VALUES_YAML"
  _release="$GOLDILOCKS_HELM_RELEASE"
  _chart="$GOLDILOCKS_HELM_CHART"
  _ingress_tmpl="$GOLDILOCKS_INGRESS_TMPL"
  _ingress_yaml="$GOLDILOCKS_INGRESS_YAML"
  if is_selected "$CLUSTER_USE_BASIC_AUTH"; then
    _auth_name="$GOLDILOCKS_BASIC_AUTH_NAME"
    _auth_user="$GOLDILOCKS_BASIC_AUTH_USER"
    _auth_file="$GOLDILOCKS_AUTH_FILE"
  else
    _auth_name=""
    _auth_user=""
    _auth_file=""
  fi
  _auth_yaml="$GOLDILOCKS_AUTH_YAML"
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
  footer
}

addons_goldilocks_remove() {
  addons_goldilocks_export_variables
  _addon="goldilocks"
  _ns="$GOLDILOCKS_NAMESPACE"
  _ingress_name="$MINIO_BASIC_AUTH_NAME"
  _ingress_yaml="$MINIO_INGRESS_YAML"
  _values_yaml="$GOLDILOCKS_HELM_VALUES_YAML"
  _release="$GOLDILOCKS_HELM_RELEASE"
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
  addons_goldilocks_clean_directories
}

addons_goldilocks_status() {
  addons_goldilocks_export_variables
  _addon="goldilocks"
  _ns="$GOLDILOCKS_NAMESPACE"
  _release="$GOLDILOCKS_HELM_RELEASE"
  if find_namespace "$_ns"; then
    kubectl get all,endpoints,ingress,secrets -n "$_ns" \
      -l "release=$_release"
  else
    echo "Namespace '$_ns' for '$_addon' not found!"
  fi
}

addons_goldilocks_summary() {
  addons_goldilocks_export_variables
  _addon="goldilocks"
  _ns="$GOLDILOCKS_NAMESPACE"
  _release="$GOLDILOCKS_HELM_RELEASE"
  print_helm_summary "$_ns" "$_addon" "$_release"
}

addons_goldilocks_uris() {
  addons_goldilocks_export_variables
  _hostname="goldilocks.$CLUSTER_DOMAIN"
  if is_selected "$CLUSTER_USE_BASIC_AUTH" &&
    [ -f "$GOLDILOCKS_AUTH_FILE" ]; then
    _uap="$(file_to_stdout "$GOLDILOCKS_AUTH_FILE")"
    echo "https://$_uap@$_hostname/"
  else
    echo "https://$_hostname/"
  fi
}

addons_goldilocks_command() {
  case "$1" in
    install) addons_goldilocks_install ;;
    remove) addons_goldilocks_remove ;;
    status) addons_goldilocks_status ;;
    summary) addons_goldilocks_summary ;;
    uris) addons_goldilocks_uris ;;
    *) echo "Unknown goldilocks subcommand '$1'"; exit 1 ;;
  esac
}

addons_goldilocks_command_list() {
  echo "install remove status summary uris"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
