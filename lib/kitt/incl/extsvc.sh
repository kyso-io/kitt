#!/bin/sh
# ----
# File:        extsvc.sh
# Description: Functions to manage ingress configs for external services
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022-2023 Kyso Inc.
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_EXTSVC_SH="1"

# ---------
# Variables
# ---------

# extsvc defaults
export APP_DEFAULT_EXTSVC_NAMESPACE="ingress"
export APP_DEFAULT_EXTSVC_EXTERNAL_HOST=""
export APP_DEFAULT_EXTSVC_INTERNAL_PORT="80"
export APP_DEFAULT_EXTSVC_SERVER_ADDR=""
export APP_DEFAULT_EXTSVC_SERVER_PORT="80"
export APP_DEFAULT_EXTSVC_SERVER_PROTO="http"
export APP_DEFAULT_EXTSVC_SERVICE_PREFIX="/"
export APP_DEFAULT_EXTSVC_MAX_BODY_SIZE=""
export APP_DEFAULT_EXTSVC_FORCE_SSL_REDIRECT="true"
export APP_DEFAULT_EXTSVC_USE_BASIC_AUTH="false"
export APP_DEFAULT_EXTSVC_BASIC_AUTH_USER="user"
export APP_DEFAULT_EXTSVC_USE_CERTS="false"

# --------
# Includes
# --------

if [ -d "$INCL_DIR" ]; then
  # shellcheck source=./common.sh
  [ "$INCL_COMMON_SH" = "1" ] || . "$INCL_DIR/common.sh"
else
  echo "This file has to be sourced using kitt.sh"
  exit 1
fi

# ---------
# Functions
# ---------

extsvc_export_cluster_variables() {
  [ -z "$__extsvc_export_cluster_variables" ] || return 0
  _cluster="$1"
  cluster_export_variables "$_cluster"
  # Directories
  export EXTSVC_TMPL_DIR="$TMPL_DIR/extsvc"
  export EXTSVC_BASE_KUBECTL_DIR="$CLUST_KUBECTL_DIR/extsvc"
  export EXTSVC_BASE_SECRETS_DIR="$CLUST_SECRETS_DIR/extsvc"
  # Templates
  export EXTSVC_INGRESS_TMPL="$EXTSVC_TMPL_DIR/ingress.yaml"
  # Values
  [ "$EXTSVC_NAMESPACE" ] || EXTSVC_NAMESPACE="${APP_DEFAULT_EXTSVC_NAMESPACE}"
  export EXTSVC_NAMESPACE
  # Set variable to avoid loading variables twice
  __extsvc_export_cluster_variables="1"
}

