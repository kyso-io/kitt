#!/bin/sh
# ----
# File:        apps/portmaps.sh
# Description: Functions to configure the kyso applications portmap services
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022-2023 Kyso Inc.
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_APPS_PORTMAPS_SH="1"

# ---------
# Variables
# ---------

# CMND_DSC="portmaps: add or remove kyso applications portmap services"

# --------
# Includes
# --------

if [ -d "$INCL_DIR" ]; then
  # shellcheck source=../common.sh
  [ "$INCL_COMMON_SH" = "1" ] || . "$INCL_DIR/common.sh"
  # shellcheck source=../addons/ingress.sh
  [ "$INCL_ADDONS_INGRESS_SH" = "1" ] || . "$INCL_DIR/addons/ingress.sh"
  # shellcheck source=./common.sh
  [ "$INCL_APPS_COMMON_SH" = "1" ] || . "$INCL_DIR/apps/common.sh"
fi

# ---------
# Functions
# ---------

apps_portmaps_export_variables() {
  # Check if we need to run the function
  [ -z "$__apps_portmaps_export_variables" ] || return 0
  _deployment="$1"
  _cluster="$2"
  apps_common_export_variables "$_deployment" "$_cluster"
  # Directories
  export PORTMAPS_TMPL_DIR="$TMPL_DIR/apps/portmaps"
  export PORTMAPS_KUBECTL_DIR="$DEPLOY_KUBECTL_DIR/portmaps"
  # Templates
  export PORTMAPS_SVC_MAP_TMPL="$PORTMAPS_TMPL_DIR/svc_map.yaml"
  # Files
  export PORTMAPS_SVC_MAP_YAML="$PORTMAPS_KUBECTL_DIR/svc_map.yaml"
  # set variable to avoid running the function twice
  __apps_portmaps_export_variables="1"
}

apps_portmaps_check_directories() {
  apps_common_check_directories
  for _d in $PORTMAPS_KUBECTL_DIR; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

apps_portmaps_clean_directories() {
  # Try to remove empty dirs, except if they contain secrets
  for _d in $PORTMAPS_KUBECTL_DIR; do
    if [ -d "$_d" ]; then
      rmdir "$_d" 2>/dev/null || true
    fi
  done
}

apps_portmaps_install() {
  _deployment="$1"
  _cluster="$2"
  apps_portmaps_export_variables "$_deployment" "$_cluster"
  # Load additional variables & check directories
  apps_common_export_service_hostnames "$_deployment" "$_cluster"
  apps_portmaps_check_directories
  # Adjust variables
  _app="portmaps"
  _ns="$INGRESS_PORTMAPS_NAMESPACE"
  _svc_map_tmpl="$PORTMAPS_SVC_MAP_TMPL"
  _svc_map_yaml="$PORTMAPS_SVC_MAP_YAML"
  if ! find_namespace "$_ns"; then
    # Remove old files, just in case ...
    rm -f "$_svc_map_yaml"
    # Create namespace
    create_namespace "$_ns"
  fi
  # Prepare mapping services
  sed \
    -e "s%__NAMESPACE__%$_ns%" \
    -e "s%__DEPLOYMENT__%$DEPLOYMENT_NAME%" \
    -e "s%__ELASTICSEARCH_SVC_HOSTNAME__%$ELASTICSEARCH_SVC_HOSTNAME%" \
    -e "s%__KYSO_SCS_SVC_HOSTNAME__%$KYSO_SCS_SVC_HOSTNAME%" \
    -e "s%__MONGODB_SVC_HOSTNAME__%$MONGODB_SVC_HOSTNAME%" \
    -e "s%__NATS_SVC_HOSTNAME__%$NATS_SVC_HOSTNAME%" \
    "$_svc_map_tmpl" >"$_svc_map_yaml"
  for _yaml in $_svc_map_yaml; do
    kubectl_apply "$_yaml"
  done
}

apps_portmaps_remove() {
  _deployment="$1"
  _cluster="$2"
  apps_portmaps_export_variables "$_deployment" "$_cluster"
  _app="portmaps"
  _ns="$INGRESS_PORTMAPS_NAMESPACE"
  _svc_map_yaml="$PORTMAPS_SVC_MAP_YAML"
  if find_namespace "$_ns"; then
    header "Removing '$_app' objects"
    for _yaml in $_svc_map_yaml; do
      kubectl_delete "$_yaml" || true
    done
    delete_namespace "$_ns"
    footer
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
  apps_portmaps_clean_directories
}

apps_portmaps_status() {
  _deployment="$1"
  _cluster="$2"
  apps_portmaps_export_variables "$_deployment" "$_cluster"
  _app="portmaps"
  _ns="$INGRESS_PORTMAPS_NAMESPACE"
  if find_namespace "$_ns"; then
    kubectl get all -n "$_ns" -l deployment="$DEPLOYMENT_NAME"
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

apps_portmaps_summary() {
  _deployment="$1"
  _cluster="$2"
  apps_portmaps_export_variables "$_deployment" "$_cluster"
  _app="portmaps"
  _ns="$INGRESS_PORTMAPS_NAMESPACE"
  if find_namespace "$_ns"; then
    _names="$(
      kubectl get all -n "$_ns" -l deployment="$DEPLOYMENT_NAME" -o name
    )"
    if [ "$_names" ]; then
      echo "FOUND '$DEPLOYMENT_NAME'  entries in namespace '$_ns'"
      for _n in $_names; do
        echo "- $_n"
      done
    else
      echo "MISSING '$DEPLOYMENT_NAME'  entries in namespace '$_ns'"
    fi
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

apps_portmaps_command() {
  _command="$1"
  _deployment="$2"
  _cluster="$3"
  case "$_command" in
  install) apps_portmaps_install "$_deployment" "$_cluster" ;;
  remove) apps_portmaps_remove "$_deployment" "$_cluster" ;;
  status) apps_portmaps_status "$_deployment" "$_cluster" ;;
  summary) apps_portmaps_summary "$_deployment" "$_cluster" ;;
  *)
    echo "Unknown portmaps subcommand '$1'"
    exit 1
    ;;
  esac
}

apps_portmaps_command_list() {
  echo "install remove status summary"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
