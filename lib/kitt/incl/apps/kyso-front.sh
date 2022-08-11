#!/bin/sh
# ----
# File:        apps/kyso-front.sh
# Description: Functions to manage kyso-front deployments for kyso on k8s
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_APPS_KYSO_FRONT_SH="1"

# ---------
# Variables
# ---------

# CMND_DSC="kyso-front: manage kyso-front deployment for kyso"

# Defaults
export DEPLOYMENT_DEFAULT_KYSO_FRONT_ENDPOINT=""
export DEPLOYMENT_DEFAULT_KYSO_FRONT_IMAGE=""
export DEPLOYMENT_DEFAULT_KYSO_FRONT_PATH_PREFIX="/"
export DEPLOYMENT_DEFAULT_KYSO_FRONT_REPLICAS="1"

# Fixed values
export KYSO_FRONT_PORT="3000"

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

apps_kyso_front_export_variables() {
  [ -z "$__apps_kyso_front_export_variables" ] || return 0
  _deployment="$1"
  _cluster="$2"
  apps_common_export_variables "$_deployment" "$_cluster"
  apps_mongodb_export_variables "$_deployment" "$_cluster"
  # Values
  export KYSO_FRONT_NAMESPACE="kyso-front-$DEPLOYMENT_NAME"
  # Directories
  export KYSO_FRONT_TMPL_DIR="$TMPL_DIR/apps/kyso-front"
  export KYSO_FRONT_KUBECTL_DIR="$DEPLOY_KUBECTL_DIR/kyso-front"
  export KYSO_FRONT_SECRETS_DIR="$DEPLOY_SECRETS_DIR/kyso-front"
  # Templates
  export KYSO_FRONT_DEPLOY_TMPL="$KYSO_FRONT_TMPL_DIR/deploy.yaml"
  export KYSO_FRONT_ENDPOINT_TMPL="$KYSO_FRONT_TMPL_DIR/endpoint.yaml"
  export KYSO_FRONT_ENDPOINT_SVC_TMPL="$KYSO_FRONT_TMPL_DIR/endpoint_svc.yaml"
  export KYSO_FRONT_SERVICE_TMPL="$KYSO_FRONT_TMPL_DIR/service.yaml"
  export KYSO_FRONT_INGRESS_TMPL="$KYSO_FRONT_TMPL_DIR/ingress.yaml"
  # Files
  export KYSO_FRONT_DEPLOY_YAML="$KYSO_FRONT_KUBECTL_DIR/deploy.yaml"
  export KYSO_FRONT_ENDPOINT_YAML="$KYSO_FRONT_KUBECTL_DIR/endpoint.yaml"
  export KYSO_FRONT_SERVICE_YAML="$KYSO_FRONT_KUBECTL_DIR/service.yaml"
  export KYSO_FRONT_INGRESS_YAML="$KYSO_FRONT_KUBECTL_DIR/ingress.yaml"
  # Use defaults for variables missing from config files / enviroment
  if [ -z "$KYSO_FRONT_ENDPOINT" ]; then
    if [ "$DEPLOYMENT_KYSO_FRONT_ENDPOINT" ]; then
      KYSO_FRONT_ENDPOINT="$DEPLOYMENT_KYSO_FRONT_ENDPOINT"
    else
      KYSO_FRONT_ENDPOINT="$DEPLOYMENT_DEFAULT_KYSO_FRONT_ENDPOINT"
    fi
  fi
  if [ -z "$KYSO_FRONT_IMAGE" ]; then
    if [ "$DEPLOYMENT_KYSO_FRONT_IMAGE" ]; then
      KYSO_FRONT_IMAGE="$DEPLOYMENT_KYSO_FRONT_IMAGE"
    else
      KYSO_FRONT_IMAGE="$DEPLOYMENT_DEFAULT_KYSO_FRONT_IMAGE"
    fi
  fi
  export KYSO_FRONT_IMAGE
  if [ -z "$KYSO_FRONT_PATH_PREFIX" ]; then
    if [ "$DEPLOYMENT_KYSO_FRONT_PATH_PREFIX" ]; then
      KYSO_FRONT_PATH_PREFIX="$DEPLOYMENT_KYSO_FRONT_PATH_PREFIX"
    else
      KYSO_FRONT_PATH_PREFIX="$DEPLOYMENT_DEFAULT_KYSO_FRONT_PATH_PREFIX"
    fi
  fi
  export KYSO_FRONT_PATH_PREFIX
  if [ "$DEPLOYMENT_KYSO_FRONT_REPLICAS" ]; then
    KYSO_FRONT_REPLICAS="$DEPLOYMENT_KYSO_FRONT_REPLICAS"
  else
    KYSO_FRONT_REPLICAS="$DEPLOYMENT_DEFAULT_KYSO_FRONT_REPLICAS"
  fi
  export KYSO_FRONT_REPLICAS
  __apps_kyso_front_export_variables="1"
}