extsvc_export_variables() {
  [ -z "$__extsvc_export_variables" ] || return 0
  _extsvc="$1"
  _cluster="$2"
  # Load cluster values
  extsvc_export_cluster_variables "$_cluster"
  # Labels
  export EXTSVC_NAME="$_extsvc"
  # Directories
  export EXTSVC_CONFIG_DIR="$CLUST_EXTSVC_DIR/$EXTSVC_NAME"
  export EXTSVC_KUBECTL_DIR="$EXTSVC_BASE_KUBECTL_DIR/$EXTSVC_NAME"
  export EXTSVC_SECRETS_DIR="$EXTSVC_BASE_SECRETS_DIR/$EXTSVC_NAME"
  # Files
  export EXTSVC_CONFIG="$CLUST_EXTSVC_DIR/$EXTSVC_NAME/config"
  # Export CLUSTER_CONFIG variables
  export_env_file_vars "$EXTSVC_CONFIG" "EXTSVC"
  # Check if configuration is right
  if [ "$EXTSVC_SERVICE_NAME" ] &&
    [ "$EXTSVC_SERVICE_NAME" != "$EXTSVC_NAME" ]; then
    cat <<EOF
Service name '$EXTSVC_SERVICE_NAME' does not match '$EXTSVC_NAME'.

Edit the '$EXTSVC_CONFIG' file to fix it.
EOF
    exit 1
  fi
  # Values
  [ "$EXTSVC_SERVICE_NAME" ] || EXTSVC_SERVICE_NAME="$EXTSVC_NAME"
  export EXTSVC_SERVICE_NAME
  [ "$EXTSVC_SERVER_ADDR" ] ||
    EXTSVC_SERVER_ADDR="${APP_DEFAULT_EXTSVC_SERVER_ADDR}"
  export EXTSVC_SERVER_ADDR
  [ "$EXTSVC_SERVER_PORT" ] ||
    EXTSVC_SERVER_PORT="${APP_DEFAULT_EXTSVC_SERVER_PORT}"
  export EXTSVC_SERVER_PORT
  [ "$EXTSVC_SERVER_PROTO" ] ||
    EXTSVC_SERVER_PROTO="${APP_DEFAULT_EXTSVC_SERVER_PROTO}"
  export EXTSVC_SERVER_PROTO
  [ "$EXTSVC_INTERNAL_PORT" ] ||
    EXTSVC_INTERNAL_PORT="${APP_DEFAULT_EXTSVC_INTERNAL_PORT}"
  export EXTSVC_INTERNAL_PORT
  [ "$EXTSVC_SERVICE_PREFIX" ] ||
    EXTSVC_SERVICE_PREFIX="${APP_DEFAULT_EXTSVC_SERVICE_PREFIX}"
  export EXTSVC_SERVICE_PREFIX
  [ "$EXTSVC_FORCE_SSL_REDIRECT" ] ||
    EXTSVC_FORCE_SSL_REDIRECT="${APP_DEFAULT_EXTSVC_FORCE_SSL_REDIRECT}"
  export EXTSVC_FORCE_SSL_REDIRECT
  [ "$EXTSVC_USE_BASIC_AUTH" ] ||
    EXTSVC_USE_BASIC_AUTH="${APP_DEFAULT_EXTSVC_USE_BASIC_AUTH}"
  export EXTSVC_USE_BASIC_AUTH
  [ "$EXTSVC_BASIC_AUTH_USER" ] ||
    EXTSVC_BASIC_AUTH_USER="${APP_DEFAULT_EXTSVC_BASIC_AUTH_USER}"
  export EXTSVC_BASIC_AUTH_USER
  [ "$EXTSVC_USE_CERTS" ] ||
    EXTSVC_USE_CERTS="${APP_DEFAULT_EXTSVC_USE_CERTS}"
  export EXTSVC_USE_CERTS
  [ "$EXTSVC_MAX_BODY_SIZE" ] ||
    EXTSVC_MAX_BODY_SIZE="$APP_DEFAULT_EXTSVC_MAX_BODY_SIZE"
  export EXTSVC_MAX_BODY_SIZE
  # Files
  EXTSVC_AUTH_FILE="$EXTSVC_SECRETS_DIR/basic_auth${SOPS_EXT}.txt"
  export EXTSVC_AUTH_FILE
  EXTSVC_AUTH_YAML="$EXTSVC_KUBECTL_DIR/basic-auth${SOPS_EXT}.yaml"
  export EXTSVC_AUTH_YAML
  EXTSVC_CERT_CRT="$EXTSVC_SECRETS_DIR/cert.crt"
  export EXTSVC_CERT_CRT
  EXTSVC_CERT_KEY="$EXTSVC_SECRETS_DIR/cert${SOPS_EXT}.key"
  export EXTSVC_CERT_KEY
  EXTSVC_CERT_YAML="$EXTSVC_KUBECTL_DIR/cert${SOPS_EXT}.yaml"
  export EXTSVC_CERT_YAML
  EXTSVC_ENDPOINT_YAML="$EXTSVC_KUBECTL_DIR/endpoint.yaml"
  export EXTSVC_ENDPOINT_YAML
  EXTSVC_INGRESS_YAML="$EXTSVC_KUBECTL_DIR/ingress.yaml"
  export EXTSVC_INGRESS_YAML
  EXTSVC_SERVICE_YAML="$EXTSVC_KUBECTL_DIR/service.yaml"
  export EXTSVC_SERVICE_YAML
  # Set variable to avoid loading variables twice
  __extsvc_export_variables="1"
}

