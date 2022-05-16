#!/bin/sh
# ----
# File:        apps/mongo-gui.sh
# Description: Functions to manage mongo-gui deployments for kyso on k8s clusters
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_APPS_MONGO_GUI_SH="1"

# ---------
# Variables
# ---------

# CMND_DSC="mongo-gui: manage mongo-gui deployment for kyso"

# Defaults
_image="registry.kyso.io/docker/mongo-gui:latest"
export DEPLOYMENT_DEFAULT_MONGO_GUI_IMAGE="$_image"

# Fixed values
export MONGO_GUI_BASIC_AUTH_NAME="basic-auth"
export MONGO_GUI_BASIC_AUTH_USER="mongo-admin"

# --------
# Includes
# --------

if [ -d "$INCL_DIR" ]; then
  # shellcheck source=../common.sh
  [ "$INCL_COMMON_SH" = "1" ] || . "$INCL_DIR/common.sh"
  # shellcheck source=./common.sh
  [ "$INCL_APPS_COMMON_SH" = "1" ] || . "$INCL_DIR/apps/common.sh"
  # shellcheck source=./mongodb.sh
  [ "$INCL_APPS_MONGODB_SH" = "1" ] || . "$INCL_DIR/apps/mongodb.sh"
fi

# ---------
# Functions
# ---------

apps_mongo_gui_export_variables() {
  [ -z "$__apps_mongo_gui_export_variables" ] || return 0
  _deployment="$1"
  _cluster="$2"
  apps_common_export_variables "$_deployment" "$_cluster"
  apps_mongodb_export_variables "$_deployment" "$_cluster"
  # Values
  export MONGO_GUI_NAMESPACE="mongo-gui-$DEPLOYMENT_NAME"
  # Directories
  export MONGO_GUI_TMPL_DIR="$TMPL_DIR/apps/mongo-gui"
  export MONGO_GUI_KUBECTL_DIR="$DEPLOY_KUBECTL_DIR/mongo-gui"
  export MONGO_GUI_SECRETS_DIR="$DEPLOY_SECRETS_DIR/mongo-gui"
  # Templates
  export MONGO_GUI_DEPLOY_TMPL="$MONGO_GUI_TMPL_DIR/deploy.yaml"
  export MONGO_GUI_SECRET_TMPL="$MONGO_GUI_TMPL_DIR/secrets.yaml"
  export MONGO_GUI_SVC_TMPL="$MONGO_GUI_TMPL_DIR/service.yaml"
  export MONGO_GUI_INGRESS_TMPL="$MONGO_GUI_TMPL_DIR/ingress.yaml"
  # Files
  export MONGO_GUI_DEPLOY_YAML="$MONGO_GUI_KUBECTL_DIR/deploy.yaml"
  export MONGO_GUI_SECRET_YAML="$MONGO_GUI_SECRETS_DIR/secrets.yaml"
  export MONGO_GUI_SVC_YAML="$MONGO_GUI_KUBECTL_DIR/service.yaml"
  export MONGO_GUI_INGRESS_YAML="$MONGO_GUI_KUBECTL_DIR/ingress.yaml"
  _auth_file="$MONGO_GUI_SECRETS_DIR/basic_auth${SOPS_EXT}.txt"
  export MONGO_GUI_AUTH_FILE="$_auth_file"
  _auth_yaml="$MONGO_GUI_KUBECTL_DIR/basic-auth${SOPS_EXT}.yaml"
  export MONGO_GUI_AUTH_YAML="$_auth_yaml"
  # Use defaults for variables missing from config files
  if [ "$DEPLOYMENT_MONGO_GUI_IMAGE" ]; then
    MONGO_GUI_IMAGE="$DEPLOYMENT_MONGO_GUI_IMAGE" 
  else
    MONGO_GUI_IMAGE="$DEPLOYMENT_DEFAULT_MONGO_GUI_IMAGE" 
  fi
  export MONGO_GUI_IMAGE
  __apps_mongo_gui_export_variables="1"
}

