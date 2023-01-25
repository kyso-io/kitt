#!/bin/sh
# ----
# File:        apps/kyso-front.sh
# Description: Functions to manage kyso-front deployments for kyso on k8s
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022-2023 Sergio Talens-Oliag <sto@kyso.io>
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
export KYSO_FRONT_SERVER_PORT="3000"

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
  export KYSO_FRONT_CHART_DIR="$CHARTS_DIR/kyso-front"
  export KYSO_FRONT_TMPL_DIR="$TMPL_DIR/apps/kyso-front"
  export KYSO_FRONT_HELM_DIR="$DEPLOY_HELM_DIR/kyso-front"
  export KYSO_FRONT_KUBECTL_DIR="$DEPLOY_KUBECTL_DIR/kyso-front"
  export KYSO_FRONT_SECRETS_DIR="$DEPLOY_SECRETS_DIR/kyso-front"
  # Templates
  export KYSO_FRONT_HELM_VALUES_TMPL="$KYSO_FRONT_TMPL_DIR/values.yaml"
  export KYSO_FRONT_SVC_MAP_TMPL="$KYSO_FRONT_TMPL_DIR/svc_map.yaml"
  # BEG: deprecated files
  export KYSO_FRONT_DEPLOY_YAML="$KYSO_FRONT_KUBECTL_DIR/deploy.yaml"
  export KYSO_FRONT_ENDPOINT_YAML="$KYSO_FRONT_KUBECTL_DIR/endpoint.yaml"
  export KYSO_FRONT_SERVICE_YAML="$KYSO_FRONT_KUBECTL_DIR/service.yaml"
  export KYSO_FRONT_INGRESS_YAML="$KYSO_FRONT_KUBECTL_DIR/ingress.yaml"
  # END: deprecated files
  # Files
  _helm_values_yaml="$KYSO_FRONT_HELM_DIR/values${SOPS_EXT}.yaml"
  _helm_values_yaml_plain="$KYSO_FRONT_HELM_DIR/values.yaml"
  export KYSO_FRONT_HELM_VALUES_YAML="${_helm_values_yaml}"
  export KYSO_FRONT_HELM_VALUES_YAML_PLAIN="${_helm_values_yaml_plain}"
  export KYSO_FRONT_SVC_MAP_YAML="$KYSO_FRONT_KUBECTL_DIR/svc_map.yaml"
  # By default don't auto save the environment
  KYSO_FRONT_AUTO_SAVE_ENV="false"
  # Use defaults for variables missing from config files / enviroment
  if [ -z "$KYSO_FRONT_ENDPOINT" ]; then
    if [ "$DEPLOYMENT_KYSO_FRONT_ENDPOINT" ]; then
      KYSO_FRONT_ENDPOINT="$DEPLOYMENT_KYSO_FRONT_ENDPOINT"
    else
      KYSO_FRONT_ENDPOINT="$DEPLOYMENT_DEFAULT_KYSO_FRONT_ENDPOINT"
    fi
  else
    KYSO_FRONT_AUTO_SAVE_ENV="true"
  fi
  if [ -z "$KYSO_FRONT_IMAGE" ]; then
    if [ "$DEPLOYMENT_KYSO_FRONT_IMAGE" ]; then
      KYSO_FRONT_IMAGE="$DEPLOYMENT_KYSO_FRONT_IMAGE"
    else
      KYSO_FRONT_IMAGE="$DEPLOYMENT_DEFAULT_KYSO_FRONT_IMAGE"
    fi
  else
    KYSO_FRONT_AUTO_SAVE_ENV="true"
  fi
  export KYSO_FRONT_IMAGE
  if [ -z "$KYSO_FRONT_PATH_PREFIX" ]; then
    if [ "$DEPLOYMENT_KYSO_FRONT_PATH_PREFIX" ]; then
      KYSO_FRONT_PATH_PREFIX="$DEPLOYMENT_KYSO_FRONT_PATH_PREFIX"
    else
      KYSO_FRONT_PATH_PREFIX="$DEPLOYMENT_DEFAULT_KYSO_FRONT_PATH_PREFIX"
    fi
  else
    KYSO_FRONT_AUTO_SAVE_ENV="true"
  fi
  export KYSO_FRONT_PATH_PREFIX
  if [ "$DEPLOYMENT_KYSO_FRONT_REPLICAS" ]; then
    KYSO_FRONT_REPLICAS="$DEPLOYMENT_KYSO_FRONT_REPLICAS"
  else
    KYSO_FRONT_REPLICAS="$DEPLOYMENT_DEFAULT_KYSO_FRONT_REPLICAS"
  fi
  export KYSO_FRONT_REPLICAS
  # Export auto save environment flag
  export KYSO_FRONT_AUTO_SAVE_ENV
  __apps_kyso_front_export_variables="1"
}

