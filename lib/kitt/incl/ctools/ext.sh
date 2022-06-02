#!/bin/sh
# ----
# File:        ctools/ext.sh
# Description: Functions to configure external clusters to use with kitt.
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_CTOOLS_EXT_SH="1"

# ---------
# Variables
# ---------

# CMND_DSC="ext: configure clusters not managed with this tool"

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

ctool_ext_export_variables() {
  # Check if we need to run the function
  [ -z "$__ctool_ext_export_variables" ] || return 0
  _cluster="$1"
  cluster_export_variables "$_cluster"
  # set variable to avoid running the function twice
  __ctool_ext_export_variables="1"
}

ctool_ext_check_directories() {
  cluster_check_directories
}

ctool_ext_read_variables() {
  read_value "Cluster DNS Domain" "${CLUSTER_DOMAIN}"
  CLUSTER_DOMAIN=${READ_VALUE}
  read_bool "Keep cluster data in git" "${CLUSTER_DATA_IN_GIT}"
  CLUSTER_DATA_IN_GIT=${READ_VALUE}
  read_bool "Add pull secrets to namespaces" "${CLUSTER_PULL_SECRETS_IN_NS}"
  CLUSTER_PULL_SECRETS_IN_NS=${READ_VALUE}
  read_bool "Force SSL redirect on ingress" "${CLUSTER_FORCE_SSL_REDIRECT}"
  CLUSTER_FORCE_SSL_REDIRECT=${READ_VALUE}
  read_bool "Use basic auth" "${CLUSTER_USE_BASIC_AUTH}"
  CLUSTER_USE_BASIC_AUTH=${READ_VALUE}
  read_bool "Use SOPS" "${CLUSTER_USE_SOPS}"
  CLUSTER_USE_SOPS=${READ_VALUE}
  if is_selected "$CLUSTER_USE_SOPS"; then
    export SOPS_EXT="${APP_DEFAULT_SOPS_EXT}"
  else
    export SOPS_EXT=""
  fi
}

ctool_ext_print_variables() {
  cat <<EOF
# KITT External Cluster Configuration File
# ---
# Cluster name
NAME=$CLUSTER_NAME
# Cluster kind (one of eks, ext or k3d for now)
KIND=$CLUSTER_KIND
# Public DNS domain used with the cluster ingress by default
DOMAIN=$CLUSTER_DOMAIN
# Force SSL redirect on ingress
FORCE_SSL_REDIRECT=$CLUSTER_FORCE_SSL_REDIRECT
# Keep cluster data in git or not
CLUSTER_DATA_IN_GIT=$CLUSTER_DATA_IN_GIT
# Enable to add credentials to namespaces to pull images from a private registry
PULL_SECRETS_IN_NS=$CLUSTER_PULL_SECRETS_IN_NS
# Enable basic auth for sensible services (disable only on dev deployments)
USE_BASIC_AUTH=$CLUSTER_USE_BASIC_AUTH
# Use sops to encrypt files (needs a ~/.sops.yaml file to be useful)
USE_SOPS=$CLUSTER_USE_SOPS
EOF
}

ctool_ext_remove() {
  _cluster="$1"
  ctool_ext_export_variables "$_cluster"
  cluster_remove_directories
}

ctool_ext_status() {
  _cluster="$1"
  ctool_ext_export_variables "$_cluster"
  kubectl 
}

# ----
# vim: ts=2:sw=2:et:ai:sts=3
