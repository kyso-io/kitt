#!/bin/sh
# ----
# File:        apps/kyso-ui.sh
# Description: Functions to manage kyso-ui deployments for kyso on k8s clusters
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_APPS_KYSO_UI_SH="1"

# ---------
# Variables
# ---------

# CMND_DSC="kyso-ui: manage kyso-ui deployment for kyso"

# Defaults
export DEPLOYMENT_DEFAULT_KYSO_UI_IMAGE=""
export DEPLOYMENT_DEFAULT_KYSO_UI_REPLICAS="1"

# Fixed values
export KYSO_UI_PORT="3000"

# --------
# Includes
# --------

if [ -d "$INCL_DIR" ]; then
  # shellcheck source=../common.sh
  [ "$INCL_COMMON_SH" = "1" ] || . "$INCL_DIR/common.sh"
  # shellcheck source=./common.sh
  [ "$INCL_APPS_COMMON_SH" = "1" ] || . "$INCL_DIR/apps/common.sh"
fi

# ---------
# Functions
# ---------

apps_kyso_ui_export_variables() {
  [ -z "$__apps_kyso_ui_export_variables" ] || return 0
  _deployment="$1"
  _cluster="$2"
  apps_common_export_variables "$_deployment" "$_cluster"
  apps_mongodb_export_variables "$_deployment" "$_cluster"
  # Values
  export KYSO_UI_NAMESPACE="kyso-ui-$DEPLOYMENT_NAME"
  # Directories
  export KYSO_UI_TMPL_DIR="$TMPL_DIR/apps/kyso-ui"
  export KYSO_UI_KUBECTL_DIR="$DEPLOY_KUBECTL_DIR/kyso-ui"
  export KYSO_UI_SECRETS_DIR="$DEPLOY_SECRETS_DIR/kyso-ui"
  # Templates
  export KYSO_UI_DEPLOY_TMPL="$KYSO_UI_TMPL_DIR/deploy.yaml"
  export KYSO_UI_SERVICE_TMPL="$KYSO_UI_TMPL_DIR/service.yaml"
  export KYSO_UI_INGRESS_TMPL="$KYSO_UI_TMPL_DIR/ingress.yaml"
  # Files
  export KYSO_UI_DEPLOY_YAML="$KYSO_UI_KUBECTL_DIR/deploy.yaml"
  export KYSO_UI_SERVICE_YAML="$KYSO_UI_KUBECTL_DIR/service.yaml"
  export KYSO_UI_INGRESS_YAML="$KYSO_UI_KUBECTL_DIR/ingress.yaml"
  # Use defaults for variables missing from config files
  if [ "$DEPLOYMENT_KYSO_UI_IMAGE" ]; then
    KYSO_UI_IMAGE="$DEPLOYMENT_KYSO_UI_IMAGE" 
  else
    KYSO_UI_IMAGE="$DEPLOYMENT_DEFAULT_KYSO_UI_IMAGE" 
  fi
  export KYSO_UI_IMAGE
  if [ "$DEPLOYMENT_KYSO_UI_REPLICAS" ]; then
    KYSO_UI_REPLICAS="$DEPLOYMENT_KYSO_UI_REPLICAS" 
  else
    KYSO_UI_REPLICAS="$DEPLOYMENT_DEFAULT_KYSO_UI_REPLICAS" 
  fi
  export KYSO_UI_REPLICAS
  __apps_kyso_ui_export_variables="1"
}

