#!/bin/sh
# ----
# File:        apps/common.sh
# Description: Functions to configure common kyso variables
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022-2023 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_APPS_COMMON_SH="1"

# ---------
# Variables
# ---------

# CMND_DSC="common: manage common deployment settings for kyso"

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
  # shellcheck source=../mongo.sh
  [ "$INCL_MONGO_SH" = "1" ] || . "$INCL_DIR/mongo.sh"
  # shellcheck source=./elasticsearch.sh
  [ "$INCL_APPS_ELASTICSEARCH_SH" = "1" ] || . "$INCL_DIR/apps/elasticsearch.sh"
  # shellcheck source=./kyso-api.sh
  [ "$INCL_APPS_KYSO_API_SH" = "1" ] || . "$INCL_DIR/apps/kyso-api.sh"
  # shellcheck source=./kyso-scs.sh
  [ "$INCL_APPS_KYSO_SCS_SH" = "1" ] || . "$INCL_DIR/apps/kyso-scs.sh"
  # shellcheck source=./mongodb.sh
  [ "$INCL_APPS_MONGODB_SH" = "1" ] || . "$INCL_DIR/apps/mongodb.sh"
  # shellcheck source=./nats.sh
  [ "$INCL_APPS_NATS_SH" = "1" ] || . "$INCL_DIR/apps/nats.sh"
  # shellcheck source=./kyso-nbdime.sh
  [ "$INCL_APPS_KYSO_NBDIME_SH" = "1" ] || . "$INCL_DIR/apps/kyso-nbdime.sh"
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

apps_common_read_variables() {
  header "Common Settings"
  read_value "Space separated list of ingress hostnames" \
    "${DEPLOYMENT_HOSTNAMES}"
  DEPLOYMENT_HOSTNAMES=${READ_VALUE}
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

apps_common_env_edit() {
  if [ "$EDITOR" ]; then
    _app="common"
    _deployment="$1"
    _cluster="$2"
    apps_export_variables "$_deployment" "$_cluster"
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

apps_common_env_path() {
  _app="common"
  _deployment="$1"
  _cluster="$2"
  apps_export_variables "$_deployment" "$_cluster"
  _env_file="$DEPLOY_ENVS_DIR/$_app.env"
  echo "$_env_file"
}

apps_common_env_save() {
  _app="common"
  _deployment="$1"
  _cluster="$2"
  _env_file="$3"
  apps_common_check_directories
  apps_common_print_variables "$_deployment" "$_cluster" |
    stdout_to_file "$_env_file"
}

apps_common_env_update() {
  _app="common"
  _deployment="$1"
  _cluster="$2"
  apps_export_variables "$_deployment" "$_cluster"
  _env_file="$DEPLOY_ENVS_DIR/$_app.env"
  header "$_app config variables"
  apps_common_print_variables "$_deployment" "$_cluster" |
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
    apps_common_read_variables
    if [ -f "$_env_file" ]; then
      footer
      read_bool "Save updated $_app env vars?" "Yes"
    else
      READ_VALUE="Yes"
    fi
    if is_selected "${READ_VALUE}"; then
      apps_common_env_save "$_deployment" "$_cluster" "$_env_file"
      footer
      echo "$_app configuration saved to '$_env_file'"
      footer
    fi
  fi
}

apps_common_export_service_hostnames() {
  _deployment="$1"
  _cluster="$2"
  apps_elasticsearch_export_variables "$_deployment" "$_cluster"
  apps_kyso_scs_export_variables "$_deployment" "$_cluster"
  apps_mongodb_export_variables "$_deployment" "$_cluster"
  apps_nats_export_variables "$_deployment" "$_cluster"
  _elasticsearch_svc_domain="$ELASTICSEARCH_NAMESPACE.svc.cluster.local"
  ELASTICSEARCH_SVC_HOSTNAME="elasticsearch-master.$_elasticsearch_svc_domain"
  export ELASTICSEARCH_SVC_HOSTNAME
  KYSO_API_SVC_HOSTNAME="kyso-api.$KYSO_API_NAMESPACE.svc.cluster.local"
  export KYSO_API_SVC_HOSTNAME
  KYSO_SCS_SVC_HOSTNAME="kyso-scs.$KYSO_SCS_NAMESPACE.svc.cluster.local"
  export KYSO_SCS_SVC_HOSTNAME
  _mongodb_svc_domain="$MONGODB_NAMESPACE.svc.cluster.local"
  MONGODB_SVC_HOSTNAME="$MONGODB_HELM_RELEASE-headless.$_mongodb_svc_domain"
  if [ "$MONGODB_ARCHITECTURE" = "replicaset" ]; then
    MONGODB_SVC_HOSTNAME="$MONGODB_HELM_RELEASE-0.$MONGODB_SVC_HOSTNAME"
  fi
  export MONGODB_SVC_HOSTNAME
  NATS_SVC_HOSTNAME="$NATS_HELM_RELEASE.$NATS_NAMESPACE.svc.cluster.local"
  export NATS_SVC_HOSTNAME
  _kyso_nbdime_svc_domain="$KYSO_NBDIME_NAMESPACE.svc.cluster.local"
  KYSO_NBDIME_SVC_HOSTNAME="kyso-nbdime.$_kyso_nbdime_svc_domain"
  export KYSO_NBDIME_SVC_HOSTNAME
}

apps_kyso_print_api_settings() {
  ret="0"
  _deployment="$1"
  _cluster="$2"
  apps_kyso_api_export_variables "$_deployment" "$_cluster"
  if [ "$KYSO_API_ENDPOINT" ]; then
    ELASTICSEARCH_SVC_HOSTNAME="elasticsearch"
    KYSO_SCS_SVC_HOSTNAME="kyso-scs"
    MONGODB_SVC_HOSTNAME="mongodb"
    NATS_SVC_HOSTNAME="nats"
    KYSO_NBDIME_SVC_HOSTNAME="kyso-nbdime"
    _sftp_port="2020"
  else
    apps_common_export_service_hostnames "$_deployment" "$_cluster"
    _sftp_port="22"
  fi
  # Common variables
  _base_url="https://${DEPLOYMENT_HOSTNAMES%% *}"
  _frontend_url="https://${DEPLOYMENT_HOSTNAMES%% *}"
  # Elastic vars
  _elastic_url="http://$ELASTICSEARCH_SVC_HOSTNAME:9200"
  # SCS Vars
  _sftp_host="$KYSO_SCS_SVC_HOSTNAME"
  _kyso_indexer_api_base_url="http://$KYSO_SCS_SVC_HOSTNAME:8080"
  _user_pass_txt="$(
    apps_kyso_scs_secret_cat_file "user_pass.txt" "$_deployment" "$_cluster"
  )"
  if [ "$_user_pass_txt" ]; then

    _user_and_pass="$(
      echo "$_user_pass_txt" | grep "^$KYSO_SCS_SFTP_SCS_USER:"
    )" || true
    _sftp_username="${_user_and_pass%%:*}"
    _sftp_password="${_user_and_pass#*:}"
    _pub_user_and_pass="$(
      echo "$_user_pass_txt" | grep "^$KYSO_SCS_SFTP_PUB_USER:"
    )" || true
    _sftp_pub_username="${_pub_user_and_pass%%:*}"
    _sftp_pub_password="${_pub_user_and_pass#*:}"
  else
    _sftp_username=""
    _sftp_password=""
    _sftp_pub_username=""
    _sftp_pub_password=""
  fi
  _sftp_destination_folder=""
  _static_content_prefix="/scs"
  _content_pub_prefix="/pub"
  # NATS Vars
  _nats_url="nats://$NATS_SVC_HOSTNAME:$NATS_PORT"
  # WEBHOOK Vars
  _webhook_url="http://$KYSO_SCS_SVC_HOSTNAME:9000"
  # KYSO_NBDIME Vars
  _kyso_nbdime_url="http://$KYSO_NBDIME_SVC_HOSTNAME:$KYSO_NBDIME_PORT"
  # Print values
  cat <<EOF
