#!/bin/sh
# ----
# File:        dam/common.sh
# Description: Functions to configure common dam variables
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2023 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_DAM_COMMON_SH="1"

# ---------
# Variables
# ---------

# CMND_DSC="common: manage common deployment settings for kyso dam"

# Deployment defaults
export DEPLOYMENT_DEFAULT_IMAGE_PULL_POLICY="Always"
export DEPLOYMENT_DEFAULT_INGRESS_TLS_CERTS="false"
export DEPLOYMENT_DEFAULT_INGRESS_USE_TLS_CERTS="false"
export DEPLOYMENT_DEFAULT_PF_ADDR="127.0.0.1"

# --------
# Includes
# --------

if [ -d "$INCL_DIR" ]; then
  # shellcheck source=../common.sh
  [ "$INCL_COMMON_SH" = "1" ] || . "$INCL_DIR/common.sh"
  # shellcheck source=./kyso-dam.sh
  [ "$INCL_DAM_KYSO_DAM_SH" = "1" ] || . "$INCL_DIR/dam/kyso-dam.sh"
  # shellcheck source=./zot.sh
  [ "$INCL_DAM_ZOT_SH" = "1" ] || . "$INCL_DIR/dam/zot.sh"
  # shellcheck source=../apps/kyso-api.sh
  [ "$INCL_APPS_KYSO_API_SH" = "1" ] || . "$INCL_DIR/apps/kyso-api.sh"
fi

# ---------
# Functions
# ---------

dam_common_export_variables() {
  [ -z "$__dam_common_export_variables" ] || return 0
  _deployment="$1"
  _cluster="$2"
  deployment_export_variables "$_deployment" "$_cluster"
  # Directories
  export DEPLOYMENT_CERTS_DIR="$DEPLOY_SECRETS_DIR/certs"
  # Use defaults for variables missing from config files
  [ "$DEPLOYMENT_APP_DOMAIN" ] ||
    export DEPLOYMENT_APP_DOMAIN="app.$CLUSTER_DOMAIN"
  [ "$DEPLOYMENT_IMAGE_PULL_POLICY" ] ||
    export DEPLOYMENT_IMAGE_PULL_POLICY="$DEPLOYMENT_DEFAULT_IMAGE_PULL_POLICY"
  [ "$DEPLOYMENT_INGRESS_TLS_CERTS" ] ||
    export DEPLOYMENT_INGRESS_TLS_CERTS="$DEPLOYMENT_DEFAULT_INGRESS_TLS_CERTS"
  if is_selected "$DEPLOYMENT_INGRESS_TLS_CERTS"; then
    _use_tls_certs="true"
  else
    _use_tls_certs="$DEPLOYMENT_INGRESS_USE_TLS_CERTS"
    [ "$_use_tls_certs" ] ||
      _use_tls_certs="$DEPLOYMENT_DEFAULT_INGRESS_USE_TLS_CERTS"
  fi
  export DEPLOYMENT_INGRESS_USE_TLS_CERTS="$_use_tls_certs"
  [ "$DEPLOYMENT_PF_ADDR" ] ||
    export DEPLOYMENT_PF_ADDR="$DEPLOYMENT_DEFAULT_PF_ADDR"
  __dam_common_export_variables="1"
}

dam_common_check_directories() {
  deployment_check_directories
}

dam_common_print_variables() {
  _app="dam-common"
  cat <<EOF
# $_app deployment common settings
# ---
# Domain for apps, to work as expected must be a subdomain of the kyso domain
APP_DOMAIN=$DEPLOYMENT_APP_DOMAIN
# Image pull policy for the deployment, for development use Always or use
# always fixed tags to avoid surprises
IMAGE_PULL_POLICY=$DEPLOYMENT_IMAGE_PULL_POLICY
# Manage TLS certificates for each ingress definition (the system is in charge
# of creating them)
INGRESS_TLS_CERTS=$DEPLOYMENT_INGRESS_TLS_CERTS
# Use certificates on each ingress definition (true by default if
# INGRESS_TLS_CERTS is set, can be useful without local management if using
# cert-manager)
INGRESS_USE_TLS_CERTS=$DEPLOYMENT_INGRESS_USE_TLS_CERTS
# IP Address for port-forward, 127.0.0.1 for local dev and 0.0.0.0 if you need
# to access the services from a machine different than the docker host
PF_ADDR=$DEPLOYMENT_PF_ADDR
# ---
EOF
}