apps_kyso_ui_check_directories() {
  apps_common_check_directories
  for _d in "$KYSO_UI_KUBECTL_DIR" "$KYSO_UI_SECRETS_DIR"; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

apps_kyso_ui_clean_directories() {
  # Try to remove empty dirs, except if they contain secrets
  for _d in "$KYSO_UI_KUBECTL_DIR" "$KYSO_UI_SECRETS_DIR"; do
    if [ -d "$_d" ]; then
      rmdir "$_d" 2>/dev/null || true
    fi
  done
}

apps_kyso_ui_read_variables() {
  header "Kyso UI Settings"
  _ex_ep="$LINUX_HOST_IP:$KYSO_UI_PORT"
  read_value "kyso-ui endpoint (i.e. '$_ex_ep' or '-' to deploy image)" \
    "${KYSO_UI_ENDPOINT}"
  KYSO_UI_ENDPOINT=${READ_VALUE}
  _ex_img="registry.kyso.io/kyso-io/kyso-ui/develop:latest"
  read_value \
    "Kyso UI Image URI (i.e. '$_ex_img' or export KYSO_UI_IMAGE env var)" \
    "${KYSO_UI_IMAGE}"
  KYSO_UI_IMAGE=${READ_VALUE}
  read_value "Kyso UI Replicas" "${KYSO_UI_REPLICAS}"
  KYSO_UI_REPLICAS=${READ_VALUE}
}

apps_kyso_ui_print_variables() {
  cat <<EOF
# Kyso UI Settings
# ---
# Endpoint for Kyso UI (replaces the real deployment on development systems),
# set to:
# - '$LINUX_HOST_IP:$KYSO_UI_PORT' on Linux
# - '$MACOS_HOST_IP:$KYSO_UI_PORT' on systems using Docker Desktop (Mac/Win)
KYSO_UI_ENDPOINT=$KYSO_UI_ENDPOINT
# Kyso UI Image URI, examples for local testing:
# - 'registry.kyso.io/kyso-io/kyso-ui/develop:latest'
# - 'k3d-registry.lo.kyso.io:5000/kyso-ui:latest'
# If left empty the KYSO_UI_IMAGE environment variable has to be set each time
# the kyso-ui service is installed
KYSO_UI_IMAGE=$KYSO_UI_IMAGE
# Number of pods to run in parallel
KYSO_UI_REPLICAS=$KYSO_UI_REPLICAS
# ---
EOF
}

apps_kyso_ui_install() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_ui_export_variables "$_deployment" "$_cluster"
  apps_kyso_ui_check_directories
  # Adjust variables
  _app="kyso-ui"
  _ns="$KYSO_UI_NAMESPACE"
  _ep_tmpl="$KYSO_UI_ENDPOINT_TMPL"
  _ep_yaml="$KYSO_UI_ENDPOINT_YAML"
  _service_tmpl="$KYSO_UI_SERVICE_TMPL"
  _service_yaml="$KYSO_UI_SERVICE_YAML"
  _deploy_tmpl="$KYSO_UI_DEPLOY_TMPL"
  _deploy_yaml="$KYSO_UI_DEPLOY_YAML"
  _ingress_tmpl="$KYSO_UI_INGRESS_TMPL"
  _ingress_yaml="$KYSO_UI_INGRESS_YAML"
  _cert_yamls=""
  for _hostname in $DEPLOYMENT_HOSTNAMES; do
    _cert_yaml="$KYSO_UI_KUBECTL_DIR/tls-$_hostname${SOPS_EXT}.yaml"
    _cert_yamls="$_cert_yamls $_cert_yaml"
  done
  if ! find_namespace "$_ns"; then
    # Remove old files, just in case ...
    # shellcheck disable=SC2086
    rm -f "$_ep_yaml" "$_service_yaml" "$_deploy_yaml" "$_ingress_yaml" \
      $_cert_yamls
    # Create namespace
    create_namespace "$_ns"
  fi
  if [ "$KYSO_UI_ENDPOINT" ]; then
    # Remove service if we are switching from a deployment, otherwise we already
    # have an endpoint linked to the service and the creation generates a warn
    if [ -f "$_service_yaml" ]; then
      if [ ! -f "$_ep_yaml" ]; then
        kubectl_delete "$_service_yaml" || true
      fi
    fi
    # Remove deployment related files
    kubectl_delete "$_deploy_yaml" || true
    # Generate / update endpoint yaml
    _ui_addr="${KYSO_UI_ENDPOINT%:*}"
    _ui_port="${KYSO_UI_ENDPOINT#*:}"
    [ "$_ui_port" != "$_ui_addr" ] || _ui_port="$KYSO_UI_PORT"
    sed \
      -e "s%__APP__%$_app%" \
      -e "s%__NAMESPACE__%$_ns%" \
      -e "s%__SERVER_ADDR__%$_ui_addr%" \
      -e "s%__SERVER_PORT__%$_ui_port%" \
      "$_ep_tmpl" >"$_ep_yaml"
    # Use the right service template
    _service_tmpl="$KYSO_UI_ENDPOINT_SVC_TMPL"
  else
    # Remove endpoint if switching
    kubectl_delete "$_ep_yaml" || true
    # Adjust the ui port
    _ui_port="$KYSO_UI_PORT"
    # Use the right service template
    _service_tmpl="$KYSO_UI_SERVICE_TMPL"
  fi
  # Create certificate secrets if needed or remove them if not
  if is_selected "$DEPLOYMENT_INGRESS_TLS_CERTS"; then
    create_app_cert_yamls "$_ns" "$KYSO_UI_KUBECTL_DIR"
  else
    for _hostname in $DEPLOYMENT_HOSTNAMES; do
      _cert_yaml="$KYSO_UI_KUBECTL_DIR/tls-$_hostname${SOPS_EXT}.yaml"
      kubectl_delete "$_cert_yaml" || true
    done
  fi
  # Create ingress definition
  create_app_ingress_yaml "$_ns" "$_app" "$_ingress_tmpl" "$_ingress_yaml" \
    "" ""
  # Prepare service_yaml
  sed \
    -e "s%__APP__%$_app%" \
    -e "s%__NAMESPACE__%$_ns%" \
    -e "s%__SERVER_PORT__%$_ui_port%" \
    "$_service_tmpl" >"$_service_yaml"
  # Prepare deployment file
  sed \
    -e "s%__APP__%$_app%" \
    -e "s%__NAMESPACE__%$_ns%" \
    -e "s%__UI_REPLICAS__%$KYSO_UI_REPLICAS%" \
    -e "s%__UI_IMAGE__%$KYSO_UI_IMAGE%" \
    -e "s%__IMAGE_PULL_POLICY__%$IMAGE_PULL_POLICY%" \
    "$_deploy_tmpl" >"$_deploy_yaml"
  for _yaml in "$_ep_yaml" "$_service_yaml" "$_deploy_yaml" "$_ingress_yaml" \
    $_cert_yamls; do
    kubectl_apply "$_yaml"
  done
  # Wait until deployment succeds or fails (if there is one, of course)
  if [ -f "$_deploy_yaml" ]; then
    kubectl rollout status deployment --timeout="$ROLLOUT_STATUS_TIMEOUT" \
      -n "$_ns" "$_app"
  fi
}

