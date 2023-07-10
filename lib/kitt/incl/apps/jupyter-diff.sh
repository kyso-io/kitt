#!/bin/sh
# ----
# File:        apps/jupyter-diff.sh
# Description: Functions to manage jupyter-diff deployments for kyso on k8s
# Author:      Francisco Javier Barrena <francisco@kyso.io>
# Copyright:   (c) 2022-2023 Kyso Inc.
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_APPS_JUPYTER_DIFF_SH="1"

# ---------
# Variables
# ---------

# CMND_DSC="jupyter-diff: manage jupyter-diff deployment for kyso"

# Defaults
export DEPLOYMENT_DEFAULT_JUPYTER_DIFF_ENDPOINT=""
export DEPLOYMENT_DEFAULT_JUPYTER_DIFF_IMAGE=""
export DEPLOYMENT_DEFAULT_JUPYTER_DIFF_PATH_PREFIX="/"
export DEPLOYMENT_DEFAULT_JUPYTER_DIFF_REPLICAS="1"

# Fixed values
export JUPYTER_DIFF_SERVER_PORT="3000"

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

apps_jupyter_diff_export_variables() {
  [ -z "$__apps_jupyter_diff_export_variables" ] || return 0
  _deployment="$1"
  _cluster="$2"
  apps_common_export_variables "$_deployment" "$_cluster"
  
  # Probably not needed
  # apps_mongodb_export_variables "$_deployment" "$_cluster"
  
  # Values
  export JUPYTER_DIFF_NAMESPACE="jupyter-diff-$DEPLOYMENT_NAME"
  # Charts
  _repo_name="$KYSO_HELM_REPO_NAME"
  export JUPYTER_DIFF_CHART="$_repo_name/jupyter-diff"
  # Directories
  export JUPYTER_DIFF_TMPL_DIR="$TMPL_DIR/apps/jupyter-diff"
  export JUPYTER_DIFF_HELM_DIR="$DEPLOY_HELM_DIR/jupyter-diff"
  export JUPYTER_DIFF_KUBECTL_DIR="$DEPLOY_KUBECTL_DIR/jupyter-diff"
  export JUPYTER_DIFF_SECRETS_DIR="$DEPLOY_SECRETS_DIR/jupyter-diff"
  # Templates
  export JUPYTER_DIFF_HELM_VALUES_TMPL="$JUPYTER_DIFF_TMPL_DIR/values.yaml"
  export JUPYTER_DIFF_SVC_MAP_TMPL="$JUPYTER_DIFF_TMPL_DIR/svc_map.yaml"
  # BEG: deprecated files
  export JUPYTER_DIFF_DEPLOY_YAML="$JUPYTER_DIFF_KUBECTL_DIR/deploy.yaml"
  export JUPYTER_DIFF_ENDPOINT_YAML="$JUPYTER_DIFF_KUBECTL_DIR/endpoint.yaml"
  export JUPYTER_DIFF_SERVICE_YAML="$JUPYTER_DIFF_KUBECTL_DIR/service.yaml"
  export JUPYTER_DIFF_INGRESS_YAML="$JUPYTER_DIFF_KUBECTL_DIR/ingress.yaml"
  # END: deprecated files
  # Files
  _helm_values_yaml="$JUPYTER_DIFF_HELM_DIR/values${SOPS_EXT}.yaml"
  _helm_values_yaml_plain="$JUPYTER_DIFF_HELM_DIR/values.yaml"
  export JUPYTER_DIFF_HELM_VALUES_YAML="${_helm_values_yaml}"
  export JUPYTER_DIFF_HELM_VALUES_YAML_PLAIN="${_helm_values_yaml_plain}"
  export JUPYTER_DIFF_SVC_MAP_YAML="$JUPYTER_DIFF_KUBECTL_DIR/svc_map.yaml"
  # By default don't auto save the environment
  JUPYTER_DIFF_AUTO_SAVE_ENV="false"
  # Use defaults for variables missing from config files / enviroment
  if [ -z "$JUPYTER_DIFF_ENDPOINT" ]; then
    if [ "$DEPLOYMENT_JUPYTER_DIFF_ENDPOINT" ]; then
      JUPYTER_DIFF_ENDPOINT="$DEPLOYMENT_JUPYTER_DIFF_ENDPOINT"
    else
      JUPYTER_DIFF_ENDPOINT="$DEPLOYMENT_DEFAULT_JUPYTER_DIFF_ENDPOINT"
    fi
  else
    JUPYTER_DIFF_AUTO_SAVE_ENV="true"
  fi
  if [ -z "$JUPYTER_DIFF_IMAGE" ]; then
    if [ "$DEPLOYMENT_JUPYTER_DIFF_IMAGE" ]; then
      JUPYTER_DIFF_IMAGE="$DEPLOYMENT_JUPYTER_DIFF_IMAGE"
    else
      JUPYTER_DIFF_IMAGE="$DEPLOYMENT_DEFAULT_JUPYTER_DIFF_IMAGE"
    fi
  else
    JUPYTER_DIFF_AUTO_SAVE_ENV="true"
  fi
  export JUPYTER_DIFF_IMAGE
  if [ -z "$JUPYTER_DIFF_PATH_PREFIX" ]; then
    if [ "$DEPLOYMENT_JUPYTER_DIFF_PATH_PREFIX" ]; then
      JUPYTER_DIFF_PATH_PREFIX="$DEPLOYMENT_JUPYTER_DIFF_PATH_PREFIX"
    else
      JUPYTER_DIFF_PATH_PREFIX="$DEPLOYMENT_DEFAULT_JUPYTER_DIFF_PATH_PREFIX"
    fi
  else
    JUPYTER_DIFF_AUTO_SAVE_ENV="true"
  fi
  export JUPYTER_DIFF_PATH_PREFIX
  if [ "$DEPLOYMENT_JUPYTER_DIFF_REPLICAS" ]; then
    JUPYTER_DIFF_REPLICAS="$DEPLOYMENT_JUPYTER_DIFF_REPLICAS"
  else
    JUPYTER_DIFF_REPLICAS="$DEPLOYMENT_DEFAULT_JUPYTER_DIFF_REPLICAS"
  fi
  export JUPYTER_DIFF_REPLICAS
  # Export auto save environment flag
  export JUPYTER_DIFF_AUTO_SAVE_ENV
  __apps_jupyter_diff_export_variables="1"
}

