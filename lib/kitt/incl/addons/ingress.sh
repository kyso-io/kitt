#!/bin/sh
# ----
# File:        addons/ingress.sh
# Description: Functions to install and remove the nginx ingress from a cluster
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_ADDONS_INGRESS_SH="1"

# ---------
# Variables
# ---------

# CMND_DSC="ingress: manage the cluster nginx ingress deployment"

# Fixed values
export INGRESS_NAMESPACE="ingress"
export INGRESS_HELM_REPO_NAME="bitnami"
export INGRESS_HELM_REPO_URL="https://charts.bitnami.com/bitnami"
export INGRESS_HELM_CHART="$INGRESS_HELM_REPO_NAME/nginx-ingress-controller"
export INGRESS_HELM_RELEASE="ingress"
export INGRESS_CERT_NAME="ingress-cert"
export INGRESS_PORTMAPS_NAMESPACE="ingress-portmaps"

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

addons_ingress_export_variables() {
  [ -z "$_addons_ingress_export_variables" ] || return 0
  # Directories
  export INGRESS_TMPL_DIR="$TMPL_DIR/addons/ingress"
  export INGRESS_HELM_DIR="$CLUST_HELM_DIR/ingress"
  export INGRESS_KUBECTL_DIR="$CLUST_KUBECTL_DIR/ingress"
  # Templates
  export INGRESS_HELM_VALUES_TMPL="$INGRESS_TMPL_DIR/values.yaml"
  # Files
  export INGRESS_HELM_VALUES_YAML="$INGRESS_HELM_DIR/values.yaml"
  export INGRESS_CERT_CRT="$CERTIFICATES_DIR/$CLUSTER_DOMAIN.crt"
  export INGRESS_CERT_KEY="$CERTIFICATES_DIR/$CLUSTER_DOMAIN${SOPS_EXT}.key"
  _cert_yaml="$INGRESS_KUBECTL_DIR/$INGRESS_CERT_NAME$SOPS_EXT.yaml"
  export INGRESS_CERT_YAML="$_cert_yaml"
  # Set variable to avoid loading variables twice
  _addons_ingress_export_variables="1"
}

addons_ingress_check_directories() {
  for _d in "$INGRESS_HELM_DIR" "$INGRESS_KUBECTL_DIR"; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

addons_ingress_clean_directories() {
  # Try to remove empty dirs, except if they contain secrets
  for _d in "$INGRESS_HELM_DIR" "$INGRESS_KUBECTL_DIR"; do
    if [ -d "$_d" ]; then
      rmdir "$_d" 2>/dev/null || true
    fi
  done
}

addons_ingress_create_cert_yaml() {
  _ns="$INGRESS_NAMESPACE"
  _cert_name="$INGRESS_CERT_NAME"
  _cert_crt="$INGRESS_CERT_CRT"
  _cert_key="$INGRESS_CERT_KEY"
  create_tls_cert_yaml "$_ns" "$_cert_name" "$_cert_crt" "$_cert_key" \
    "$_cert_yaml"
}

addons_ingress_newcert() {
  addons_ingress_export_variables
  _cert_yaml="$INGRESS_CERT_YAML"
  addons_ingress_create_cert_yaml "$_cert_yaml"
  kubectl_apply "$_cert_yaml"
}

addons_ingress_install() {
  addons_ingress_export_variables
  addons_ingress_check_directories
  _addon="ingress"
  _cert_name="$INGRESS_CERT_NAME"
  _cert_yaml="$INGRESS_CERT_YAML"
  _ns="$INGRESS_NAMESPACE"
  _replicas="$CLUSTER_INGRESS_REPLICAS"
  _repo_name="$INGRESS_HELM_REPO_NAME"
  _repo_url="$INGRESS_HELM_REPO_URL"
  _values_tmpl="$INGRESS_HELM_VALUES_TMPL"
  _values_yaml="$INGRESS_HELM_VALUES_YAML"
  _release="$INGRESS_HELM_RELEASE"
  _chart="$INGRESS_HELM_CHART"
  header "Installing '$_addon'"
  # Create _cert_yaml
  addons_ingress_create_cert_yaml "$_cert_yaml"
  # Check helm repo
  check_helm_repo "$_repo_name" "$_repo_url"
  # Create namespace if needed
  if ! find_namespace "$_ns"; then
    create_namespace "$_ns"
  fi
  # Add ingress certificate
  kubectl_apply "$_cert_yaml"
  # Remove kyso dev port mapping if not set
  if is_selected "${CLUSTER_MAP_KYSO_DEV_PORTS}"; then
    dev_ports_sed="s%__PORTMAPS_NAMESPACE__%$INGRESS_PORTMAPS_NAMESPACE%"
  else
    dev_ports_sed="/BEG: MAP_KYSO_DEV_PORTS/,/END: MAP_KYSO_DEV_PORTS/d"
  fi
  # Values for the chart
  sed \
    -e "s%__INGRESS_CERT_NAME__%$_cert_name%" \
    -e "s%__REPLICAS__%$_replicas%" \
    -e "$dev_ports_sed" \
    "$_values_tmpl" >"$_values_yaml"
  # Update or install chart
  helm_upgrade "$_ns" "$_values_yaml" "$_release" "$_chart"
  # Wait for installation to complete
  kubectl rollout status deployment --timeout="$ROLLOUT_STATUS_TIMEOUT" \
    -n "$_ns" "ingress-nginx-ingress-controller"
  footer
  header "LoadBalancer info:"
  kubectl -n ingress get svc | grep -E -e NAME -e LoadBalancer
  footer
}

addons_ingress_remove() {
  addons_ingress_export_variables
  _addon="ingress"
  _ns="$INGRESS_NAMESPACE"
  _secrets="$INGRESS_CERT_YAML"
  _values="$INGRESS_HELM_VALUES_YAML"
  _release="$INGRESS_HELM_RELEASE"
  if find_namespace "$_ns"; then
    header "Removing '$_addon' objects"
    # Delete secrets
    kubectl_delete "$_secrets" || true
    # Uninstall chart
    if [ -f "$_values" ]; then
      helm uninstall -n "$_ns" "$_release" || true
      rm -f "$_values"
    fi
    # Delete namespace if there are no charts deployed
    if [ -z "$(helm list -n "$_ns" -q)" ]; then
      delete_namespace "$_ns"
    fi
    footer
  else
    echo "Namespace '$_ns' for '$_addon' not found!"
  fi
  addons_ingress_clean_directories
}

addons_ingress_status() {
  addons_ingress_export_variables
  _addon="ingress"
  _ns="$INGRESS_NAMESPACE"
  if find_namespace "$_ns"; then
    kubectl get all,endpoints,ingress,secrets -n "$_ns"
  else
    echo "Namespace '$_ns' for '$_addon' not found!"
  fi
}

addons_ingress_summary() {
  addons_ingress_export_variables
  _addon="ingress"
  _ns="$INGRESS_NAMESPACE"
  _release="$INGRESS_HELM_RELEASE"
  print_helm_summary "$_ns" "$_addon" "$_release"
}

addons_ingress_command() {
  case "$1" in
  install) addons_ingress_install ;;
  remove) addons_ingress_remove ;;
  renew) addons_ingress_newcert ;;
  status) addons_ingress_status ;;
  summary) addons_ingress_summary ;;
  *)
    echo "Unknown ingress subcommand '$1'"
    exit 1
    ;;
  esac
}

addons_ingress_command_list() {
  echo "install remove renew status summary"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