apps_mongo_gui_check_directories() {
  apps_common_check_directories
  for _d in "$MONGO_GUI_KUBECTL_DIR" "$MONGO_GUI_SECRETS_DIR"; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

apps_mongo_gui_clean_directories() {
  # Try to remove empty dirs, except if they contain secrets
  for _d in "$MONGO_GUI_KUBECTL_DIR" "$MONGO_GUI_SECRETS_DIR"; do
    if [ -d "$_d" ]; then
      rmdir "$_d" 2>/dev/null || true
    fi
  done
}

apps_mongo_gui_read_variables() {
  header "Mongo GUI Settings"
  read_value "Mongo-gui image" "${MONGO_GUI_IMAGE}"
  MONGO_GUI_IMAGE=${READ_VALUE}
}

apps_mongo_gui_print_variables() {
  cat <<EOF
# Mongo GUI Settings
# ---
MONGO_GUI_IMAGE=$MONGO_GUI_IMAGE
# ---
EOF
}

apps_mongo_gui_logs() {
  _deployment="$1"
  _cluster="$2"
  apps_mongo_gui_export_variables "$_deployment" "$_cluster"
  _ns="$MONGO_GUI_NAMESPACE"
  _label="app=mongo-gui"
  kubectl -n "$_ns" logs -l "$_label" -f
}

apps_mongo_gui_install() {
  _deployment="$1"
  _cluster="$2"
  apps_mongo_gui_export_variables "$_deployment" "$_cluster"
  apps_mongo_gui_check_directories
  _app="mongo-gui"
  _ns="$MONGO_GUI_NAMESPACE"
  _secret_tmpl="$MONGO_GUI_SECRET_TMPL"
  _secret_yaml="$MONGO_GUI_SECRET_YAML"
  _svc_tmpl="$MONGO_GUI_SVC_TMPL"
  _svc_yaml="$MONGO_GUI_SVC_YAML"
  _deploy_tmpl="$MONGO_GUI_DEPLOY_TMPL"
  _deploy_yaml="$MONGO_GUI_DEPLOY_YAML"
  _ingress_tmpl="$MONGO_GUI_INGRESS_TMPL"
  _ingress_yaml="$MONGO_GUI_INGRESS_YAML"
  if is_selected "$CLUSTER_USE_BASIC_AUTH"; then
    _auth_name="$MONGO_GUI_BASIC_AUTH_NAME"
    _auth_user="$MONGO_GUI_BASIC_AUTH_USER"
    _auth_file="$MONGO_GUI_AUTH_FILE"
  else
    _auth_name=""
    _auth_user=""
    _auth_file=""
  fi
  _auth_yaml="$MONGO_GUI_AUTH_YAML"
  _cert_yamls=""
  for _hostname in $DEPLOYMENT_HOSTNAMES; do
    _cert_yaml="$MONGO_GUI_KUBECTL_DIR/tls-$_hostname${SOPS_EXT}.yaml"
    _cert_yamls="$_cert_yamls $_cert_yaml"
  done
  if ! find_namespace "$_ns"; then
    # Remove old files, just in case ...
    # shellcheck disable=SC2086
    rm -f "$_secret_yaml" "$_auth_yaml" "$_svc_yaml" "$_deploy_yaml" \
      "$_ingress_yaml" $_cert_yamls
    # Create namespace
    create_namespace "$_ns"
  fi
  # Create htpasswd for ingress if needed or remove the yaml if present
  if [ "$_auth_name" ]; then
    create_htpasswd_secret_yaml "$_ns" "$_auth_name" "$_auth_user" \
      "$_auth_file" "$_auth_yaml"
  else
    kubectl_delete "$_auth_yaml" || true
  fi
  # Create certificate secrets if needed or remove them if not
  if is_selected "$DEPLOYMENT_INGRESS_TLS_CERTS"; then
    create_app_cert_yamls "$_ns" "$MONGO_GUI_KUBECTL_DIR"
  else
    for _hostname in $DEPLOYMENT_HOSTNAMES; do
      _cert_yaml="$MONGO_GUI_KUBECTL_DIR/tls-$_hostname${SOPS_EXT}.yaml"
      kubectl_delete "$_cert_yaml" || true
    done
  fi
  # Create ingress definition
  create_app_ingress_yaml "$_ns" "$_app" "$_ingress_tmpl" "$_ingress_yaml" \
    "$_auth_name" ""
  # Prepare service_yaml
  sed \
    -e "s%__APP__%$_app%" \
    -e "s%__NAMESPACE__%$_ns%" \
    "$_svc_tmpl" >"$_svc_yaml"
  # Prepare secrets
  : >"$_secret_yaml"
  chmod 0600 "$_secret_yaml"
  _mongodb_url_b64="$(
    apps_mongodb_print_root_database_uri "$_deployment" "$_cluster" |
      openssl base64 -e | tr -d '\n'
  )"
  sed \
    -e "s%__APP__%$_app%" \
    -e "s%__NAMESPACE__%$_ns%" \
    -e "s%__MONGODB_URL_BASE64__%$_mongodb_url_b64%" \
    "$_secret_tmpl" |
    stdout_to_file "$_secret_yaml"
  # Prepare deployment file
  sed \
    -e "s%__APP__%$_app%" \
    -e "s%__NAMESPACE__%$_ns%" \
    -e "s%__MONGO_GUI_IMAGE__%$MONGO_GUI_IMAGE%" \
    -e "s%__IMAGE_PULL_POLICY__%$IMAGE_PULL_POLICY%" \
    "$_deploy_tmpl" >"$_deploy_yaml"
  for _yaml in "$_secret_yaml" "$_auth_yaml" "$_svc_yaml" "$_deploy_yaml" \
    "$_ingress_yaml" $_cert_yamls; do
    kubectl_apply "$_yaml"
  done
  # Wait until deployment succeds of fails
  kubectl rollout status deployment --timeout="$ROLLOUT_STATUS_TIMEOUT" \
    -n "$_ns" "$_app"
}