apps_kyso_ui_remove() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_ui_export_variables "$_deployment" "$_cluster"
  _app="kyso-ui"
  _ns="$KYSO_UI_NAMESPACE"
  _svc_yaml="$KYSO_UI_SVC_YAML"
  _deploy_yaml="$KYSO_UI_DEPLOY_YAML"
  _ingress_yaml="$KYSO_UI_INGRESS_YAML"
  _cert_yamls=""
  for _hostname in $DEPLOYMENT_HOSTNAMES; do
    _cert_yaml="$KYSO_UI_KUBECTL_DIR/tls-$_hostname${SOPS_EXT}.yaml"
    _cert_yamls="$_cert_yamls $_cert_yaml"
  done
  apps_kyso_ui_export_variables
  if find_namespace "$_ns"; then
    header "Removing '$_app' objects"
    for _yaml in "$_svc_yaml" "$_deploy_yaml" "$_ingress_yaml" $_cert_yamls; do
      kubectl_delete "$_yaml" || true
    done
    delete_namespace "$_ns"
    footer
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
  apps_kyso_ui_clean_directories
}

apps_kyso_ui_restart() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_ui_export_variables "$_deployment" "$_cluster"
  _app="kyso-ui"
  _ns="$KYSO_UI_NAMESPACE"
  if find_namespace "$_ns"; then
    deployment_restart "$_ns" "$_app"
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

apps_kyso_ui_status() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_ui_export_variables "$_deployment" "$_cluster"
  _app="kyso-ui"
  _ns="$KYSO_UI_NAMESPACE"
  if find_namespace "$_ns"; then
    kubectl get all,endpoints,ingress,secrets -n "$_ns"
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

apps_kyso_ui_summary() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_ui_export_variables "$_deployment" "$_cluster"
  _ns="$KYSO_UI_NAMESPACE"
  _app="kyso-ui"
  deployment_summary "$_ns" "$_app"
}

apps_kyso_ui_uris() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_api_export_variables "$_deployment" "$_cluster"
  _hostname="${DEPLOYMENT_HOSTNAMES%% *}"
  echo "https://$_hostname/"
}

apps_kyso_ui_command() {
  _command="$1"
  _deployment="$2"
  _cluster="$3"
  case "$_command" in
    install) apps_kyso_ui_install "$_deployment" "$_cluster";;
    restart) apps_kyso_ui_restart "$_deployment" "$_cluster";;
    remove) apps_kyso_ui_remove "$_deployment" "$_cluster";;
    status) apps_kyso_ui_status "$_deployment" "$_cluster";;
    summary) apps_kyso_ui_summary "$_deployment" "$_cluster";;
    uris) apps_kyso_ui_uris "$_deployment" "$_cluster";;
    *) echo "Unknown kyso-ui subcommand '$1'"; exit 1 ;;
  esac
}

apps_kyso_ui_command_list() {
  echo "install remove status summary uris"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