dam_common_read_variables() {
  header "Common Settings"
  read_value "Apps domain" "${DEPLOYMENT_APP_DOMAIN}"
  DEPLOYMENT_APP_DOMAIN=${READ_VALUE}
  read_value "imagePullPolicy ('Always'/'IfNotPresent')" \
    "${DEPLOYMENT_IMAGE_PULL_POLICY}"
  DEPLOYMENT_IMAGE_PULL_POLICY=${READ_VALUE}
  read_bool "Manage TLS certificates for the ingress definitions?" \
    "${DEPLOYMENT_INGRESS_TLS_CERTS}"
  DEPLOYMENT_INGRESS_TLS_CERTS=${READ_VALUE}
  if is_selected "$DEPLOYMENT_INGRESS_TLS_CERTS"; then
    DEPLOYMENT_INGRESS_USE_TLS_CERTS="true"
  else
    read_bool "Use TLS certificates on ingress definitions (cert-manager)?" \
      "${DEPLOYMENT_INGRESS_USE_TLS_CERTS}"
    DEPLOYMENT_INGRESS_USE_TLS_CERTS=${READ_VALUE}
  fi
  read_value "Port forward IP address" \
    "${DEPLOYMENT_PF_ADDR}"
  DEPLOYMENT_PF_ADDR=${READ_VALUE}
}

dam_common_env_edit() {
  if [ "$EDITOR" ]; then
    _app="dam-common"
    _deployment="$1"
    _cluster="$2"
    dam_export_variables "$_deployment" "$_cluster"
    _env_file="$DEPLOY_ENVS_DIR/$_app.env"
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

dam_common_env_path() {
  _app="dam-common"
  _deployment="$1"
  _cluster="$2"
  dam_export_variables "$_deployment" "$_cluster"
  _env_file="$DEPLOY_ENVS_DIR/$_app.env"
  echo "$_env_file"
}

dam_common_env_save() {
  _app="dam-common"
  _deployment="$1"
  _cluster="$2"
  _env_file="$3"
  dam_common_check_directories
  dam_common_print_variables "$_deployment" "$_cluster" |
    stdout_to_file "$_env_file"
}

dam_common_env_update() {
  _app="dam-common"
  _deployment="$1"
  _cluster="$2"
  dam_export_variables "$_deployment" "$_cluster"
  _env_file="$DEPLOY_ENVS_DIR/$_app.env"
  header "$_app config variables"
  dam_common_print_variables "$_deployment" "$_cluster" |
    grep -v "^#"
  if [ -f "$_env_file" ]; then
    footer
    [ "$KITT_AUTOUPDATE" = "true" ] && _update="Yes" || _update="No"
    read_bool "Update $_app env vars?" "$_update"
  else
    READ_VALUE="Yes"
  fi
  if is_selected "${READ_VALUE}"; then
    footer
    dam_common_read_variables
    if [ -f "$_env_file" ]; then
      footer
      read_bool "Save updated $_app env vars?" "Yes"
    else
      READ_VALUE="Yes"
    fi
    if is_selected "${READ_VALUE}"; then
      dam_common_env_save "$_deployment" "$_cluster" "$_env_file"
      footer
      echo "$_app configuration saved to '$_env_file'"
      footer
    fi
  fi
}

dam_common_export_service_hostnames() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_api_export_variables "$_deployment" "$_cluster"
  dam_kyso_dam_export_variables "$_deployment" "$_cluster"
  dam_zot_export_variables "$_deployment" "$_cluster"
  KYSO_API_SVC_HOSTNAME="kyso-api.$KYSO_API_NAMESPACE.svc.cluster.local"
  export KYSO_API_SVC_HOSTNAME
  KYSO_DAM_SVC_HOSTNAME="kyso-dam.$KYSO_DAM_NAMESPACE.svc.cluster.local"
  export KYSO_DAM_SVC_HOSTNAME
}

dam_common_command() {
  _command="$1"
  _deployment="$2"
  _cluster="$3"
  case "$_command" in
  env-edit | env_edit)
    dam_common_env_edit "$_deployment" "$_cluster"
    ;;
  env-path | env_path)
    dam_common_env_path "$_deployment" "$_cluster"
    ;;
  env-show | env_show)
    dam_common_print_variables "$_deployment" "$_cluster" | grep -v '^#'
    ;;
  env-update | env_update)
    dam_common_env_update "$_deployment" "$_cluster"
    ;;
  *)
    echo "Unknown common subcommand '$1'"
    exit 1
    ;;
  esac
}

dam_common_command_list() {
  echo "env-edit env-path env-show env-update"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
