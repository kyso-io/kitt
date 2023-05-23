#!/bin/sh
# ----
# File:        apps/imagebox.sh
# Description: Functions to manage imagebox deployments for kyso on k8s
#              clusters
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022-2023 Kyso Inc.
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_APPS_IMAGEBOX_SH="1"

# ---------
# Variables
# ---------

# CMND_DSC="imagebox: manage imagebox deployment for kyso"

# Defaults
_image="registry.kyso.io/docker/imagebox:latest"
export DEPLOYMENT_DEFAULT_IMAGEBOX_IMAGE="$_image"

# Fixed values
export IMAGEBOX_SERVER_PORT="8080"

# --------
# Includes
# --------

if [ -d "$INCL_DIR" ]; then
  # shellcheck source=../common.sh
  [ "$INCL_COMMON_SH" = "1" ] || . "$INCL_DIR/common.sh"
  # shellcheck source=./common.sh
  [ "$INCL_APPS_COMMON_SH" = "1" ] || . "$INCL_DIR/apps/common.sh"
  # shellcheck source=./kyso-scs.sh
  [ "$INCL_APPS_KYSO_SCS_SH" = "1" ] || . "$INCL_DIR/apps/kyso-scs.sh"
fi

# ---------
# Functions
# ---------

apps_imagebox_export_variables() {
  [ -z "$__apps_imagebox_export_variables" ] || return 0
  _deployment="$1"
  _cluster="$2"
  apps_common_export_variables "$_deployment" "$_cluster"
  apps_kyso_scs_export_variables "$_deployment" "$_cluster"
  # Values
  export IMAGEBOX_NAMESPACE="imagebox-$DEPLOYMENT_NAME"
  # Directories
  export IMAGEBOX_CHART_DIR="$CHARTS_DIR/imagebox"
  export IMAGEBOX_TMPL_DIR="$TMPL_DIR/apps/imagebox"
  export IMAGEBOX_HELM_DIR="$DEPLOY_HELM_DIR/imagebox"
  export IMAGEBOX_KUBECTL_DIR="$DEPLOY_KUBECTL_DIR/imagebox"
  # Templates
  export IMAGEBOX_HELM_VALUES_TMPL="$IMAGEBOX_TMPL_DIR/values.yaml"
  export IMAGEBOX_SVC_MAP_TMPL="$IMAGEBOX_TMPL_DIR/svc_map.yaml"
  # Files
  export IMAGEBOX_HELM_VALUES_YAML="$IMAGEBOX_HELM_DIR/values.yaml"
  export IMAGEBOX_SVC_MAP_YAML="$IMAGEBOX_KUBECTL_DIR/svc_map.yaml"
  # Use defaults for variables missing from config files
  if [ "$DEPLOYMENT_IMAGEBOX_IMAGE" ]; then
    IMAGEBOX_IMAGE="$DEPLOYMENT_IMAGEBOX_IMAGE"
  else
    IMAGEBOX_IMAGE="$DEPLOYMENT_DEFAULT_IMAGEBOX_IMAGE"
  fi
  export IMAGEBOX_IMAGE
  __apps_imagebox_export_variables="1"
}