extsvc_check_directories() {
  for _d in "$CLUST_EXTSVC_DIR" "$CLUST_KUBECTL_DIR" "$CLUST_SECRETS_DIR" \
    "$EXTSVC_BASE_KUBECTL_DIR" "$EXTSVC_BASE_SECRETS_DIR" "$EXTSVC_CONFIG_DIR" \
    "$EXTSVC_KUBECTL_DIR" "$EXTSVC_SECRETS_DIR"; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

extsvc_clean_directories() {
  # Try to remove empty dirs, except if they contain secrets
  for _d in "$EXTSVC_CONFIG_DIR" "$EXTSVC_KUBECTL_DIR" \
    "$EXTSVC_SECRETS_DIR" "$EXTSVC_BASE_KUBECTL_DIR" \
    "$EXTSVC_BASE_SECRETS_DIR" "$CLUST_EXTSVC_DIR"; do
    if [ -d "$_d" ]; then
      rmdir "$_d" 2>/dev/null || true
    fi
  done
}

extsvc_read_config_variables() {
  header "Configuring external service '${EXTSVC_SERVICE_NAME}'"
  read_value "External HOSTNAME" "${EXTSVC_EXTERNAL_HOST}"
  EXTSVC_EXTERNAL_HOST=${READ_VALUE}
  read_value "Server ADDRESS" "${EXTSVC_SERVER_ADDR}"
  EXTSVC_SERVER_ADDR=${READ_VALUE}
  read_value "Server PORT" "${EXTSVC_SERVER_PORT}"
  EXTSVC_SERVER_PORT=${READ_VALUE}
  read_value "Server PROTOCOL" "${EXTSVC_SERVER_PROTO}"
  EXTSVC_SERVER_PROTO=${READ_VALUE}
  read_value "Internal service PORT" "${EXTSVC_INTERNAL_PORT}"
  EXTSVC_INTERNAL_PORT=${READ_VALUE}
  read_value "Service PREFIX" "${EXTSVC_SERVICE_PREFIX}"
  EXTSVC_SERVICE_PREFIX=${READ_VALUE}
  read_bool "Force SSL redirect" "${EXTSVC_FORCE_SSL_REDIRECT}"
  EXTSVC_FORCE_SSL_REDIRECT=${READ_VALUE}
  read_bool "Use BASIC AUTH" "${EXTSVC_USE_BASIC_AUTH}"
  EXTSVC_USE_BASIC_AUTH=${READ_VALUE}
  if is_selected "$EXTSVC_USE_BASIC_AUTH"; then
    read_value "BASIC AUTH Username" "${EXTSVC_BASIC_AUTH_USER}"
    EXTSVC_BASIC_AUTH_USER=${READ_VALUE}
  fi
  read_bool "Use specific TLS certs" "${EXTSVC_USE_CERTS}"
  EXTSVC_USE_CERTS=${READ_VALUE}
  read_value "Ingress max body size" "${EXTSVC_MAX_BODY_SIZE}"
  EXTSVC_MAX_BODY_SIZE=${READ_VALUE}
}

extsvc_print_config_variables() {
  cat <<EOF
SERVICE_NAME=$EXTSVC_SERVICE_NAME
EXTERNAL_HOST=$EXTSVC_EXTERNAL_HOST
SERVER_ADDR=$EXTSVC_SERVER_ADDR
SERVER_PORT=$EXTSVC_SERVER_PORT
SERVER_PROTO=$EXTSVC_SERVER_PROTO
INTERNAL_PORT=$EXTSVC_INTERNAL_PORT
SERVICE_PREFIX=$EXTSVC_SERVICE_PREFIX
FORCE_SSL_REDIRECT=$EXTSVC_FORCE_SSL_REDIRECT
USE_BASIC_AUTH=$EXTSVC_USE_BASIC_AUTH
BASIC_AUTH_USER=$EXTSVC_BASIC_AUTH_USER
USE_CERTS=$EXTSVC_USE_CERTS
MAX_BODY_SIZE=$EXTSVC_MAX_BODY_SIZE
EOF
}

extsvc_create_endpoint_yaml() {
  # Variables
  _ns="$1"
  _service_name="$2"
  _server_addr="$3"
  _server_port="$4"
  _endpoint_yaml="$5"
  _endpoint_tmpl="$TMPL_DIR/extsvc/endpoint.yaml"
  # Check minimal values to continue
  emsg=""
  if [ -z "$_server_addr" ]; then
    emsg="$emsg\n- Missing SERVER_ADDR"
  fi
  case "$_server_port" in
  '') emsg="$emsg\n- Missing SERVER_PORT" ;;
  *[!0-9]*) emsg="$emsg\n- SERVER_PORT must be a number, not '$_server_port'" ;;
  esac
  if [ "$emsg" ]; then
    echo "$emsg"
    return 1
  fi
  # Create endpoint YAML
  sed \
    -e "s/__NAMESPACE__/$_ns/g" \
    -e "s/__SERVICE_NAME__/$_service_name/g" \
    -e "s/__SERVER_ADDR__/$_server_addr/g" \
    -e "s/__SERVER_PORT__/$_server_port/g" \
    "$_endpoint_tmpl" >"$_endpoint_yaml"
}

