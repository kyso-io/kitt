#!/bin/sh
# ----
# File:        addons/external-dns.sh
# Description: Functions to install and remove the external-dns from a cluster
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022-2023 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_ADDONS_EXTERNAL_DNS_SH="1"

# ---------
# Variables
# ---------

# CMND_DSC="external-dns: manage the cluster external-dns deployment (eks)"

# Fixed values
export EXTERNAL_DNS_NAMESPACE="kube-system"
export EXTERNAL_DNS_HELM_REPO_NAME="external-dns"
EXTERNAL_DNS_HELM_REPO_URL="https://kubernetes-sigs.github.io/external-dns"
export EXTERNAL_DNS_HELM_REPO_URL
export EXTERNAL_DNS_HELM_CHART="$EXTERNAL_DNS_HELM_REPO_NAME/external-dns"
export EXTERNAL_DNS_HELM_RELEASE="external-dns"

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

addons_external_dns_export_variables() {
  [ -z "$__addons_external_dns_export_variables" ] || return 0
  # Directories
  export EXTERNAL_DNS_TMPL_DIR="$TMPL_DIR/addons/external-dns"
  export EXTERNAL_DNS_HELM_DIR="$CLUST_HELM_DIR/external-dns"
  # Templates
  export EXTERNAL_DNS_HELM_VALUES_TMPL="$EXTERNAL_DNS_TMPL_DIR/values.yaml"
  # Files
  export EXTERNAL_DNS_HELM_VALUES_YAML="$EXTERNAL_DNS_HELM_DIR/values.yaml"
  # ROLES
  export ROUTE53_ROLE_NAME="$CLUSTER-route53-access"
  # Set variable to avoid loading variables twice
  __addons_external_dns_export_variables="1"
}

addons_external_dns_check_directories() {
  for _d in $EXTERNAL_DNS_HELM_DIR; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

addons_external_dns_clean_directories() {
  # Try to remove empty dirs, except if they contain secrets
  for _d in $EXTERNAL_DNS_HELM_DIR; do
    if [ -d "$_d" ]; then
      rmdir "$_d" 2>/dev/null || true
    fi
  done
}

addons_external_dns_install() {
  addons_external_dns_export_variables
  addons_external_dns_check_directories
  _addon="external-dns"
  _ns="$EXTERNAL_DNS_NAMESPACE"
  _repo_name="$EXTERNAL_DNS_HELM_REPO_NAME"
  _repo_url="$EXTERNAL_DNS_HELM_REPO_URL"
  _values_tmpl="$EXTERNAL_DNS_HELM_VALUES_TMPL"
  _values_yaml="$EXTERNAL_DNS_HELM_VALUES_YAML"
  _release="$EXTERNAL_DNS_HELM_RELEASE"
  _chart="$EXTERNAL_DNS_HELM_CHART"
  header "Installing '$_addon'"
  # Check helm repo
  check_helm_repo "$_repo_name" "$_repo_url"
  # Create namespace if needed
  if ! find_namespace "$_ns"; then
    create_namespace "$_ns"
  fi
  _route53_role_arn="$(aws_get_role_arn "$ROUTE53_ROLE_NAME")"
  # Values for the chart
  sed \
    -e "s/__ROUTE53_ROLE_ARN__/$_route53_role_arn/" \
    "$_values_tmpl" >"$_values_yaml"
  # Update or install chart
  helm_upgrade "$_ns" "$_values_yaml" "$_release" "$_chart" "" "$_release"
  footer
}

addons_external_dns_remove() {
  addons_external_dns_export_variables
  _addon="external-dns"
  _ns="$EXTERNAL_DNS_NAMESPACE"
  _values_yaml="$EXTERNAL_DNS_HELM_VALUES_YAML"
  _release="$EXTERNAL_DNS_HELM_RELEASE"
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
  addons_external_dns_clean_directories
}

addons_external_dns_status() {
  addons_external_dns_export_variables
  _addon="external-dns"
  _ns="$EXTERNAL_DNS_NAMESPACE"
  _release="$EXTERNAL_DNS_HELM_RELEASE"
  if find_namespace "$_ns"; then
    kubectl get all,endpoints,ingress,secrets -n "$_ns" \
      -l "release=$_release"
  else
    echo "Namespace '$_ns' for '$_addon' not found!"
  fi
}

addons_external_dns_summary() {
  addons_external_dns_export_variables
  _addon="external-dns"
  _ns="$EXTERNAL_DNS_NAMESPACE"
  _release="$EXTERNAL_DNS_HELM_RELEASE"
  print_helm_summary "$_ns" "$_addon" "$_release"
}

addons_external_dns_command() {
  case "$1" in
    install) addons_external_dns_install ;;
    remove) addons_external_dns_remove ;;
    status) addons_external_dns_status ;;
    summary) addons_external_dns_summary ;;
    *) echo "Unknown external-dns subcommand '$1'"; exit 1 ;;
  esac
}

addons_external_dns_command_list() {
  echo "install remove status summary"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
