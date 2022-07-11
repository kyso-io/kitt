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
export DEPLOYMENT_DEFAULT_IMAGE_PULL_POLICY="Always"
export DEPLOYMENT_DEFAULT_INGRESS_TLS_CERTS="false"
export DEPLOYMENT_DEFAULT_PF_ADDR="127.0.0.1"

# --------
# Includes
# --------

if [ -d "$INCL_DIR" ]; then
  # shellcheck source=../common.sh
  [ "$INCL_COMMON_SH" = "1" ] || . "$INCL_DIR/common.sh"
  # shellcheck source=../mongo.sh
  [ "$INCL_MONGO_SH" = "1" ] || . "$INCL_DIR/mongo.sh"
  # shellcheck source=./kyso-scs.sh
  [ "$INCL_APPS_KYSO_SCS_SH" = "1" ] || . "$INCL_DIR/apps/kyso-scs.sh"
  # shellcheck source=./nats.sh
  [ "$INCL_APPS_NATS_SH" = "1" ] || . "$INCL_DIR/apps/nats.sh"
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
    export DEPLOYMENT_HOSTNAMES="$CLUSTER_DOMAIN"
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
  _app="common"
  cat <<EOF
# Deployment $_app settings
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

apps_common_env_edit() {
  if [ "$EDITOR" ]; then
    _app="common"
    _deployment="$1"
    _cluster="$2"
    apps_export_variables "$_deployment" "$_cluster"
    _env_file="$DEPLOYMENT_CONFIG"
    if [ -f "$_env_file" ]; then
      exec "$EDITOR" "$_env_file"
    else
      echo "The '$_env_file' does not exist, use 'env-update' to create it"
      exit 1
    fi
  else
    echo "Export the EDITOR environment variable to use this subcommand"
    exit 1
  fi
}

apps_common_env_path() {
  _app="common"
  _deployment="$1"
  _cluster="$2"
  apps_export_variables "$_deployment" "$_cluster"
  _env_file="$DEPLOYMENT_CONFIG"
  echo "$_env_file"
}

apps_common_env_update() {
  _app="common"
  _deployment="$1"
  _cluster="$2"
  apps_export_variables "$_deployment" "$_cluster"
  _env_file="$DEPLOYMENT_CONFIG"
  header "$_app config variables"
  apps_common_print_variables "$_deployment" "$_cluster" |
    grep -v "^#"
  if [ -f "$_env_file" ]; then
    footer
    read_bool "Update $_app env vars?" "No"
  else
    READ_VALUE="Yes"
  fi
  if is_selected "${READ_VALUE}"; then
    footer
    apps_common_read_variables
    if [ -f "$_env_file" ]; then
      footer
      read_bool "Save updated $_app env vars?" "Yes"
    else
      READ_VALUE="Yes"
    fi
    if is_selected "${READ_VALUE}"; then
      apps_check_directories
      apps_print_variables "$_deployment" "$_cluster" |
        stdout_to_file "$_env_file"
      footer
      echo "$_app configuration saved to '$_env_file'"
      footer
    fi
  fi
}

apps_kyso_update_api_settings() {
  ret="0"
  _deployment="$1"
  _cluster="$2"
  apps_kyso_scs_export_variables "$_deployment" "$_cluster"
  apps_nats_export_variables "$_deployment" "$_cluster"
  _tmp_dir="$(mktemp -d)"
  chmod 0700 "$_tmp_dir"
  _settings_csv="$_tmp_dir/KysoSettings.csv"
  _settings_err="$_tmp_dir/KysoSettings.err"
  _settings_new="$_tmp_dir/KysoSettings.new"
  mongo_command settings-export "$_settings_csv" "$_deployment" "$_cluster" \
    2>"$_settings_err" || ret="$?"
  if [ "$ret" -ne "0" ]; then
    cat "$_settings_err" 1>&2
    rm -rf "$_tmp_dir"
    return "$ret"
  fi
  # Common variables
  _base_url="https://${DEPLOYMENT_HOSTNAMES%% *}"
  _frontend_url="https://${DEPLOYMENT_HOSTNAMES%% *}"
  # SCS Vars
  _sftp_host="kyso-scs-svc.$KYSO_SCS_NAMESPACE.svc.cluster.local"
  _sftp_port="22"
  _kyso_indexer_api_host="kyso-scs-svc.$KYSO_SCS_NAMESPACE.svc.cluster.local"
  _kyso_indexer_api_base_url="http://$_kyso_indexer_api_host:8080"
  if [ -f "$KYSO_SCS_USERS_TAR" ]; then
    _user_and_pass="$(
      file_to_stdout "$KYSO_SCS_USERS_TAR" | tar xOf - user_pass.txt
    )"
    _sftp_username="$(echo "$_user_and_pass" | cut -d':' -f1)"
    _sftp_password="$(echo "$_user_and_pass" | cut -d':' -f2)"
  else
    _sftp_username=""
    _sftp_password=""
  fi
  _sftp_destination_folder=""
  _static_content_prefix="/scs"
  # NATS Vars
  _nats_url="nats://$NATS_RELEASE.$NATS_NAMESPACE.svc.cluster.local:$NATS_PORT"
  # Replace values
  sed \
    -e "s%^\(BASE_URL\),.*%\1,$_base_url%" \
    -e "s%^\(FRONTEND_URL\),.*%\1,$_frontend_url%" \
    -e "s%^\(SFTP_HOST\),.*$%\1,$_sftp_host%" \
    -e "s%^\(SFTP_PORT\),.*$%\1,$_sftp_port%" \
    -e "s%^\(SFTP_USERNAME\),.*$%\1,$_sftp_username%" \
    -e "s%^\(SFTP_PASSWORD\),.*$%\1,$_sftp_password%" \
    -e "s%^\(SFTP_DESTINATION_FOLDER\),.*$%\1,$_sftp_destination_folder%" \
    -e "s%^\(STATIC_CONTENT_PREFIX\),.*$%\1,$_static_content_prefix%" \
    -e "s%^\(KYSO_INDEXER_API_BASE_URL\),.*$%\1,$_kyso_indexer_api_base_url%" \
    -e "s%^\(KYSO_NATS_URL\),.*$%\1,$_nats_url%" \
    "$_settings_csv" >"$_settings_new"
  DIFF_OUT="$(diff -U 0 "$_settings_csv" "$_settings_new")" || true
  if [ "$DIFF_OUT" ]; then
    echo "Updating KysoSettings:"
    echo "$DIFF_OUT" | grep '^[-+][^-+]'
    mongo_command settings-merge "$_settings_new" 2>"$_settings_err" || ret="$?"
    if [ "$ret" -ne "0" ]; then
      cat "$_settings_err" 1>&2
    fi
  fi
  rm -rf "$_tmp_dir"
  return "$ret"
}

apps_common_command() {
  _command="$1"
  _deployment="$2"
  _cluster="$3"
  case "$_command" in
  env-edit | env_edit)
    apps_common_env_edit "$_deployment" "$_cluster"
    ;;
  env-path | env_path)
    apps_common_env_path "$_deployment" "$_cluster"
    ;;
  env-update | env_update)
    apps_common_env_update "$_deployment" "$_cluster"
    ;;
  *)
    echo "Unknown common subcommand '$1'"
    exit 1
    ;;
  esac
}

apps_common_command_list() {
  echo "env-edit env-path env-update"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