BASE_URL,$_base_url
FRONTEND_URL,$_frontend_url
ELASTICSEARCH_URL,$_elastic_url
SFTP_HOST,$_sftp_host
SFTP_PORT,$_sftp_port
SFTP_USERNAME,$_sftp_username
SFTP_PASSWORD,$_sftp_password
SFTP_DESTINATION_FOLDER,$_sftp_destination_folder
STATIC_CONTENT_PREFIX,$_static_content_prefix
SFTP_PUBLIC_USERNAME,$_sftp_pub_username
SFTP_PUBLIC_PASSWORD,$_sftp_pub_password
STATIC_CONTENT_PUBLIC_PREFIX,$_content_pub_prefix
KYSO_INDEXER_API_BASE_URL,$_kyso_indexer_api_base_url
KYSO_NATS_URL,$_nats_url
KYSO_WEBHOOK_URL,$_webhook_url
KYSO_NBDIME_URL,$_kyso_nbdime_url
EOF
}

apps_kyso_update_api_settings() {
  ret="0"
  _deployment="$1"
  _cluster="$2"
  apps_kyso_api_export_variables "$_deployment" "$_cluster"
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
  # Prepare sed commands to replace the variables on the settings file
  _sed_commands="$(
    apps_kyso_print_api_settings "$_deployment" "$_cluster" | sed -e 's/,/ /' |
      while read -r _k _v; do
        printf "s|^%s,.*$|%s,%s|;\n" "$_k" "$_k" "$_v"
      done
  )"
  echo "$_sed_commands" | sed -f - "$_settings_csv" >"$_settings_new"
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
  env-show | env_show)
    apps_common_print_variables "$_deployment" "$_cluster" | grep -v '^#'
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
  echo "env-edit env-path env-show env-update"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