apps_imagebox_check_directories() {
  apps_common_check_directories
  for _d in "$IMAGEBOX_HELM_DIR" "$IMAGEBOX_KUBECTL_DIR"; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

apps_imagebox_clean_directories() {
  # Try to remove empty dirs, except if they contain secrets
  for _d in "$IMAGEBOX_HELM_DIR" "$IMAGEBOX_KUBECTL_DIR"; do
    if [ -d "$_d" ]; then
      rmdir "$_d" 2>/dev/null || true
    fi
  done
}

apps_imagebox_read_variables() {
  _app="imagebox"
  header "Reading $_app settings"
  read_value "Imagebox container image" "${IMAGEBOX_IMAGE}"
  IMAGEBOX_IMAGE=${READ_VALUE}
}

apps_imagebox_print_variables() {
  _app="imagebox"
  cat <<EOF
# Deployment $_app settings
# ---
IMAGEBOX_IMAGE=$IMAGEBOX_IMAGE
# ---
EOF
}

apps_imagebox_logs() {
  _deployment="$1"
  _cluster="$2"
  apps_imagebox_export_variables "$_deployment" "$_cluster"
  _app="imagebox"
  _ns="$IMAGEBOX_NAMESPACE"
  if kubectl get -n "$_ns" "deployments/$_app" >/dev/null 2>&1; then
    kubectl -n "$_ns" logs "deployments/$_app" -f
  else
    echo "Deployment '$_app' not found on namespace '$_ns'"
  fi
}

apps_imagebox_sh() {
  _deployment="$1"
  _cluster="$2"
  apps_imagebox_export_variables "$_deployment" "$_cluster"
  _app="imagebox"
  _ns="$IMAGEBOX_NAMESPACE"
  if kubectl get -n "$_ns" "deployments/$_app" >/dev/null 2>&1; then
    kubectl -n "$_ns" exec -ti "deployments/$_app" -- /bin/sh
  else
    echo "Deployment '$_app' not found on namespace '$_ns'"
  fi
}

apps_imagebox_install() {
  _deployment="$1"
  _cluster="$2"
  apps_imagebox_export_variables "$_deployment" "$_cluster"
  # Load additional variables & check directories
  apps_common_export_service_hostnames "$_deployment" "$_cluster"
  apps_imagebox_check_directories
  # Adjust variables
  _app="imagebox"
  _ns="$IMAGEBOX_NAMESPACE"
  # directories
  _chart="$IMAGEBOX_CHART_DIR"
  # files
  _helm_values_tmpl="$IMAGEBOX_HELM_VALUES_TMPL"
  _helm_values_yaml="$IMAGEBOX_HELM_VALUES_YAML"
  _svc_map_tmpl="$IMAGEBOX_SVC_MAP_TMPL"
  _svc_map_yaml="$IMAGEBOX_SVC_MAP_YAML"
  _cert_yamls=""
  for _hostname in $DEPLOYMENT_HOSTNAMES; do
    _cert_yaml="$IMAGEBOX_KUBECTL_DIR/tls-$_hostname${SOPS_EXT}.yaml"
    _cert_yamls="$_cert_yamls $_cert_yaml"
  done
  if ! find_namespace "$_ns"; then
    # Remove old files, just in case ...
    # shellcheck disable=SC2086
    rm -f "$_helm_values_yaml" "$_svc_map_yaml" $_cert_yamls
    # Create namespace
    create_namespace "$_ns"
  fi
  # Image settings
  _image_repo="${IMAGEBOX_IMAGE%:*}"
  _image_tag="${IMAGEBOX_IMAGE#*:}"
  if [ "$_image_repo" = "$_image_tag" ]; then
    _image_tag="latest"
  fi
  # Service settings
  _server_port="$IMAGEBOX_SERVER_PORT"
  # Prepare values.yaml file
  sed \
    -e "s%__IMAGEBOX_REPLICAS__%$IMAGEBOX_REPLICAS%" \
    -e "s%__IMAGEBOX_IMAGE_REPO__%$_image_repo%" \
    -e "s%__IMAGEBOX_IMAGE_TAG__%$_image_tag%" \
    -e "s%__IMAGE_PULL_POLICY__%$DEPLOYMENT_IMAGE_PULL_POLICY%" \
    -e "s%__PULL_SECRETS_NAME__%$CLUSTER_PULL_SECRETS_NAME%" \
    -e "s%__IMAGEBOX_SERVER_PORT__%$_server_port%" \
    "$_helm_values_tmpl" | stdout_to_file "$_helm_values_yaml"
  # Apply ingress values
  replace_app_ingress_values "$_app" "$_helm_values_yaml"
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
    create_app_cert_yamls "$_ns" "$IMAGEBOX_KUBECTL_DIR"
  else
    for _cert_yaml in $_cert_yamls; do
      kubectl_delete "$_cert_yaml" || true
    done
  fi
  # Install map and certs
  for _yaml in "$_svc_map_yaml" $_cert_yamls; do
    kubectl_apply "$_yaml"
  done
  # Install helm chart
  helm_upgrade "$_ns" "$_helm_values_yaml" "$_app" "$_chart"
  # Wait until deployment succeds or fails
  kubectl rollout status deployment --timeout="$ROLLOUT_STATUS_TIMEOUT" \
    -n "$_ns" "$_app"
}

apps_imagebox_helm_history() {
  _deployment="$1"
  _cluster="$2"
  apps_imagebox_export_variables "$_deployment" "$_cluster"
  _app="imagebox"
  _ns="$IMAGEBOX_NAMESPACE"
  if find_namespace "$_ns"; then
    helm_history "$_ns" "$_app"
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

apps_imagebox_helm_rollback() {
  _deployment="$1"
  _cluster="$2"
  apps_imagebox_export_variables "$_deployment" "$_cluster"
  _app="imagebox"
  _ns="$IMAGEBOX_NAMESPACE"
  _release="$ROLLBACK_RELEASE"
  if find_namespace "$_ns"; then
    # Execute the rollback
    helm_rollback "$_ns" "$_app" "$_release"
    # If we succeed update the api settings
    apps_kyso_update_api_settings "$_deployment" "$_cluster"
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

apps_imagebox_reinstall() {
  _deployment="$1"
  _cluster="$2"
  apps_imagebox_export_variables "$_deployment" "$_cluster"
  _app="imagebox"
  _ns="$IMAGEBOX_NAMESPACE"
  if find_namespace "$_ns"; then
    _cimages="$(deployment_container_images "$_ns" "$_app")"
    _cname="imagebox"
    IMAGEBOX_IMAGE="$(echo "$_cimages" | sed -ne "s/^$_cname //p")"
    if [ "$IMAGEBOX_IMAGE" ]; then
      export IMAGEBOX_IMAGE
      apps_imagebox_install "$_deployment" "$_cluster"
    else
      echo "Image for '$_app' on '$_ns' not found!"
    fi
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

apps_imagebox_remove() {
  _deployment="$1"
  _cluster="$2"
  apps_imagebox_export_variables "$_deployment" "$_cluster"
  _app="imagebox"
  _ns="$IMAGEBOX_NAMESPACE"
  # yaml files
  _helm_values_yaml="$IMAGEBOX_HELM_VALUES_YAML"
  _svc_map_yaml="$ONLYOFFICE_DS_SVC_MAP_YAML"
  _cert_yamls=""
  for _hostname in $DEPLOYMENT_HOSTNAMES; do
    _cert_yaml="$IMAGEBOX_KUBECTL_DIR/tls-$_hostname${SOPS_EXT}.yaml"
    _cert_yamls="$_cert_yamls $_cert_yaml"
  done
  apps_imagebox_export_variables
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
    delete_namespace "$_ns"
    footer
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
  apps_imagebox_clean_directories
}

apps_imagebox_restart() {
  _deployment="$1"
  _cluster="$2"
  apps_imagebox_export_variables "$_deployment" "$_cluster"
  _app="imagebox"
  _ns="$IMAGEBOX_NAMESPACE"
  if find_namespace "$_ns"; then
    deployment_restart "$_ns" "$_app"
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

apps_imagebox_status() {
  _deployment="$1"
  _cluster="$2"
  apps_imagebox_export_variables "$_deployment" "$_cluster"
  _app="imagebox"
  _ns="$IMAGEBOX_NAMESPACE"
  if find_namespace "$_ns"; then
    kubectl get all,endpoints,ingress,secrets -n "$_ns"
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

apps_imagebox_summary() {
  _deployment="$1"
  _cluster="$2"
  apps_imagebox_export_variables "$_deployment" "$_cluster"
  _ns="$IMAGEBOX_NAMESPACE"
  _app="imagebox"
  deployment_summary "$_ns" "$_app"
}

apps_imagebox_uris() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_api_export_variables "$_deployment" "$_cluster"
  _hostname="${DEPLOYMENT_HOSTNAMES%% *}"
  echo "https://$_hostname/iiif"
}

apps_imagebox_env_edit() {
  if [ "$EDITOR" ]; then
    _app="imagebox"
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

apps_imagebox_env_path() {
  _app="imagebox"
  _deployment="$1"
  _cluster="$2"
  apps_export_variables "$_deployment" "$_cluster"
  _env_file="$DEPLOY_ENVS_DIR/$_app.env"
  echo "$_env_file"
}

apps_imagebox_env_save() {
  _app="imagebox"
  _deployment="$1"
  _cluster="$2"
  _env_file="$3"
  apps_imagebox_check_directories
  apps_imagebox_print_variables "$_deployment" "$_cluster" |
    stdout_to_file "$_env_file"
}

apps_imagebox_env_update() {
  _app="imagebox"
  _deployment="$1"
  _cluster="$2"
  apps_export_variables "$_deployment" "$_cluster"
  _env_file="$DEPLOY_ENVS_DIR/$_app.env"
  header "$_app configuration variables"
  apps_imagebox_print_variables "$_deployment" "$_cluster" |
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
    apps_imagebox_read_variables
    if [ -f "$_env_file" ]; then
      footer
      read_bool "Save updated $_app env vars?" "Yes"
    else
      READ_VALUE="Yes"
    fi
    if is_selected "${READ_VALUE}"; then
      apps_imagebox_env_save "$_deployment" "$_cluster" "$_env_file"
      footer
      echo "$_app configuration saved to '$_env_file'"
      footer
    fi
  fi
}

apps_imagebox_command() {
  _command="$1"
  _deployment="$2"
  _cluster="$3"
  case "$_command" in
  env-edit | env_edit)
    apps_imagebox_env_edit "$_deployment" "$_cluster"
    ;;
  env-path | env_path)
    apps_imagebox_env_path "$_deployment" "$_cluster"
    ;;
  env-show | env_show)
    apps_imagebox_print_variables "$_deployment" "$_cluster" | grep -v '^#'
    ;;
  env-update | env_update)
    apps_imagebox_env_update "$_deployment" "$_cluster"
    ;;
  helm-history) apps_imagebox_helm_history "$_deployment" "$_cluster" ;;
  helm-rollback) apps_imagebox_helm_rollback "$_deployment" "$_cluster" ;;
  install) apps_imagebox_install "$_deployment" "$_cluster" ;;
  logs) apps_imagebox_logs "$_deployment" "$_cluster" ;;
  reinstall) apps_imagebox_reinstall "$_deployment" "$_cluster" ;;
  remove) apps_imagebox_remove "$_deployment" "$_cluster" ;;
  restart) apps_imagebox_restart "$_deployment" "$_cluster" ;;
  sh) apps_imagebox_sh "$_deployment" "$_cluster" ;;
  status) apps_imagebox_status "$_deployment" "$_cluster" ;;
  summary) apps_imagebox_summary "$_deployment" "$_cluster" ;;
  uris) apps_imagebox_uris "$_deployment" "$_cluster" ;;
  *)
    echo "Unknown imagebox subcommand '$1'"
    exit 1
    ;;
  esac
}

apps_imagebox_command_list() {
  _cmnds="env-edit env-path env-show env-update helm-history helm-rollback"
  _cmnds="$_cmnds install logs reinstall remove restart sh status summary uris"
  echo "$_cmnds"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