apps_kyso_front_check_directories() {
  apps_common_check_directories
  for _d in "$KYSO_FRONT_KUBECTL_DIR" "$KYSO_FRONT_SECRETS_DIR"; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

apps_kyso_front_clean_directories() {
  # Try to remove empty dirs, except if they contain secrets
  for _d in "$KYSO_FRONT_KUBECTL_DIR" "$KYSO_FRONT_SECRETS_DIR"; do
    if [ -d "$_d" ]; then
      rmdir "$_d" 2>/dev/null || true
    fi
  done
}

apps_kyso_front_read_variables() {
  _app="kyso-front"
  header "Reading $_app settings"
  _ex_ep="$LINUX_HOST_IP:$KYSO_FRONT_PORT"
  read_value "kyso-front endpoint (i.e. '$_ex_ep' or '-' to deploy image)" \
    "${KYSO_FRONT_ENDPOINT}"
  KYSO_FRONT_ENDPOINT=${READ_VALUE}
  _ex_img="registry.kyso.io/kyso-io/kyso-front/develop:latest"
  read_value \
    "Kyso Front Image URI (i.e. '$_ex_img' or export KYSO_FRONT_IMAGE env var)" \
    "${KYSO_FRONT_IMAGE}"
  KYSO_FRONT_IMAGE=${READ_VALUE}
  read_value "Kyso PATH Prefix" "${KYSO_FRONT_PATH_PREFIX}"
  KYSO_FRONT_PATH_PREFIX=${READ_VALUE}
  read_value "Kyso Front Replicas" "${KYSO_FRONT_REPLICAS}"
  KYSO_FRONT_REPLICAS=${READ_VALUE}
}

apps_kyso_front_print_variables() {
  _app="kyso-front"
  cat <<EOF
# Deployment $_app settings
# ---
# Endpoint for Kyso Front (replaces the real deployment on development systems),
# set to:
# - '$LINUX_HOST_IP:$KYSO_FRONT_PORT' on Linux
# - '$MACOS_HOST_IP:$KYSO_FRONT_PORT' on systems using Docker Desktop (Mac/Win)
KYSO_FRONT_ENDPOINT=$KYSO_FRONT_ENDPOINT
# Kyso Front Image URI, examples for local testing:
# - 'registry.kyso.io/kyso-io/kyso-front/develop:latest'
# - 'k3d-registry.lo.kyso.io:5000/kyso-front:latest'
# If left empty the KYSO_FRONT_IMAGE environment variable has to be set each time
# the kyso-front service is installed
KYSO_FRONT_IMAGE=$KYSO_FRONT_IMAGE
# Kyso Front PATH Prefix
KYSO_FRONT_PATH_PREFIX=$KYSO_FRONT_PATH_PREFIX
# Number of pods to run in parallel
KYSO_FRONT_REPLICAS=$KYSO_FRONT_REPLICAS
# ---
EOF
}

apps_kyso_front_logs() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_front_export_variables "$_deployment" "$_cluster"
  _ns="$KYSO_FRONT_NAMESPACE"
  _label="app=kyso-front"
  kubectl -n "$_ns" logs -l "$_label" -f
}