apps_mongo_gui_remove() {
  _deployment="$1"
  _cluster="$2"
  apps_mongo_gui_export_variables "$_deployment" "$_cluster"
  _app="mongo-gui"
  _ns="$MONGO_GUI_NAMESPACE"
  _secret_yaml="$MONGO_GUI_SECRET_YAML"
  _svc_yaml="$MONGO_GUI_SVC_YAML"
  _deploy_yaml="$MONGO_GUI_DEPLOY_YAML"
  _ingress_yaml="$MONGO_GUI_INGRESS_YAML"
  _auth_yaml="$MONGO_GUI_AUTH_YAML"
  _cert_yamls=""
  for _hostname in $DEPLOYMENT_HOSTNAMES; do
    _cert_yaml="$MONGO_GUI_KUBECTL_DIR/tls-$_hostname${SOPS_EXT}.yaml"
    _cert_yamls="$_cert_yamls $_cert_yaml"
  done
  apps_mongo_gui_export_variables
  if find_namespace "$_ns"; then
    header "Removing '$_app' objects"
    for _yaml in "$_secret_yaml" "$_auth_yaml" "$_svc_yaml" "$_deploy_yaml" \
      "$_ingress_yaml" $_cert_yamls; do
      kubectl_delete "$_yaml" || true
    done
    delete_namespace "$_ns"
    footer
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
  apps_mongo_gui_clean_directories
}

apps_mongo_gui_restart() {
  _deployment="$1"
  _cluster="$2"
  apps_mongo_gui_export_variables "$_deployment" "$_cluster"
  _app="mongo-gui"
  _ns="$MONGO_GUI_NAMESPACE"
  if find_namespace "$_ns"; then
    deployment_restart "$_ns" "$_app"
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

apps_mongo_gui_status() {
  _deployment="$1"
  _cluster="$2"
  apps_mongo_gui_export_variables "$_deployment" "$_cluster"
  _app="mongo-gui"
  _ns="$MONGO_GUI_NAMESPACE"
  if find_namespace "$_ns"; then
    kubectl get all,endpoints,ingress,secrets -n "$_ns"
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

apps_mongo_gui_summary() {
  _deployment="$1"
  _cluster="$2"
  apps_mongo_gui_export_variables "$_deployment" "$_cluster"
  _ns="$MONGO_GUI_NAMESPACE"
  _app="mongo-gui"
  deployment_summary "$_ns" "$_app"
}

apps_mongo_gui_uris() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_api_export_variables "$_deployment" "$_cluster"
  _hostname="${DEPLOYMENT_HOSTNAMES%% *}"
  if is_selected "$CLUSTER_USE_BASIC_AUTH" &&
    [ -f "$MONGO_GUI_AUTH_FILE" ]; then
    _uap="$(file_to_stdout "$MONGO_GUI_AUTH_FILE")"
    echo "https://$_uap@$_hostname/mongo-gui/"
  else
    echo "https://$_hostname/mongo-gui/"
  fi
}

apps_mongo_gui_command() {
  _command="$1"
  _deployment="$2"
  _cluster="$3"
  case "$_command" in
    logs) apps_mongo_gui_logs "$_deployment" "$_cluster";;
    install) apps_mongo_gui_install "$_deployment" "$_cluster";;
    remove) apps_mongo_gui_remove "$_deployment" "$_cluster";;
    restart) apps_mongo_gui_restart "$_deployment" "$_cluster";;
    status) apps_mongo_gui_status "$_deployment" "$_cluster";;
    summary) apps_mongo_gui_summary "$_deployment" "$_cluster";;
    uris) apps_mongo_gui_uris "$_deployment" "$_cluster";;
    *) echo "Unknown mongo-gui subcommand '$1'"; exit 1 ;;
  esac
}

apps_mongo_gui_command_list() {
  echo "logs install remove restart status summary uris"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
