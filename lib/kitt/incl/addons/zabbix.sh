#!/bin/sh
# ----
# File:        addons/zabbix.sh
# Description: Functions to install and remove zabbix from a cluster
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_ADDONS_ZABBIX_SH="1"

# ---------
# Variables
# ---------

# CMND_DSC="zabbix: manage the cluster zabbix deployment (monitoring)"

# Defaults
export CLUSTER_DEFAULT_ZABBIX_SERVER_HOST="zabbix.kyso.io"
export CLUSTER_DEFAULT_ZABBIX_SERVER_PORT="10051"

# Fixed values
export ZABBIX_NAMESPACE="monitoring"
export ZABBIX_HELM_REPO_NAME="zabbix-chart-6.2"
_repo_url="https://cdn.zabbix.com/zabbix/integrations/kubernetes-helm/6.2"
export ZABBIX_HELM_REPO_URL="$_repo_url"
export ZABBIX_HELM_CHART="$ZABBIX_HELM_REPO_NAME/zabbix-helm-chrt"
export ZABBIX_HELM_RELEASE="zabbix"
# Chart values, will make configurable if needed
_zbx_proxy_image_repo="registry.kyso.io/docker/zabbix/zabbix-proxy-sqlite3"
export ZABBIX_PROXY_IMAGE_REPOSITORY="$_zbx_proxy_image_repo"
export ZABBIX_PROXY_IMAGE_TAG="alpine-6.2.0"
_zbx_agent2_image_repo="registry.kyso.io/docker/zabbix/zabbix-agent2"
export ZABBIX_AGENT2_IMAGE_REPOSITORY="$_zbx_agent2_image_repo"
export ZABBIX_AGENT2_IMAGE_TAG="alpine-6.2.0"

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

addons_zabbix_export_variables() {
  [ -z "$_addons_zabbix_export_variables" ] || return 0
  # Directories
  export ZABBIX_TMPL_DIR="$TMPL_DIR/addons/zabbix"
  export ZABBIX_ENV_DIR="$CLUST_ENVS_DIR/zabbix"
  export ZABBIX_HELM_DIR="$CLUST_HELM_DIR/zabbix"
  # Templates
  export ZABBIX_HELM_VALUES_TMPL="$ZABBIX_TMPL_DIR/values.yaml"
  # Files
  export ZABBIX_HELM_VALUES_YAML="$ZABBIX_HELM_DIR/values.yaml"
  # Values
  if [ -z "$ZABBIX_SERVER_HOST" ]; then
    if [ "$CLUSTER_ZABBIX_SERVER_HOST" ]; then
      ZABBIX_SERVER_HOST="$CLUSTER_ZABBIX_SERVER_HOST"
    else
      ZABBIX_SERVER_HOST="$CLUSTER_DEFAULT_ZABBIX_SERVER_HOST"
    fi
  fi
  if [ -z "$ZABBIX_SERVER_PORT" ]; then
    if [ "$CLUSTER_ZABBIX_SERVER_PORT" ]; then
      ZABBIX_SERVER_PORT="$CLUSTER_ZABBIX_SERVER_PORT"
    else
      ZABBIX_SERVER_PORT="$CLUSTER_DEFAULT_ZABBIX_SERVER_PORT"
    fi
  fi
  # Set variable to avoid loading variables twice
  _addons_zabbix_export_variables="1"
}

addons_zabbix_read_variables() {
  _addon="zabbix"
  header "Reading $_addon settings"
  read_value "Zabbix Server Host" "${ZABBIX_SERVER_HOST}"
  ZABBIX_SERVER_HOST=${READ_VALUE}
  read_value "Zabbix Server Port" "${ZABBIX_SERVER_PORT}"
  ZABBIX_SERVER_PORT=${READ_VALUE}
}

addons_zabbix_print_variables() {
  _addon="zabbix"
  cat <<EOF
# Cluster $_addon settings
# ---
# Zabbix server host
ZABBIX_SERVER_HOST=$ZABBIX_SERVER_HOST
# Zabbix server port (default is 10051)
ZABBIX_SERVER_PORT=$ZABBIX_SERVER_PORT
# ---
EOF
}