apps_kyso_front_install() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_front_export_variables "$_deployment" "$_cluster"
  if [ -z "$KYSO_FRONT_ENDPOINT" ] && [ -z "$KYSO_FRONT_IMAGE" ]; then
    echo "The FRONT_IMAGE & FRONT_ENDPOINT variables are empty."
    echo "Export KYSO_FRONT_IMAGE or KYSO_FRONT_ENDPOINT or reconfigure."
    exit 1
  fi
  apps_kyso_front_check_directories
  # Adjust variables
  _app="kyso-front"
  _ns="$KYSO_FRONT_NAMESPACE"
  _ep_tmpl="$KYSO_FRONT_ENDPOINT_TMPL"
  _ep_yaml="$KYSO_FRONT_ENDPOINT_YAML"
  _service_tmpl="$KYSO_FRONT_SERVICE_TMPL"
  _service_yaml="$KYSO_FRONT_SERVICE_YAML"
  _deploy_tmpl="$KYSO_FRONT_DEPLOY_TMPL"
  _deploy_yaml="$KYSO_FRONT_DEPLOY_YAML"
  _ingress_tmpl="$KYSO_FRONT_INGRESS_TMPL"
  _ingress_yaml="$KYSO_FRONT_INGRESS_YAML"
  _cert_yamls=""
  for _hostname in $DEPLOYMENT_HOSTNAMES; do
    _cert_yaml="$KYSO_FRONT_KUBECTL_DIR/tls-$_hostname${SOPS_EXT}.yaml"
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
  if [ "$KYSO_FRONT_ENDPOINT" ]; then
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
    _front_addr="${KYSO_FRONT_ENDPOINT%:*}"
    _front_port="${KYSO_FRONT_ENDPOINT#*:}"
    [ "$_front_port" != "$_front_addr" ] || _front_port="$KYSO_FRONT_PORT"
    sed \
      -e "s%__APP__%$_app%" \
      -e "s%__NAMESPACE__%$_ns%" \
      -e "s%__SERVER_ADDR__%$_front_addr%" \
      -e "s%__SERVER_PORT__%$_front_port%" \
      "$_ep_tmpl" >"$_ep_yaml"
    # Use the right service template
    _service_tmpl="$KYSO_FRONT_ENDPOINT_SVC_TMPL"
  else
    # Remove endpoint if switching
    kubectl_delete "$_ep_yaml" || true
    # Adjust the front port
    _front_port="$KYSO_FRONT_PORT"
    # Use the right service template
    _service_tmpl="$KYSO_FRONT_SERVICE_TMPL"
    # Prepare deployment file
    sed \
      -e "s%__APP__%$_app%" \
      -e "s%__NAMESPACE__%$_ns%" \
      -e "s%__FRONT_REPLICAS__%$KYSO_FRONT_REPLICAS%" \
      -e "s%__FRONT_IMAGE__%$KYSO_FRONT_IMAGE%" \
      -e "s%__IMAGE_PULL_POLICY__%$DEPLOYMENT_IMAGE_PULL_POLICY%" \
      "$_deploy_tmpl" >"$_deploy_yaml"
  fi
  # Create certificate secrets if needed or remove them if not
  if is_selected "$DEPLOYMENT_INGRESS_TLS_CERTS"; then
    create_app_cert_yamls "$_ns" "$KYSO_FRONT_KUBECTL_DIR"
  else
    for _hostname in $DEPLOYMENT_HOSTNAMES; do
      _cert_yaml="$KYSO_FRONT_KUBECTL_DIR/tls-$_hostname${SOPS_EXT}.yaml"
      kubectl_delete "$_cert_yaml" || true
    done
  fi
  # Create ingress definition
  create_app_ingress_yaml "$_ns" "$_app" "$_ingress_tmpl" "$_ingress_yaml" \
    "" ""
  sed -i -e "s%__PATH_PREFIX__%$KYSO_FRONT_PATH_PREFIX%" "$_ingress_yaml"
  # Prepare service_yaml
  sed \
    -e "s%__APP__%$_app%" \
    -e "s%__NAMESPACE__%$_ns%" \
    -e "s%__SERVER_PORT__%$_front_port%" \
    "$_service_tmpl" >"$_service_yaml"
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

apps_kyso_front_reinstall() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_front_export_variables "$_deployment" "$_cluster"
  _app="kyso-front"
  _ns="$KYSO_FRONT_NAMESPACE"
  if find_namespace "$_ns"; then
    _cimages="$(deployment_container_images "$_ns" "$_app")"
    _cname="kyso-front"
    KYSO_FRONT_IMAGE="$(echo "$_cimages" | sed -ne "s/^$_cname //p")"
    if [ "$KYSO_FRONT_IMAGE" ]; then
      export KYSO_FRONT_IMAGE
      apps_kyso_front_install "$_deployment" "$_cluster"
    else
      echo "Image for '$_app' on '$_ns' not found!"
    fi
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

apps_kyso_front_remove() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_front_export_variables "$_deployment" "$_cluster"
  _app="kyso-front"
  _ns="$KYSO_FRONT_NAMESPACE"
  _svc_yaml="$KYSO_FRONT_SVC_YAML"
  _deploy_yaml="$KYSO_FRONT_DEPLOY_YAML"
  _ingress_yaml="$KYSO_FRONT_INGRESS_YAML"
  _cert_yamls=""
  for _hostname in $DEPLOYMENT_HOSTNAMES; do
    _cert_yaml="$KYSO_FRONT_KUBECTL_DIR/tls-$_hostname${SOPS_EXT}.yaml"
    _cert_yamls="$_cert_yamls $_cert_yaml"
  done
  apps_kyso_front_export_variables
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
  apps_kyso_front_clean_directories
}