apps_kyso_front_check_directories() {
  apps_common_check_directories
  for _d in "$KYSO_FRONT_HELM_DIR" "$KYSO_FRONT_KUBECTL_DIR" \
    "$KYSO_FRONT_SECRETS_DIR"; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

apps_kyso_front_clean_directories() {
  # Try to remove empty dirs, except if they contain secrets
  for _d in "$KYSO_FRONT_HELM_DIR" "$KYSO_FRONT_KUBECTL_DIR" \
    "$KYSO_FRONT_SECRETS_DIR"; do
    if [ -d "$_d" ]; then
      rmdir "$_d" 2>/dev/null || true
    fi
  done
}

apps_kyso_front_read_variables() {
  _app="kyso-front"
  header "Reading $_app settings"
  _ex_ep="$LINUX_HOST_IP:$KYSO_FRONT_SERVER_PORT"
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
# - '$LINUX_HOST_IP:$KYSO_FRONT_SERVER_PORT' on Linux
# - '$MACOS_HOST_IP:$KYSO_FRONT_SERVER_PORT' on systems using Docker Desktop
KYSO_FRONT_ENDPOINT=$KYSO_FRONT_ENDPOINT
# Kyso Front Image URI, examples for local testing:
# - 'registry.kyso.io/kyso-io/kyso-front/develop:latest'
# - 'k3d-registry.lo.kyso.io:5000/kyso-front:latest'
# If empty the KYSO_FRONT_IMAGE environment variable has to be set each time
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
  _app="kyso-front"
  if kubectl get -n "$_ns" "deployments/$_app" >/dev/null 2>&1; then
    kubectl -n "$_ns" logs "deployments/$_app" -f
  else
    echo "Deployment '$_app' not found on namespace '$_ns'"
  fi
}

apps_kyso_front_sh() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_front_export_variables "$_deployment" "$_cluster"
  _ns="$KYSO_FRONT_NAMESPACE"
  _app="kyso-front"
  if kubectl get -n "$_ns" "deployments/$_app" >/dev/null 2>&1; then
    kubectl -n "$_ns" exec -ti "deployments/$_app" -- /bin/sh
  else
    echo "Deployment '$_app' not found on namespace '$_ns'"
  fi
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
  # Initial test
  if ! find_namespace "$MONGODB_NAMESPACE"; then
    read_bool "mongodb namespace not found, abort install?" "Yes"
    if is_selected "${READ_VALUE}"; then
      return 1
    fi
  fi
  # Auto save the configuration if requested
  if is_selected "$KYSO_FRONT_AUTO_SAVE_ENV"; then
    apps_kyso_front_env_save "$_deployment" "$_cluster"
  fi
  # Load additional variables & check directories
  apps_common_export_service_hostnames "$_deployment" "$_cluster"
  apps_kyso_front_check_directories
  # Adjust variables
  _app="kyso-front"
  _ns="$KYSO_FRONT_NAMESPACE"
  # directory
  _chart="$KYSO_FRONT_CHART_DIR"
  # deprecated yaml files
  _auth_yaml="$KYSO_FRONT_AUTH_YAML"
  _deploy_yaml="$KYSO_FRONT_DEPLOY_YAML"
  _ingress_docs_yaml="$KYSO_FRONT_INGRESS_DOCS_YAML"
  _ingress_yaml="$KYSO_FRONT_INGRESS_YAML"
  _service_yaml="$KYSO_FRONT_SERVICE_YAML"
  # files
  _helm_values_tmpl="$KYSO_FRONT_HELM_VALUES_TMPL"
  _helm_values_yaml="$KYSO_FRONT_HELM_VALUES_YAML"
  _helm_values_yaml_plain="$KYSO_FRONT_HELM_VALUES_YAML_PLAIN"
  _svc_map_tmpl="$KYSO_FRONT_SVC_MAP_TMPL"
  _svc_map_yaml="$KYSO_FRONT_SVC_MAP_YAML"
  _auth_user="$KYSO_FRONT_BASIC_AUTH_USER"
  if is_selected "$CLUSTER_USE_BASIC_AUTH" &&
    is_selected "$KYSO_FRONT_DOCS_INGRESS"; then
    auth_file_update "$KYSO_FRONT_BASIC_AUTH_USER" "$KYSO_FRONT_AUTH_FILE"
    _auth_pass="$(
      file_to_stdout "$KYSO_FRONT_AUTH_FILE" | sed -ne "s/^${_auth_user}://p"
    )"
  else
    _auth_pass=""
  fi
  _cert_yamls=""
  for _hostname in $DEPLOYMENT_HOSTNAMES; do
    _cert_yaml="$KYSO_FRONT_KUBECTL_DIR/tls-$_hostname${SOPS_EXT}.yaml"
    _cert_yamls="$_cert_yamls $_cert_yaml"
  done
  if ! find_namespace "$_ns"; then
    # Remove old files, just in case ...
    # shellcheck disable=SC2086
    rm -f "$_helm_values_yaml" "$_svc_map_yaml" \
      "$_ep_yaml" "$_auth_yaml" "$_service_yaml" "$_deploy_yaml" \
      "$_ingress_yaml" "$_ingress_docs_yaml" $_cert_yamls
    # Create namespace
    create_namespace "$_ns"
  fi
  # If we have a legacy deployment, remove the old objects
  for _yaml in "$_ep_yaml" "$_auth_yaml" "$_service_yaml" "$_deploy_yaml" \
    "$_ingress_yaml" "$_ingress_docs_yaml"; do
    kubectl_delete "$_yaml" || true
  done
  # Image settings
  _image_repo="${KYSO_FRONT_IMAGE%:*}"
  _image_tag="${KYSO_FRONT_IMAGE#*:}"
  if [ "$_image_repo" = "$_image_tag" ]; then
    _image_tag="latest"
  fi
  # Endpoint settings
  if [ "$KYSO_FRONT_ENDPOINT" ]; then
    # Generate / update endpoint values
    _ep_enabled="true"
  else
    # Adjust the front port
    _ep_enabled="false"
  fi
  _ep_addr="${KYSO_FRONT_ENDPOINT%:*}"
  _ep_port="${KYSO_FRONT_ENDPOINT#*:}"
  [ "$_ep_port" != "$_ep_addr" ] || _ep_port="$KYSO_FRONT_SERVER_PORT"
  # Service settings
  _server_port="$KYSO_FRONT_SERVER_PORT"
  # Get the database uri
  _mongodb_user_database_uri="$(
    apps_mongodb_print_user_database_uri "$_deployment" "$_cluster"
  )"
  # Prepare values.yaml file
  sed \
    -e "s%__FRONT_REPLICAS__%$KYSO_FRONT_REPLICAS%" \
    -e "s%__FRONT_IMAGE_REPO__%$_image_repo%" \
    -e "s%__FRONT_IMAGE_TAG__%$_image_tag%" \
    -e "s%__IMAGE_PULL_POLICY__%$DEPLOYMENT_IMAGE_PULL_POLICY%" \
    -e "s%__PULL_SECRETS_NAME__%$CLUSTER_PULL_SECRETS_NAME%" \
    -e "s%__FRONT_ENDPOINT_ENABLED__%$_ep_enabled%" \
    -e "s%__FRONT_ENDPOINT_ADDR__%$_ep_addr%" \
    -e "s%__FRONT_ENDPOINT_PORT__%$_ep_port%" \
    -e "s%__FRONT_SERVER_PORT__%$_server_port%" \
    "$_helm_values_tmpl" > "$_helm_values_yaml_plain"
  # Apply ingress values
  replace_app_ingress_values "$_app" "$_helm_values_yaml_plain"
  # Generate encoded version if needed and remove plain version
  if [ "$_helm_values_yaml" != "$_helm_values_yaml_plain" ]; then
    stdout_to_file "$_helm_values_yaml" <"$_helm_values_yaml_plain"
    rm -f "$_helm_values_yaml_plain"
  fi
  # Prepare svc_map file
  sed \
    -e "s%__NAMESPACE__%$_ns%" \
    -e "s%__ELASTICSEARCH_SVC_HOSTNAME__%$ELASTICSEARCH_SVC_HOSTNAME%" \
    -e "s%__KYSO_SCS_SVC_HOSTNAME__%$KYSO_SCS_SVC_HOSTNAME%" \
    -e "s%__MONGODB_SVC_HOSTNAME__%$MONGODB_SVC_HOSTNAME%" \
    -e "s%__NATS_SVC_HOSTNAME__%$NATS_SVC_HOSTNAME%" \
    "$_svc_map_tmpl" >"$_svc_map_yaml"
  # Create certificate secrets if needed or remove them if not
  if is_selected "$DEPLOYMENT_INGRESS_TLS_CERTS"; then
    create_app_cert_yamls "$_ns" "$KYSO_FRONT_KUBECTL_DIR"
  else
    for _cert_yaml in $_cert_yamls; do
      kubectl_delete "$_cert_yaml" || true
    done
  fi
  # Install map and certs
  for _yaml in "$_svc_map_yaml" $_cert_yamls; do
    kubectl_apply "$_yaml"
  done
  # If moving from deployment to endpoint add annotations to the automatic
  # endpoint to avoid issues with the upgrade
  if [ "$KYSO_FRONT_ENDPOINT" ]; then
    if [ "$(kubectl get -n "$_ns" "deployments" -o name)" ]; then
      kubectl annotate -n "$_ns" --overwrite "endpoints/$_app" \
        "meta.helm.sh/release-name=$_app" \
        "meta.helm.sh/release-namespace=$_ns"
    fi
  fi
  # Install helm chart
  helm_upgrade "$_ns" "$_helm_values_yaml" "$_app" "$_chart"
  # Wait until deployment succeds or fails (if there is one, of course)
  if [ -z "$KYSO_FRONT_ENDPOINT" ]; then
    kubectl rollout status deployment --timeout="$ROLLOUT_STATUS_TIMEOUT" \
      -n "$_ns" "$_app"
  fi
}