extsvc_create_service_yaml() {
  # Variables
  _ns="$1"
  _service_name="$2"
  _internal_port="$3"
  _server_port="$4"
  _service_yaml="$5"
  _service_tmpl="$TMPL_DIR/extsvc/service.yaml"
  # Check minimal values to continue
  emsg=""
  if [ -z "$_server_addr" ]; then
    emsg="$emsg\n- Missing SERVER_ADDR"
  fi
  case "$_server_port" in
  '') emsg="$emsg\n- Missing SERVER_PORT" ;;
  *[!0-9]*) emsg="$emsg\n- SERVER_PORT must be a number, not '$_server_port'" ;;
  esac
  if [ "$emsg" ]; then
    echo "$emsg"
    return 1
  fi
  sed \
    -e "s/__NAMESPACE__/$_ns/g" \
    -e "s/__SERVICE_NAME__/$_service_name/g" \
    -e "s/__INTERNAL_PORT__/$_internal_port/g" \
    -e "s/__SERVER_PORT__/$_server_port/g" \
    "$_service_tmpl" >"$_service_yaml"
}

extsvc_config() {
  _extsvc="$1"
  _cluster="$2"
  extsvc_export_variables "$_extsvc" "$_cluster"
  if [ -f "$EXTSVC_CONFIG" ]; then
    header "External service configuration"
    extsvc_print_config_variables
    footer
    read_value "Update configuration? ${yes_no}" "No"
  else
    READ_VALUE="Yes"
  fi
  if is_selected "${READ_VALUE}"; then
    footer
    extsvc_read_config_variables
    if [ -f "$CLUSTER_CONFIG" ]; then
      read_value "Save updated configuration? ${yes_no}" "Yes"
    else
      READ_VALUE="Yes"
    fi
    if is_selected "${READ_VALUE}"; then
      extsvc_check_directories
      extsvc_print_config_variables | stdout_to_file "$EXTSVC_CONFIG"
      footer
      echo "Configuration saved to '$EXTSVC_CONFIG'"
      footer
    fi
  fi
}

extsvc_delete() {
  _extsvc="$1"
  _cluster="$2"
  _remove_config="${3:-true}"
  extsvc_export_variables "$_extsvc" "$_cluster"
  if [ ! -f "$EXTSVC_CONFIG" ]; then
    echo "Missing service configuration, aborting!!!"
    exit 1
  fi
  extsvc_check_directories
  _ns="$EXTSVC_NAMESPACE"
  _auth_yaml="$EXTSVC_AUTH_YAML"
  _cert_yaml="$EXTSVC_CERT_YAML"
  _endpoint_yaml="$EXTSVC_ENDPOINT_YAML"
  _ingress_yaml="$EXTSVC_INGRESS_YAML"
  _service_yaml="$EXTSVC_SERVICE_YAML"
  if find_namespace "$_ns"; then
    header "Removing '$_extsvc' objects"
    for _yaml in "$_auth_yaml" "$_cert_yaml" "$_endpoint_yaml" \
      "$_service_yaml" "$_ingress_yaml"; do
      kubectl_delete "$_yaml" || true
    done
  fi
  # Remove the configuration file
  if [ "$_remove_config" = "true" ] && [ -f "$EXTSVC_CONFIG" ]; then
    rm -f "$EXTSVC_CONFIG"
  fi
  # Remove empty directories
  extsvc_clean_directories
}

