#!/bin/sh
# ----
# File:        addons/minio.sh
# Description: Functions to install and remove minio from a cluster
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_ADDONS_MINIO_SH="1"

# ---------
# Variables
# ---------

# CMND_DSC="minio: manage the cluster minio deployment (k3d backups)"

# Fixed values
export MINIO_NAMESPACE="velero"
export MINIO_HELM_REPO_NAME="minio"
export MINIO_HELM_REPO_URL="https://charts.min.io"
export MINIO_HELM_CHART="$MINIO_HELM_REPO_NAME/minio"
export MINIO_HELM_RELEASE="minio"
export MINIO_ROOT_USER="minio"
export MINIO_ROOT_PASS="321oinim"
export MINIO_BASIC_AUTH_NAME="basic-auth"
export MINIO_BASIC_AUTH_USER="k3d-mon"
export MINIO_MEMORY="4Gi"
export MINIO_STORAGE_SIZE="500Gi"

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

addons_minio_export_variables() {
  [ -z "$__addons_minio_export_variables" ] || return 0
  # Directories
  export MINIO_TMPL_DIR="$TMPL_DIR/addons/minio"
  export MINIO_HELM_DIR="$CLUST_HELM_DIR/minio"
  export MINIO_KUBECTL_DIR="$CLUST_KUBECTL_DIR/minio"
  export MINIO_SECRETS_DIR="$CLUST_SECRETS_DIR/minio"
  # Templates
  export MINIO_HELM_VALUES_TMPL="$MINIO_TMPL_DIR/values.yaml"
  export MINIO_INGRESS_TMPL="$MINIO_TMPL_DIR/ingress.yaml"
  export MINIO_PV_TMPL="$MINIO_TMPL_DIR/pv.yaml"
  export MINIO_PVC_TMPL="$MINIO_TMPL_DIR/pvc.yaml"
  # Files
  export MINIO_HELM_VALUES_YAML="$MINIO_HELM_DIR/values.yaml"
  export MINIO_INGRESS_YAML="$MINIO_KUBECTL_DIR/ingress.yaml"
  _auth_file="$MINIO_SECRETS_DIR/basic_auth${SOPS_EXT}.txt"
  export MINIO_AUTH_FILE="$_auth_file"
  _auth_yaml="$MINIO_KUBECTL_DIR/basic-auth${SOPS_EXT}.yaml"
  export MINIO_AUTH_YAML="$_auth_yaml"
  export MINIO_PV_YAML="$MINIO_KUBECTL_DIR/pv.yaml"
  export MINIO_PVC_YAML="$MINIO_KUBECTL_DIR/pvc.yaml"
  # Set variable to avoid loading variables twice
  __addons_minio_export_variables="1"
}

