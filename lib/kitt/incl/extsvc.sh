#!/bin/sh
# ----
# File:        extsvc.sh
# Description: Functions to manage ingress configs for external services
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022 Sergio Talens-Oliag <sto@kyso.io>
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

extsvc_export_variables() {
  [ -z "$__extsvc_export_variables" ] || return 0
  _extsvc="$1"
  _cluster="$2"
  # Labels
  if [ "$_extsvc" ]; then
    export EXTSVC_NAME="$_extsvc"
  fi
  # Load cluster values
  cluster_export_variables "$_cluster"
  # Directories
  export EXTSVC_TMPL_DIR="$TMPL_DIR/extsvc"
  export EXTSVC_BASE_KUBECTL_DIR="$CLUST_KUBECTL_DIR/extsvc"
  export EXTSVC_BASE_SECRETS_DIR="$CLUST_SECRETS_DIR/extsvc"
  export EXTSVC_CONFIG_DIR="$CLUST_EXTSVC_DIR/$_extsvc"
  export EXTSVC_KUBECTL_DIR="$EXTSVC_BASE_KUBECTL_DIR/$_extsvc"
  export EXTSVC_SECRETS_DIR="$EXTSVC_BASE_SECRETS_DIR/$_extsvc"
  # Templates
  export EXTSVC_INGRESS_TMPL="$EXTSVC_TMPL_DIR/ingress.yaml"
  export EXTSVC_CONFIG="$EXTSVC_CONFIG_DIR/config"
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
  [ "$EXTSVC_NAMESPACE" ] || EXTSVC_NAMESPACE="${APP_DEFAULT_EXTSVC_NAMESPACE}"
  export EXTSVC_NAMESPACE
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
}

extsvc_print_config_variables() {
  cat <<EOF
SERVICE_NAME=$EXTSVC_SERVICE_NAME
EXTERNAL_HOST=$EXTSVC_EXTERNAL_HOST
SERVER_ADDR=$EXTSVC_SERVER_ADDR
SERVER_PORT=$EXTSVC_SERVER_PORT
SERVER_PROTO=$EXTSVC_SERVER_PROTO
INTERNAL_PORT=$EXTSVC_INTERNAL_PORT
FORCE_SSL_REDIRECT=$EXTSVC_FORCE_SSL_REDIRECT
USE_BASIC_AUTH=$EXTSVC_USE_BASIC_AUTH
BASIC_AUTH_USER=$EXTSVC_BASIC_AUTH_USER
USE_CERTS=$EXTSVC_USE_CERTS
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

extsvc_install() {
  _extsvc="$1"
  _cluster="$2"
  extsvc_export_variables "$_extsvc" "$_cluster"
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
    create_htpasswd_secret_yaml "$_ns" "$_auth_name" "$_auth_user" \
      "$_auth_file" "$_auth_yaml"
    # sed commands for the _ingress_yaml file
    basic_auth_sed="s%__AUTH_NAME__%$_auth_name%"
  else
    # If not using basic auth, remove htpasswd secrets if present
    kubectl_delete "$_auth_yaml" || true
    # sed commands for the _ingress_yaml file
    basic_auth_sed="/nginx.ingress.kubernetes.io\/auth-/d"
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
  _extsvc="$1"
  _cluster="$2"
  extsvc_export_variables "$_extsvc" "$_cluster"
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
  if [ -f "$EXTSVC_CONFIG" ]; then
    rm -f "$EXTSVC_CONFIG"
  fi
  # Remove empty directories
  extsvc_clean_directories
}

extsvc_command() {
  _command="$1"
  _extsvc="$2"
  _cluster="$3"
  case "$_command" in
    config) extsvc_config "$_extsvc" "$_cluster" ;;
    install) extsvc_install "$_extsvc" "$_cluster" ;;
    remove) extsvc_remove "$_extsvc" "$_cluster" ;;
    *) echo "Unknown subcommand '$1'"; exit 1 ;;
  esac
  case "$_command" in
    status|summary) ;;
    *) cluster_git_update ;;
  esac
}

extsvc_command_list() {
  echo "config install remove"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