apps_kyso_front_helm_history() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_front_export_variables "$_deployment" "$_cluster"
  _app="kyso-front"
  _ns="$KYSO_FRONT_NAMESPACE"
  if find_namespace "$_ns"; then
    helm_history "$_ns" "$_app"
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

apps_kyso_front_helm_rollback() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_front_export_variables "$_deployment" "$_cluster"
  _app="kyso-front"
  _ns="$KYSO_FRONT_NAMESPACE"
  _release="$ROLLBACK_RELEASE"
  if find_namespace "$_ns"; then
    # Add annotations to the endpoint if we have a deployment, just in case
    if [ "$(kubectl get -n "$_ns" "deployments" -o name)" ]; then
      kubectl annotate -n "$_ns" --overwrite "endpoints/$_app" \
        "meta.helm.sh/release-name=$_app" \
        "meta.helm.sh/release-namespace=$_ns"
    fi
    # Execute the rollback
    helm_rollback "$_ns" "$_app" "$_release"
    # If we succeed update the front settings
    apps_kyso_update_front_settings "$_deployment" "$_cluster"
  else
    echo "Namespace '$_ns' for '$_app' not found!"
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
  # deprecated yaml files
  _auth_yaml="$KYSO_FRONT_AUTH_YAML"
  _deploy_yaml="$KYSO_FRONT_DEPLOY_YAML"
  _ep_yaml="$KYSO_FRONT_ENDPOINT_YAML"
  _ingress_yaml="$KYSO_FRONT_INGRESS_YAML"
  _service_yaml="$KYSO_FRONT_SERVICE_YAML"
  # files
  _helm_values_yaml="$KYSO_FRONT_HELM_VALUES_YAML"
  _svc_map_yaml="$KYSO_FRONT_SVC_MAP_YAML"
  _cert_yamls=""
  for _hostname in $DEPLOYMENT_HOSTNAMES; do
    _cert_yaml="$KYSO_FRONT_KUBECTL_DIR/tls-$_hostname${SOPS_EXT}.yaml"
    _cert_yamls="$_cert_yamls $_cert_yaml"
  done
  if find_namespace "$_ns"; then
    header "Removing '$_app' objects"
    # Uninstall chart
    if [ -f "$_helm_values_yaml" ]; then
      helm uninstall -n "$_ns" "$_app" || true
      rm -f "$_helm_values_yaml"
    fi
    # Remove objects
    for _yaml in "$_svc_map_yaml" $_cert_yamls; do
      kubectl_delete "$_yaml" || true
    done
    # Remove legacy objects
    for _yaml in "$_ep_yaml" "$_auth_yaml" "$_service_yaml" "$_deploy_yaml" \
      "$_ingress_yaml"; do
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
  _ep="$KYSO_FRONT_ENDPOINT"
  if [ "$_ep" ]; then
    _endpoint="$(
      kubectl get endpoints -n "$_ns" -l "app.kubernetes.io/name=$_app" -o name
    )"
    if [ "$_endpoint" ]; then
      echo "FOUND endpoint for '$_app' in namespace '$_ns'"
      echo "- $_endpoint: $_ep"
    else
      echo "MISSING endpoint for '$_app' in namespace '$_ns'"
    fi
  else
    deployment_summary "$_ns" "$_app"
  fi
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
  apps_export_variables "$_deployment" "$_cluster"
  _env_file="$DEPLOY_ENVS_DIR/$_app.env"
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
    [ "$KITT_AUTOUPDATE" = "true" ] && _update="Yes" || _update="No"
    read_bool "Update $_app env vars?" "$_update"
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
      apps_kyso_front_env_save "$_deployment" "$_cluster"
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
  helm-history) apps_kyso_front_helm_history "$_deployment" "$_cluster" ;;
  helm-rollback) apps_kyso_front_helm_rollback "$_deployment" "$_cluster" ;;
  install) apps_kyso_front_install "$_deployment" "$_cluster" ;;
  logs) apps_kyso_front_logs "$_deployment" "$_cluster" ;;
  reinstall) apps_kyso_front_reinstall "$_deployment" "$_cluster" ;;
  remove) apps_kyso_front_remove "$_deployment" "$_cluster" ;;
  restart) apps_kyso_front_restart "$_deployment" "$_cluster" ;;
  sh) apps_kyso_front_sh "$_deployment" "$_cluster" ;;
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
  _cmnds="env-edit env-path env-show env-update helm-history helm-rollback"
  _cmnds="$_cmnds install logs reinstall remove restart sh status summary uris"
  echo "$_cmnds"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