addons_zabbix_check_directories() {
  for _d in "$ZABBIX_ENV_DIR" "$ZABBIX_HELM_DIR"; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

addons_zabbix_clean_directories() {
  # Try to remove empty dirs, except if they contain secrets
  for _d in "$ZABBIX_ENV_DIR" "$ZABBIX_HELM_DIR"; do
    if [ -d "$_d" ]; then
      rmdir "$_d" 2>/dev/null || true
    fi
  done
}

addons_zabbix_env_edit() {
  if [ "$EDITOR" ]; then
    _addon="zabbix"
    _cluster="$1"
    addons_export_variables "$_cluster"
    _env_file="$ZABBIX_ENV_DIR/$_addon.env"
    if [ -f "$_env_file" ]; then
      "$EDITOR" "$_env_file"
    else
      echo "The '$_env_file' does not exist, use 'env-update' to create it"
      exit 1
    fi
  else
    echo "Export the EDITOR environment variable to use this subcommand"
    exit 1
  fi
}

addons_zabbix_env_path() {
  _addon="zabbix"
  _cluster="$1"
  addons_export_variables "$_cluster"
  _env_file="$ZABBIX_ENV_DIR/$_addon.env"
  echo "$_env_file"
}

addons_zabbix_env_save() {
  _addon="zabbix"
  _cluster="$1"
  _env_file="$2"
  addons_zabbix_check_directories
  addons_zabbix_print_variables "$_cluster" | stdout_to_file "$_env_file"
}

addons_zabbix_env_update() {
  _addon="zabbix"
  _cluster="$1"
  addons_export_variables "$_cluster"
  _env_file="$ZABBIX_ENV_DIR/$_addon.env"
  header "$_addon configuration variables"
  addons_zabbix_print_variables "$_cluster" | grep -v "^#"
  if [ -f "$_env_file" ]; then
    footer
    read_bool "Update $_addon env vars?" "No"
  else
    READ_VALUE="Yes"
  fi
  if is_selected "${READ_VALUE}"; then
    footer
    addons_zabbix_read_variables
    if [ -f "$_env_file" ]; then
      footer
      read_bool "Save updated $_addon env vars?" "Yes"
    else
      READ_VALUE="Yes"
    fi
    if is_selected "${READ_VALUE}"; then
      addons_zabbix_env_save "$_cluster" "$_env_file"
      footer
      echo "$_addon configuration saved to '$_env_file'"
      footer
    fi
  fi
}

addons_zabbix_install() {
  addons_zabbix_export_variables
  addons_zabbix_check_directories
  _addon="zabbix"
  _ns="$ZABBIX_NAMESPACE"
  _repo_name="$ZABBIX_HELM_REPO_NAME"
  _repo_url="$ZABBIX_HELM_REPO_URL"
  _values_tmpl="$ZABBIX_HELM_VALUES_TMPL"
  _values_yaml="$ZABBIX_HELM_VALUES_YAML"
  _release="$ZABBIX_HELM_RELEASE"
  _chart="$ZABBIX_HELM_CHART"
  header "Installing '$_addon'"
  # Check helm repo
  check_helm_repo "$_repo_name" "$_repo_url"
  # Create namespace if needed
  if ! find_namespace "$_ns"; then
    create_namespace "$_ns"
  fi
  # Values for the chart
  sed \
    -e "s%__PULL_SECRETS_NAME__%$CLUSTER_PULL_SECRETS_NAME%" \
    -e "s%__ZABBIX_PROXY_IMAGE_REPOSITORY__%$ZABBIX_PROXY_IMAGE_REPOSITORY%" \
    -e "s%__ZABBIX_PROXY_IMAGE_TAG__%$ZABBIX_PROXY_IMAGE_TAG%" \
    -e "s%__ZABBIX_AGENT2_IMAGE_REPOSITORY__%$ZABBIX_AGENT2_IMAGE_REPOSITORY%" \
    -e "s%__ZABBIX_AGENT2_IMAGE_TAG__%$ZABBIX_AGENT2_IMAGE_TAG%" \
    -e "s%__ZABBIX_SERVER_HOST__%$ZABBIX_SERVER_HOST%" \
    -e "s%__ZABBIX_SERVER_PORT__%$ZABBIX_SERVER_PORT%" \
    "$_values_tmpl" >"$_values_yaml"
  # Update or install chart
  helm_upgrade "$_ns" "$_values_yaml" "$_release" "$_chart"
  footer
}

addons_zabbix_remove() {
  addons_zabbix_export_variables
  _addon="zabbix"
  _ns="$ZABBIX_NAMESPACE"
  _values_yaml="$ZABBIX_HELM_VALUES_YAML"
  _release="$ZABBIX_HELM_RELEASE"
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
  addons_zabbix_clean_directories
}

addons_zabbix_status() {
  addons_zabbix_export_variables
  _addon="zabbix"
  _ns="$ZABBIX_NAMESPACE"
  _release="$ZABBIX_HELM_RELEASE"
  if find_namespace "$_ns"; then
    kubectl get all,endpoints,ingress,secrets -n "$_ns" \
      -l "release=$_release"
  else
    echo "Namespace '$_ns' for '$_addon' not found!"
  fi
}

addons_zabbix_summary() {
  addons_zabbix_export_variables
  _addon="zabbix"
  _ns="$ZABBIX_NAMESPACE"
  _release="$ZABBIX_HELM_RELEASE"
  print_helm_summary "$_ns" "$_addon" "$_release"
}

addons_zabbix_command() {
  _command="$1"
  _cluster="$2"
  case "$_command" in
  env-edit | env_edit)
    addons_zabbix_env_edit "$_cluster"
    ;;
  env-path | env_path)
    addons_zabbix_env_path "$_cluster"
    ;;
  env-show | env_show)
    addons_zabbix_print_variables "$_cluster" | grep -v '^#'
    ;;
  env-update | env_update)
    addons_zabbix_env_update "$_cluster"
    ;;
  install) addons_zabbix_install ;;
  remove) addons_zabbix_remove ;;
  status) addons_zabbix_status ;;
  summary) addons_zabbix_summary ;;
  *)
    echo "Unknown zabbix subcommand '$1'"
    exit 1
    ;;
  esac
}

addons_zabbix_command_list() {
  echo "env-edit env-path env-show env-update install remove status summary"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