apps_kyso_front_restart() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_front_export_variables "$_deployment" "$_cluster"
  _app="kyso-front"
  _ns="$KYSO_FRONT_NAMESPACE"
  if find_namespace "$_ns"; then
    deployment_restart "$_ns" "$_app"
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

apps_kyso_front_status() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_front_export_variables "$_deployment" "$_cluster"
  _app="kyso-front"
  _ns="$KYSO_FRONT_NAMESPACE"
  if find_namespace "$_ns"; then
    kubectl get all,endpoints,ingress,secrets -n "$_ns"
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

apps_kyso_front_summary() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_front_export_variables "$_deployment" "$_cluster"
  _ns="$KYSO_FRONT_NAMESPACE"
  _app="kyso-front"
  deployment_summary "$_ns" "$_app"
}

apps_kyso_front_uris() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_api_export_variables "$_deployment" "$_cluster"
  _hostname="${DEPLOYMENT_HOSTNAMES%% *}"
  echo "https://$_hostname/"
}

apps_kyso_front_env_edit() {
  if [ "$EDITOR" ]; then
    _app="kyso-front"
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

apps_kyso_front_env_path() {
  _app="kyso-front"
  _deployment="$1"
  _cluster="$2"
  apps_export_variables "$_deployment" "$_cluster"
  _env_file="$DEPLOY_ENVS_DIR/$_app.env"
  echo "$_env_file"
}

apps_kyso_front_env_save() {
  _app="kyso-front"
  _deployment="$1"
  _cluster="$2"
  _env_file="$3"
  apps_kyso_front_check_directories
  apps_kyso_front_print_variables "$_deployment" "$_cluster" |
    stdout_to_file "$_env_file"
}

apps_kyso_front_env_update() {
  _app="kyso-front"
  _deployment="$1"
  _cluster="$2"
  apps_export_variables "$_deployment" "$_cluster"
  _env_file="$DEPLOY_ENVS_DIR/$_app.env"
  header "$_app configuration variables"
  apps_kyso_front_print_variables "$_deployment" "$_cluster" |
    grep -v "^#"
  if [ -f "$_env_file" ]; then
    footer
    read_bool "Update $_app env vars?" "No"
  else
    READ_VALUE="Yes"
  fi
  if is_selected "${READ_VALUE}"; then
    footer
    apps_kyso_front_read_variables
    if [ -f "$_env_file" ]; then
      footer
      read_bool "Save updated $_app env vars?" "Yes"
    else
      READ_VALUE="Yes"
    fi
    if is_selected "${READ_VALUE}"; then
      apps_kyso_front_env_save "$_deployment" "$_cluster" "$_env_file"
      footer
      echo "$_app configuration saved to '$_env_file'"
      footer
    fi
  fi
}

apps_kyso_front_command() {
  _command="$1"
  _deployment="$2"
  _cluster="$3"
  case "$_command" in
  env-edit | env_edit)
    apps_kyso_front_env_edit "$_deployment" "$_cluster"
    ;;
  env-path | env_path)
    apps_kyso_front_env_path "$_deployment" "$_cluster"
    ;;
  env-show | env_show)
    apps_kyso_front_print_variables "$_deployment" "$_cluster" | grep -v '^#'
    ;;
  env-update | env_update)
    apps_kyso_front_env_update "$_deployment" "$_cluster"
    ;;
  logs) apps_kyso_front_logs "$_deployment" "$_cluster" ;;
  install) apps_kyso_front_install "$_deployment" "$_cluster" ;;
  reinstall) apps_kyso_front_reinstall "$_deployment" "$_cluster" ;;
  remove) apps_kyso_front_remove "$_deployment" "$_cluster" ;;
  restart) apps_kyso_front_restart "$_deployment" "$_cluster" ;;
  status) apps_kyso_front_status "$_deployment" "$_cluster" ;;
  summary) apps_kyso_front_summary "$_deployment" "$_cluster" ;;
  uris) apps_kyso_front_uris "$_deployment" "$_cluster" ;;
  *)
    echo "Unknown kyso-front subcommand '$1'"
    exit 1
    ;;
  esac
}

apps_kyso_front_command_list() {
  _cmnds="env-edit env-path env-show env-update install logs reinstall remove"
  _cmnds="$_cmnds restart status summary uris"
  echo "$_cmnds"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