extsvc_install() {
  _extsvc="$1"
  _cluster="$2"
  extsvc_export_variables "$_extsvc" "$_cluster"
  if [ ! -f "$EXTSVC_CONFIG" ]; then
    echo "Missing service configuration, aborting!!!"
    exit 1
  fi
  if [ -z "$EXTSVC_NAME" ]; then
    echo "Missing service name, aborting!!!"
    exit 1
  fi
  # Variables
  _ns="$EXTSVC_NAMESPACE"
  # Files
  _endpoint_tmpl="$EXTSVC_ENDPOINT_TMPL"
  _endpoint_yaml="$EXTSVC_ENDPOINT_YAML"
  _ingress_tmpl="$EXTSVC_INGRESS_TMPL"
  _ingress_yaml="$EXTSVC_INGRESS_YAML"
  _service_tmpl="$EXTSVC_SERVICE_TMPL"
  _service_yaml="$EXTSVC_SERVICE_YAML"
  # basic auth values
  if is_selected "$EXTSVC_USE_BASIC_AUTH"; then
    _auth_name="$EXTSVC_NAME-basic-auth"
    _auth_user="$EXTSVC_BASIC_AUTH_USER"
    _auth_file="$EXTSVC_AUTH_FILE"
  else
    _auth_name=""
    _auth_user=""
    _auth_file=""
  fi
  _auth_yaml="$EXTSVC_AUTH_YAML"
  # cert values
  if is_selected "$EXTSVC_USE_CERTS"; then
    _cert_name="$EXTSVC_NAME-certs"
    _cert_crt="$EXTSVC_CERT_CRT"
    _cert_key="$EXTSVC_CERT_KEY"
  else
    _cert_name=""
    _cert_crt=""
    _cert_key=""
  fi
  _cert_yaml="$EXTSVC_CERT_YAML"
  # service & ingress values
  _external_host="$EXTSVC_EXTERNAL_HOST"
  _force_ssl_redirect="$EXTSVC_FORCE_SSL_REDIRECT"
  _service_name="$EXTSVC_SERVICE_NAME"
  _server_addr="$EXTSVC_SERVER_ADDR"
  _server_port="$EXTSVC_SERVER_PORT"
  _server_proto="$EXTSVC_SERVER_PROTO"
  _internal_port="$EXTSVC_INTERNAL_PORT"
  _service_prefix="$EXTSVC_SERVICE_PREFIX"
  _max_body_size="$EXTSVC_MAX_BODY_SIZE"
  # Check minimal values to continue
  emsg=""
  if [ -z "$_external_host" ]; then
    emsg="$emsg\n- Missing EXTERNAL_HOST"
  fi
  if [ -z "$_server_addr" ]; then
    emsg="$emsg\n- Missing SERVER_ADDR"
  fi
  case "$_server_port" in
  '') emsg="$emsg\n- Missing SERVER_PORT" ;;
  *[!0-9]*) emsg="$emsg\n- SERVER_PORT must be a number, not '$_server_port'" ;;
  esac
  if [ "$emsg" ]; then
    header "Configuration errors"
    echo "$emsg"
    echo ""
    echo "Use the config subcommand to fix it"
    footer
    exit 1
  fi
  # Check directories
  extsvc_check_directories
  # Install
  header "Installing external service '$_extsvc'"
  # Check if the namespace exists
  if ! find_namespace "$_ns"; then
    echo "Ingress not installed, can't add external service"
    exit 1
  fi
  # Create tls secret if needed (the call will fall if cert files are missing)
  if [ "$_cert_name" ]; then
    create_tls_cert_yaml "$_ns" "$_cert_name" "$_cert_crt" "$_cert_key" \
      "$_cert_yaml"
    # sed commands for the _ingress_yaml file
    cert_sed="s%__CERT_NAME__%$_cert_name%"
  else
    # If not using certs, remove them if present
    kubectl_delete "$_cert_yaml" || true
    # sed commands for the _ingress_yaml file
    cert_sed="/BEG: USE_TLS/,/END: USE_TLS/d"
  fi
  # Create htpasswd for ingress if needed
  if [ "$_auth_name" ]; then
    auth_file_update "$_auth_user" "$_auth_file"
    create_htpasswd_secret_yaml "$_ns" "$_auth_name" "$_auth_file" "$_auth_yaml"
    # sed commands for the _ingress_yaml file
    basic_auth_sed="s%__AUTH_NAME__%$_auth_name%"
  else
    # If not using basic auth, remove htpasswd secrets if present
    kubectl_delete "$_auth_yaml" || true
    # sed commands for the _ingress_yaml file
    basic_auth_sed="/nginx.ingress.kubernetes.io\/auth-/d"
  fi
  if [ "$_max_body_size" ]; then
    max_body_sed="s%__MAX_BODY_SIZE__%$_max_body_size%"
  else
    max_body_sed="/__MAX_BODY_SIZE__/d"
  fi
  # Create endpoint YAML
  extsvc_create_endpoint_yaml "$_ns" "$_service_name" "$_server_addr" \
    "$_server_port" "$_endpoint_yaml"
  # Create ingress YAML
  sed \
    -e "$basic_auth_sed" \
    -e "$cert_sed" \
    -e "s%__NAMESPACE__%$_ns%" \
    -e "s%__FORCE_SSL_REDIRECT__%$_force_ssl_redirect%" \
    -e "s%__SERVER_PROTO__%$_server_proto%" \
    -e "s%__EXTERNAL_HOST__%$_external_host%" \
    -e "s%__SERVICE_NAME__%$_service_name%" \
    -e "s%__INTERNAL_PORT__%$_internal_port%" \
    -e "s%__SERVICE_PREFIX__%$_service_prefix%" \
    -e "$max_body_sed" \
    "$_ingress_tmpl" >"$_ingress_yaml"
  # Create service YAML
  extsvc_create_service_yaml "$_ns" "$_service_name" "$_internal_port" \
    "$_server_port" "$_service_yaml"
  # Apply the YAML files
  for _yaml in "$_auth_yaml" "$_cert_yaml" "$_endpoint_yaml" "$_service_yaml" \
    "$_ingress_yaml"; do
    kubectl_apply "$_yaml"
  done
  footer
}