apps_jupyter_diff_check_directories() {
  apps_common_check_directories
  for _d in "$JUPYTER_DIFF_HELM_DIR" "$JUPYTER_DIFF_KUBECTL_DIR" \
    "$JUPYTER_DIFF_SECRETS_DIR"; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

apps_jupyter_diff_clean_directories() {
  # Try to remove empty dirs, except if they contain secrets
  for _d in "$JUPYTER_DIFF_HELM_DIR" "$JUPYTER_DIFF_KUBECTL_DIR" \
    "$JUPYTER_DIFF_SECRETS_DIR"; do
    if [ -d "$_d" ]; then
      rmdir "$_d" 2>/dev/null || true
    fi
  done
}

apps_jupyter_diff_read_variables() {
  _app="jupyter-diff"
  header "Reading $_app settings"
  _ex_ep="$LINUX_HOST_IP:$JUPYTER_DIFF_SERVER_PORT"
  read_value "jupyter-diff endpoint (i.e. '$_ex_ep' or '-' to deploy image)" \
    "${JUPYTER_DIFF_ENDPOINT}"
  JUPYTER_DIFF_ENDPOINT=${READ_VALUE}
  _ex_img="registry.kyso.io/kyso-io/microfrontends/jupyter-diff/develop:latest"
  read_value \
    "jupyter-diff Image URI (i.e. '$_ex_img' or export JUPYTER_DIFF_IMAGE env var)" \
    "${JUPYTER_DIFF_IMAGE}"
  JUPYTER_DIFF_IMAGE=${READ_VALUE}
  read_value "jupyter-diff PATH Prefix" "${JUPYTER_DIFF_PATH_PREFIX}"
  JUPYTER_DIFF_PATH_PREFIX=${READ_VALUE}
  read_value "jupyter-diff Front Replicas" "${JUPYTER_DIFF_REPLICAS}"
  JUPYTER_DIFF_REPLICAS=${READ_VALUE}
}

apps_jupyter_diff_print_variables() {
  _app="jupyter-diff"
  cat <<EOF
# Deployment $_app settings
# ---
# Endpoint for jupyter-diff (replaces the real deployment on development systems),
# set to:
# - '$LINUX_HOST_IP:$JUPYTER_DIFF_SERVER_PORT' on Linux
# - '$MACOS_HOST_IP:$JUPYTER_DIFF_SERVER_PORT' on systems using Docker Desktop
JUPYTER_DIFF_ENDPOINT=$JUPYTER_DIFF_ENDPOINT
# jupyter-diff Image URI, examples for local testing:
# - 'registry.kyso.io/kyso-io/microfrontends/jupyter-diff/develop:latest'
# - 'k3d-registry.lo.kyso.io:5000/jupyter-diff:latest'
# If empty the JUPYTER_DIFF_IMAGE environment variable has to be set each time
# the jupyter-diff service is installed
JUPYTER_DIFF_IMAGE=$JUPYTER_DIFF_IMAGE
# jupyter-diff PATH Prefix
JUPYTER_DIFF_PATH_PREFIX=$JUPYTER_DIFF_PATH_PREFIX
# Number of pods to run in parallel
JUPYTER_DIFF_REPLICAS=$JUPYTER_DIFF_REPLICAS
# ---
EOF
}

apps_jupyter_diff_logs() {
  _deployment="$1"
  _cluster="$2"
  apps_jupyter_diff_export_variables "$_deployment" "$_cluster"
  _ns="$JUPYTER_DIFF_NAMESPACE"
  _app="jupyter-diff"
  if kubectl get -n "$_ns" "deployments/$_app" >/dev/null 2>&1; then
    kubectl -n "$_ns" logs "deployments/$_app" -f
  else
    echo "Deployment '$_app' not found on namespace '$_ns'"
  fi
}

apps_jupyter_diff_sh() {
  _deployment="$1"
  _cluster="$2"
  apps_jupyter_diff_export_variables "$_deployment" "$_cluster"
  _ns="$JUPYTER_DIFF_NAMESPACE"
  _app="jupyter-diff"
  if kubectl get -n "$_ns" "deployments/$_app" >/dev/null 2>&1; then
    kubectl -n "$_ns" exec -ti "deployments/$_app" -- /bin/sh
  else
    echo "Deployment '$_app' not found on namespace '$_ns'"
  fi
}

apps_jupyter_diff_install() {
  _deployment="$1"
  _cluster="$2"
  apps_jupyter_diff_export_variables "$_deployment" "$_cluster"
  if [ -z "$JUPYTER_DIFF_ENDPOINT" ] && [ -z "$JUPYTER_DIFF_IMAGE" ]; then
    echo "The FRONT_IMAGE & FRONT_ENDPOINT variables are empty."
    echo "Export JUPYTER_DIFF_IMAGE or JUPYTER_DIFF_ENDPOINT or reconfigure."
    exit 1
  fi
  # Initial test - Not needed I guess
  #if ! find_namespace "$MONGODB_NAMESPACE"; then
  #  read_bool "mongodb namespace not found, abort install?" "Yes"
  #  if is_selected "${READ_VALUE}"; then
  #    return 1
  #  fi
  #fi
  # Auto save the configuration if requested
  if is_selected "$JUPYTER_DIFF_AUTO_SAVE_ENV"; then
    apps_jupyter_diff_env_save "$_deployment" "$_cluster"
  fi
  # Load additional variables & check directories
  apps_common_export_service_hostnames "$_deployment" "$_cluster"
  apps_jupyter_diff_check_directories
  # Check kyso helm repo
  check_kyso_helm_repo
  # Adjust variables
  _app="jupyter-diff"
  _ns="$JUPYTER_DIFF_NAMESPACE"
  # directory
  _chart="$JUPYTER_DIFF_CHART"
  # deprecated yaml files
  _deploy_yaml="$JUPYTER_DIFF_DEPLOY_YAML"
  _ingress_yaml="$JUPYTER_DIFF_INGRESS_YAML"
  _service_yaml="$JUPYTER_DIFF_SERVICE_YAML"
  # files
  _helm_values_tmpl="$JUPYTER_DIFF_HELM_VALUES_TMPL"
  _helm_values_yaml="$JUPYTER_DIFF_HELM_VALUES_YAML"
  _helm_values_yaml_plain="$JUPYTER_DIFF_HELM_VALUES_YAML_PLAIN"
  _svc_map_tmpl="$JUPYTER_DIFF_SVC_MAP_TMPL"
  _svc_map_yaml="$JUPYTER_DIFF_SVC_MAP_YAML"
  _cert_yamls=""
  for _hostname in $DEPLOYMENT_HOSTNAMES; do
    _cert_yaml="$JUPYTER_DIFF_KUBECTL_DIR/tls-$_hostname${SOPS_EXT}.yaml"
    _cert_yamls="$_cert_yamls $_cert_yaml"
  done
  if ! find_namespace "$_ns"; then
    # Remove old files, just in case ...
    # shellcheck disable=SC2086
    rm -f "$_helm_values_yaml" "$_svc_map_yaml" "$_ep_yaml" "$_service_yaml" \
      "$_deploy_yaml" "$_ingress_yaml" $_cert_yamls
    # Create namespace
    create_namespace "$_ns"
  fi
  # If we have a legacy deployment, remove the old objects
  for _yaml in "$_ep_yaml" "$_service_yaml" "$_deploy_yaml" \
    "$_ingress_yaml"; do
    kubectl_delete "$_yaml" || true
  done
  # Image settings
  _image_repo="${JUPYTER_DIFF_IMAGE%:*}"
  _image_tag="${JUPYTER_DIFF_IMAGE#*:}"
  if [ "$_image_repo" = "$_image_tag" ]; then
    _image_tag="latest"
  fi
  # Endpoint settings
  if [ "$JUPYTER_DIFF_ENDPOINT" ]; then
    # Generate / update endpoint values
    _ep_enabled="true"
  else
    # Adjust the front port
    _ep_enabled="false"
  fi
  _ep_addr="${JUPYTER_DIFF_ENDPOINT%:*}"
  _ep_port="${JUPYTER_DIFF_ENDPOINT#*:}"
  [ "$_ep_port" != "$_ep_addr" ] || _ep_port="$JUPYTER_DIFF_SERVER_PORT"
  # Service settings
  _server_port="$JUPYTER_DIFF_SERVER_PORT"
  
  # Prepare values.yaml file
  sed \
    -e "s%__FRONT_REPLICAS__%$JUPYTER_DIFF_REPLICAS%" \
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
    create_app_cert_yamls "$_ns" "$JUPYTER_DIFF_KUBECTL_DIR"
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
  if [ "$JUPYTER_DIFF_ENDPOINT" ]; then
    if [ "$(kubectl get -n "$_ns" "deployments" -o name)" ]; then
      kubectl annotate -n "$_ns" --overwrite "endpoints/$_app" \
        "meta.helm.sh/release-name=$_app" \
        "meta.helm.sh/release-namespace=$_ns"
    fi
  fi
  # Install helm chart
  helm_upgrade "$_ns" "$_helm_values_yaml" "$_app" "$_chart"
  # Wait until deployment succeds or fails (if there is one, of course)
  if [ -z "$JUPYTER_DIFF_ENDPOINT" ]; then
    kubectl rollout status deployment --timeout="$ROLLOUT_STATUS_TIMEOUT" \
      -n "$_ns" "$_app"
  fi
}

apps_jupyter_diff_helm_history() {
  _deployment="$1"
  _cluster="$2"
  apps_jupyter_diff_export_variables "$_deployment" "$_cluster"
  _app="jupyter-diff"
  _ns="$JUPYTER_DIFF_NAMESPACE"
  if find_namespace "$_ns"; then
    helm_history "$_ns" "$_app"
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

apps_jupyter_diff_helm_rollback() {
  _deployment="$1"
  _cluster="$2"
  apps_jupyter_diff_export_variables "$_deployment" "$_cluster"
  _app="jupyter-diff"
  _ns="$JUPYTER_DIFF_NAMESPACE"
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

apps_jupyter_diff_reinstall() {
  _deployment="$1"
  _cluster="$2"
  apps_jupyter_diff_export_variables "$_deployment" "$_cluster"
  _app="jupyter-diff"
  _ns="$JUPYTER_DIFF_NAMESPACE"
  if find_namespace "$_ns"; then
    _cimages="$(deployment_container_images "$_ns" "$_app")"
    _cname="jupyter-diff"
    JUPYTER_DIFF_IMAGE="$(echo "$_cimages" | sed -ne "s/^$_cname //p")"
    if [ "$JUPYTER_DIFF_IMAGE" ]; then
      export JUPYTER_DIFF_IMAGE
      apps_jupyter_diff_install "$_deployment" "$_cluster"
    else
      echo "Image for '$_app' on '$_ns' not found!"
    fi
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

apps_jupyter_diff_remove() {
  _deployment="$1"
  _cluster="$2"
  apps_jupyter_diff_export_variables "$_deployment" "$_cluster"
  _app="jupyter-diff"
  _ns="$JUPYTER_DIFF_NAMESPACE"
  # deprecated yaml files
  _deploy_yaml="$JUPYTER_DIFF_DEPLOY_YAML"
  _ep_yaml="$JUPYTER_DIFF_ENDPOINT_YAML"
  _ingress_yaml="$JUPYTER_DIFF_INGRESS_YAML"
  _service_yaml="$JUPYTER_DIFF_SERVICE_YAML"
  # files
  _helm_values_yaml="$JUPYTER_DIFF_HELM_VALUES_YAML"
  _svc_map_yaml="$JUPYTER_DIFF_SVC_MAP_YAML"
  _cert_yamls=""
  for _hostname in $DEPLOYMENT_HOSTNAMES; do
    _cert_yaml="$JUPYTER_DIFF_KUBECTL_DIR/tls-$_hostname${SOPS_EXT}.yaml"
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
    for _yaml in "$_ep_yaml" "$_service_yaml" "$_deploy_yaml" \
      "$_ingress_yaml"; do
      kubectl_delete "$_yaml" || true
    done
    delete_namespace "$_ns"
    footer
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
  apps_jupyter_diff_clean_directories
}

apps_jupyter_diff_restart() {
  _deployment="$1"
  _cluster="$2"
  apps_jupyter_diff_export_variables "$_deployment" "$_cluster"
  _app="jupyter-diff"
  _ns="$JUPYTER_DIFF_NAMESPACE"
  if find_namespace "$_ns"; then
    deployment_restart "$_ns" "$_app"
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

apps_jupyter_diff_status() {
  _deployment="$1"
  _cluster="$2"
  apps_jupyter_diff_export_variables "$_deployment" "$_cluster"
  _app="jupyter-diff"
  _ns="$JUPYTER_DIFF_NAMESPACE"
  if find_namespace "$_ns"; then
    kubectl get all,endpoints,ingress,secrets -n "$_ns"
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

apps_jupyter_diff_summary() {
  _deployment="$1"
  _cluster="$2"
  apps_jupyter_diff_export_variables "$_deployment" "$_cluster"
  _ns="$JUPYTER_DIFF_NAMESPACE"
  _app="jupyter-diff"
  _ep="$JUPYTER_DIFF_ENDPOINT"
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

apps_jupyter_diff_uris() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_api_export_variables "$_deployment" "$_cluster"
  _hostname="${DEPLOYMENT_HOSTNAMES%% *}"
  echo "https://$_hostname/"
}

apps_jupyter_diff_env_edit() {
  if [ "$EDITOR" ]; then
    _app="jupyter-diff"
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

apps_jupyter_diff_env_path() {
  _app="jupyter-diff"
  _deployment="$1"
  _cluster="$2"
  apps_export_variables "$_deployment" "$_cluster"
  _env_file="$DEPLOY_ENVS_DIR/$_app.env"
  echo "$_env_file"
}

apps_jupyter_diff_env_save() {
  _app="jupyter-diff"
  _deployment="$1"
  _cluster="$2"
  apps_export_variables "$_deployment" "$_cluster"
  _env_file="$DEPLOY_ENVS_DIR/$_app.env"
  apps_jupyter_diff_check_directories
  apps_jupyter_diff_print_variables "$_deployment" "$_cluster" |
    stdout_to_file "$_env_file"
}

apps_jupyter_diff_env_update() {
  _app="jupyter-diff"
  _deployment="$1"
  _cluster="$2"
  apps_export_variables "$_deployment" "$_cluster"
  _env_file="$DEPLOY_ENVS_DIR/$_app.env"
  header "$_app configuration variables"
  apps_jupyter_diff_print_variables "$_deployment" "$_cluster" |
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
    apps_jupyter_diff_read_variables
    if [ -f "$_env_file" ]; then
      footer
      read_bool "Save updated $_app env vars?" "Yes"
    else
      READ_VALUE="Yes"
    fi
    if is_selected "${READ_VALUE}"; then
      apps_jupyter_diff_env_save "$_deployment" "$_cluster"
      footer
      echo "$_app configuration saved to '$_env_file'"
      footer
    fi
  fi
}

apps_jupyter_diff_command() {
  _command="$1"
  _deployment="$2"
  _cluster="$3"
  case "$_command" in
  env-edit | env_edit)
    apps_jupyter_diff_env_edit "$_deployment" "$_cluster"
    ;;
  env-path | env_path)
    apps_jupyter_diff_env_path "$_deployment" "$_cluster"
    ;;
  env-show | env_show)
    apps_jupyter_diff_print_variables "$_deployment" "$_cluster" | grep -v '^#'
    ;;
  env-update | env_update)
    apps_jupyter_diff_env_update "$_deployment" "$_cluster"
    ;;
  helm-history) apps_jupyter_diff_helm_history "$_deployment" "$_cluster" ;;
  helm-rollback) apps_jupyter_diff_helm_rollback "$_deployment" "$_cluster" ;;
  install) apps_jupyter_diff_install "$_deployment" "$_cluster" ;;
  logs) apps_jupyter_diff_logs "$_deployment" "$_cluster" ;;
  reinstall) apps_jupyter_diff_reinstall "$_deployment" "$_cluster" ;;
  remove) apps_jupyter_diff_remove "$_deployment" "$_cluster" ;;
  restart) apps_jupyter_diff_restart "$_deployment" "$_cluster" ;;
  sh) apps_jupyter_diff_sh "$_deployment" "$_cluster" ;;
  status) apps_jupyter_diff_status "$_deployment" "$_cluster" ;;
  summary) apps_jupyter_diff_summary "$_deployment" "$_cluster" ;;
  uris) apps_jupyter_diff_uris "$_deployment" "$_cluster" ;;
  *)
    echo "Unknown jupyter-diff subcommand '$1'"
    exit 1
    ;;
  esac
}

apps_jupyter_diff_command_list() {
  _cmnds="env-edit env-path env-show env-update helm-history helm-rollback"
  _cmnds="$_cmnds install logs reinstall remove restart sh status summary uris"
  echo "$_cmnds"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
