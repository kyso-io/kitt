#!/bin/sh
# ----
# File:        apps/common.sh
# Description: Functions to configure common kyso variables
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_APPS_COMMON_SH="1"

# ---------
# Variables
# ---------

# Deployment defaults
export DEPLOYMENT_DEFAULT_HOSTNAMES="lo.kyso.io"
export DEPLOYMENT_DEFAULT_IMAGE_PULL_POLICY="Always"
export DEPLOYMENT_DEFAULT_INGRESS_TLS_CERTS="false"
export DEPLOYMENT_DEFAULT_PF_ADDR="127.0.0.1"

# Fixed values
export KUBE_STACK_RELEASE="kube-stack"

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

apps_common_export_variables() {
  [ -z "$__apps_common_export_variables" ] || return 0
  _deployment="$1"
  _cluster="$2"
  deployment_export_variables "$_deployment" "$_cluster"
  # Directories
  export DEPLOYMENT_CERTS_DIR="$DEPLOY_SECRETS_DIR/certs"
  # Use defaults for variables missing from config files
  [ "$DEPLOYMENT_HOSTNAMES" ] ||
    export DEPLOYMENT_HOSTNAMES="$DEPLOYMENT_DEFAULT_HOSTNAMES"
  [ "$DEPLOYMENT_IMAGE_PULL_POLICY" ] ||
    export DEPLOYMENT_IMAGE_PULL_POLICY="$DEPLOYMENT_DEFAULT_IMAGE_PULL_POLICY"
  [ "$DEPLOYMENT_INGRESS_TLS_CERTS" ] ||
    export DEPLOYMENT_INGRESS_TLS_CERTS="$DEPLOYMENT_DEFAULT_INGRESS_TLS_CERTS"
  [ "$DEPLOYMENT_PF_ADDR" ] ||
    export DEPLOYMENT_PF_ADDR="$DEPLOYMENT_DEFAULT_PF_ADDR"
  __apps_common_export_variables="1"
}

apps_common_check_directories() {
  deployment_check_directories
}

apps_common_print_variables() {
  cat << EOF
# KITT Deployment config file
# ---
# Common variables
# ---
# Deployment name
NAME=$DEPLOYMENT_NAME
# Space separated list of hostnames for this deployment, usually one is enough
HOSTNAMES=$DEPLOYMENT_HOSTNAMES
# Image pull policy for the deployment, for development use Always or use
# always fixed tags to avoid surprises
IMAGE_PULL_POLICY=$DEPLOYMENT_IMAGE_PULL_POLICY
# Add certificates to each ingress definition, try to avoid it, is better to
# have a wildcard certificate on the ingress server
INGRESS_TLS_CERTS=$DEPLOYMENT_INGRESS_TLS_CERTS
# IP Address for port-forward, 127.0.0.1 for local dev and 0.0.0.0 if you need
# to access the services from a machine different than the docker host
PF_ADDR=$DEPLOYMENT_PF_ADDR
# ---
EOF
}

apps_common_read_variables() {
  header "Common Settings"
  read_value "Space separated list of ingress hostnames" \
    "${DEPLOYMENT_HOSTNAMES}"
  DEPLOYMENT_HOSTNAMES=${READ_VALUE}
  read_value "imagePullPolicy ('Always'/'IfNotPresent')" \
    "${DEPLOYMENT_IMAGE_PULL_POLICY}"
  DEPLOYMENT_IMAGE_PULL_POLICY=${READ_VALUE}
  read_bool "Add TLS certificates to the ingress definitions?" \
    "${DEPLOYMENT_INGRESS_TLS_CERTS}"
  DEPLOYMENT_INGRESS_TLS_CERTS=${READ_VALUE}
  read_value "Port forward IP address" \
    "${DEPLOYMENT_PF_ADDR}"
  DEPLOYMENT_PF_ADDR=${READ_VALUE}
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