extsvc_remove() {
  extsvc_delete "$1" "$2" "false"
}

extsvc_status() {
  _extsvc="$1"
  _cluster="$2"
  _print_status="${3:-true}"
  extsvc_export_cluster_variables "$_cluster"
  _ns="$EXTSVC_NAMESPACE"
  if [ "$_extsvc" = "all" ]; then
    _esnames=""
    if [ -d "$CLUST_EXTSVC_DIR" ]; then
      _esnames="$(
        find "$CLUST_EXTSVC_DIR" -mindepth 2 -maxdepth 2 -name config -type f \
          -printf "%P\n" | sed -e 's%/.*$%%'
      )"
    fi
    if [ -z "$_esnames" ]; then
      echo "No external services found"
      return 0
    fi
  elif [ -f "$CLUST_EXTSVC_DIR/$_extsvc/config" ]; then
    _esnames="$_extsvc"
  else
    echo "External service '$_extsvc' NOT FOUND"
    return 1
  fi
  if find_namespace "$_ns"; then
    for _svc in $_esnames; do
      _status="$(
        kubectl -n "$_ns" get "service/$_svc" "ingress/$_svc" 2>/dev/null
      )" || true
      if [ "$_status" ]; then
        echo "External service '$_svc' INSTALLED"
        if [ "$_print_status" = "true" ]; then
          echo ""
          echo "$_status"
        fi
      else
        echo "External service '$_svc' NOT INSTALLED"
      fi
      echo ""
    done
  fi
}

extsvc_summary() {
  extsvc_status "$1" "$2" "false"
}

extsvc_uris() {
  _extsvc="$1"
  _cluster="$2"
  extsvc_export_variables "$_extsvc" "$_cluster"
  [ -f "$EXTSVC_CONFIG" ] || return
  _hostname="$EXTSVC_EXTERNAL_HOST"
  if is_selected "$EXTSVC_FORCE_SSL_REDIRECT"; then
    _proto="https"
  else
    _proto="http"
  fi
  _prefix="$EXTSVC_SERVICE_PREFIX"
  _uap=""
  if is_selected "$EXTSVC_USE_BASIC_AUTH"; then
    if [ -f "$EXTSVC_AUTH_FILE" ]; then
      _uap="$(file_to_stdout "$EXTSVC_AUTH_FILE")@"
    fi
  fi
  echo "${_proto}://${_uap}${_hostname}${_prefix}"
}

extsvc_command() {
  _extsvc="$1"
  _command="$2"
  _cluster="$3"
  case "$_command" in
  config) extsvc_config "$_extsvc" "$_cluster" ;;
  delete) extsvc_delete "$_extsvc" "$_cluster" ;;
  install) extsvc_install "$_extsvc" "$_cluster" ;;
  remove) extsvc_remove "$_extsvc" "$_cluster" ;;
  status) extsvc_status "$_extsvc" "$_cluster" ;;
  summary) extsvc_summary "$_extsvc" "$_cluster" ;;
  uris) extsvc_uris "$_extsvc" "$_cluster" ;;
  *)
    echo "Unknown subcommand '$_command'"
    exit 1
    ;;
  esac
  case "$_command" in
  status | summary | uris) ;;
  *) cluster_git_update ;;
  esac
}

extsvc_command_list() {
  echo "config delete install remove status summary uris"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