addons_minio_check_directories() {
  for _d in "$MINIO_HELM_DIR"  "$MINIO_KUBECTL_DIR" "$MINIO_SECRETS_DIR"; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

addons_minio_clean_directories() {
  # Try to remove empty dirs, except if they contain secrets
  for _d in "$MINIO_HELM_DIR" "$MINIO_KUBECTL_DIR" "$MINIO_SECRETS_DIR"; do
    if [ -d "$_d" ]; then
      rmdir "$_d" 2>/dev/null || true
    fi
  done
}

addons_minio_install() {
  addons_minio_export_variables
  addons_minio_check_directories
  _addon="minio"
  _ns="$MINIO_NAMESPACE"
  _repo_name="$MINIO_HELM_REPO_NAME"
  _repo_url="$MINIO_HELM_REPO_URL"
  _values_tmpl="$MINIO_HELM_VALUES_TMPL"
  _values_yaml="$MINIO_HELM_VALUES_YAML"
  _pv_tmpl="$MINIO_PV_TMPL"
  _pv_yaml="$MINIO_PV_YAML"
  _pvc_tmpl="$MINIO_PVC_TMPL"
  _pvc_yaml="$MINIO_PVC_YAML"
  _release="$MINIO_HELM_RELEASE"
  _chart="$MINIO_HELM_CHART"
  _ingress_tmpl="$MINIO_INGRESS_TMPL"
  _ingress_yaml="$MINIO_INGRESS_YAML"
  if is_selected "$CLUSTER_USE_BASIC_AUTH"; then
    _auth_name="$MINIO_BASIC_AUTH_NAME"
    _auth_user="$MINIO_BASIC_AUTH_USER"
    _auth_file="$MINIO_AUTH_FILE"
  else
    _auth_name=""
    _auth_user=""
    _auth_file=""
  fi
  _auth_yaml="$MINIO_AUTH_YAML"
  if is_selected "$CLUSTER_USE_LOCAL_STORAGE"; then
    _storage_class="local-storage"
    _storage_size="$MINIO_STORAGE_SIZE"
    _pv_name="$_release-$_ns-pv"
    _pvc_name="$_release-$_ns-pvc"
  else
    _storage_class=""
    _storage_size="$MINIO_STORAGE_SIZE"
    _pv_name=""
    _pvc_name=""
  fi
  _memory="$MINIO_MEMORY"
  header "Installing '$_addon'"
  # Check helm repo
  check_helm_repo "$_repo_name" "$_repo_url"
  # Create namespace if needed
  if ! find_namespace "$_ns"; then
    create_namespace "$_ns"
  fi
  # Values for the chart
  sed \
    -e "s%__MINIO_ROOT_USER__%$MINIO_ROOT_USER%" \
    -e "s%__MINIO_ROOT_PASS__%$MINIO_ROOT_PASS%" \
    -e "s%__STORAGE_CLASS__%$_storage_class%" \
    -e "s%__PVC_NAME__%$_pvc_name%" \
    -e "s%__MINIO_MEMORY__%$MINIO_MEMORY%" \
    "$_values_tmpl" >"$_values_yaml"
  if is_selected "$CLUSTER_USE_LOCAL_STORAGE"; then
    test -d "$CLUST_VOLUMES_DIR/$_pv_name" ||
      mkdir "$CLUST_VOLUMES_DIR/$_pv_name"
    sed \
      -e "s%__NAMESPACE__%$_ns%" \
      -e "s%__APP__%$_release%" \
      -e "s%__PV_NAME__%$_pv_name%" \
      -e "s%__PVC_NAME__%$_pvc_name%" \
      -e "s%__STORAGE_CLASS__%$_storage_class%" \
      -e "s%__STORAGE_SIZE__%$_storage_size%" \
      "$_pv_tmpl" >"$_pv_yaml"
    sed \
      -e "s%__NAMESPACE__%$_ns%" \
      -e "s%__APP__%$_release%" \
      -e "s%__PVC_NAME__%$_pvc_name%" \
      -e "s%__STORAGE_CLASS__%$_storage_class%" \
      -e "s%__STORAGE_SIZE__%$_storage_size%" \
      "$_pvc_tmpl" >"$_pvc_yaml"
    for _yaml in "$_pv_yaml" "$_pvc_yaml"; do
      kubectl_apply "$_yaml"
    done
  else
    for _yaml in "$_pvc_yaml" "$_pv_yaml"; do
      kubectl_delete "$_yaml" || true
    done
  fi
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
  footer
}

addons_minio_remove() {
  addons_minio_export_variables
  _addon="minio"
  _ns="$MINIO_NAMESPACE"
  _ingress_name="$MINIO_BASIC_AUTH_NAME"
  _ingress_yaml="$MINIO_INGRESS_YAML"
  _values_yaml="$MINIO_HELM_VALUES_YAML"
  _release="$MINIO_HELM_RELEASE"
  _auth_yaml="$MINIO_AUTH_YAML"
  _pv_yaml="$MINIO_PV_YAML"
  _pvc_yaml="$MINIO_PVC_YAML"
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
    # Delete pvc & pv if present
    for _yaml in "$_pvc_yaml" "$_pv_yaml"; do
      kubectl_delete "$_yaml" || true
    done
    # Delete namespace if there are no charts deployed
    if [ -z "$(helm list -n "$_ns" -q)" ]; then
      delete_namespace "$_ns"
    fi
    footer
  else
    echo "Namespace '$_ns' for '$_addon' not found!"
  fi
  addons_minio_clean_directories
}

addons_minio_status() {
  addons_minio_export_variables
  _addon="minio"
  _ns="$MINIO_NAMESPACE"
  _release="$MINIO_HELM_RELEASE"
  if find_namespace "$_ns"; then
    kubectl get all,endpoints,ingress,secrets -n "$_ns" \
      -l "release=$_release"
  else
    echo "Namespace '$_ns' for '$_addon' not found!"
  fi
}

addons_minio_summary() {
  addons_minio_export_variables
  _addon="minio"
  _ns="$MINIO_NAMESPACE"
  _release="$MINIO_HELM_RELEASE"
  print_helm_summary "$_ns" "$_addon" "$_release"
}

addons_minio_uris() {
  addons_minio_export_variables
  _hostname="minio.$CLUSTER_DOMAIN"
  if is_selected "$CLUSTER_USE_BASIC_AUTH" && [ -f "$MINIO_AUTH_FILE" ]; then
    _uap="$(file_to_stdout "$MINIO_AUTH_FILE")"
    echo "https://$_uap@$_hostname/"
  else
    echo "https://$_hostname/"
  fi
}

addons_minio_command() {
  case "$1" in
    install) addons_minio_install ;;
    remove) addons_minio_remove ;;
    status) addons_minio_status ;;
    summary) addons_minio_summary ;;
    uris) addons_minio_uris ;;
    *) echo "Unknown minio subcommand '$1'"; exit 1 ;;
  esac
}

addons_minio_command_list() {
  echo "install remove status summary uris"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
