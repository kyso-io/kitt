#!/bin/sh
# ----
# File:        registry
# Description: Functions to load and update registry credentials
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_REGISTRY_SH="1"

# --------
# Includes
# --------

if [ -d "$INCL_DIR" ]; then
  # shellcheck source=./io.sh
  [ "$INCL_COMMON_IO_SH" = "1" ] || . "$INCL_DIR/common/io.sh"
  # shellcheck source=./cluster.sh
  [ "$INCL_COMMON_CLUSTER_SH" = "1" ] || . "$INCL_DIR/common/cluster.sh"
fi

# ---------
# Functions
# ---------

export_registry_variables() {
  # Load cluster variables
  _cluster="$1"
  cluster_export_variables "$_cluster"
  # Files
  export REMOTE_REGISTRY_ENV="$CLUST_SECRETS_DIR/registry${SOPS_EXT}.env"
}

check_registry_directories() {
  for _d in "$CLUST_KUBECTL_DIR" "$CLUST_SECRETS_DIR"; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

load_registry_conf() {
  export_registry_variables "$_cluster"
  if [ -f "$REMOTE_REGISTRY_ENV" ]; then
    export REMOTE_REGISTRY_NAME=""
    export REMOTE_REGISTRY_URL=""
    export REMOTE_REGISTRY_USER=""
    export REMOTE_REGISTRY_PASS=""
    export_env_file_vars "$REMOTE_REGISTRY_ENV" "REMOTE"
  else
    echo "File '$REMOTE_REGISTRY_ENV' not found"
    echo "Call the cluster 'config' command to create it"
    exit 1
  fi
}

update_registry_conf() {
  _cluster="$1"
  export_registry_variables "$_cluster"
  if [ -f "$REMOTE_REGISTRY_ENV" ]; then
    load_registry_conf
    read_value "Remote registry configuration found, update it? ${yes_no}" "No"
    if is_selected "${READ_VALUE}"; then
      footer
    fi
  else
    READ_VALUE="Yes"
    echo "Remote registry configuration not found, configuring it now!"
  fi
  if is_selected "${READ_VALUE}"; then
    header "Configuring remote registry"
    read_value "Registry NAME" "${REMOTE_REGISTRY_NAME}"
    REMOTE_REGISTRY_NAME=${READ_VALUE}
    [ "${REGISTRY_URL}" ] || REGISTRY_URL="https://${REMOTE_REGISTRY_NAME}"
    read_value "Registry URL" "${REMOTE_REGISTRY_URL}"
    REMOTE_REGISTRY_URL=${READ_VALUE}
    read_value "Registry USER" "${REMOTE_REGISTRY_USER}"
    REMOTE_REGISTRY_USER=${READ_VALUE}
    read_value "Registry PASS" "${REMOTE_REGISTRY_PASS}"
    REMOTE_REGISTRY_PASS=${READ_VALUE}
    if [ -f "$REMOTE_REGISTRY_ENV" ]; then
      read_value "Save registry configuration? ${yes_no}" "Yes"
    else
      READ_VALUE="Yes"
    fi
    if is_selected "${READ_VALUE}"; then
      check_registry_directories "$_cluster"
      stdout_to_file "$REMOTE_REGISTRY_ENV" <<EOF
REGISTRY_NAME=$REMOTE_REGISTRY_NAME
REGISTRY_URL=$REMOTE_REGISTRY_URL
REGISTRY_USER=$REMOTE_REGISTRY_USER
REGISTRY_PASS=$REMOTE_REGISTRY_PASS
EOF
      footer
      echo "Configuration saved to '$REMOTE_REGISTRY_ENV'"
    fi
  fi
  footer
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
