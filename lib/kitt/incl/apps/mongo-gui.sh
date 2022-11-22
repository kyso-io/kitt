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
_image="registry.kyso.io/docker/mongo-gui:1.0.0"
export DEPLOYMENT_DEFAULT_MONGO_GUI_IMAGE="$_image"

# Fixed values
export MONGO_GUI_SERVER_PORT="4321"
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
  export MONGO_GUI_CHART_DIR="$CHARTS_DIR/mongo-gui"
  export MONGO_GUI_TMPL_DIR="$TMPL_DIR/apps/mongo-gui"
  export MONGO_GUI_HELM_DIR="$DEPLOY_HELM_DIR/mongo-gui"
  export MONGO_GUI_KUBECTL_DIR="$DEPLOY_KUBECTL_DIR/mongo-gui"
  export MONGO_GUI_SECRETS_DIR="$DEPLOY_SECRETS_DIR/mongo-gui"
  # Templates
  export MONGO_GUI_HELM_VALUES_TMPL="$MONGO_GUI_TMPL_DIR/values.yaml"
  # BEG: deprecated files
  export MONGO_GUI_DEPLOY_YAML="$MONGO_GUI_KUBECTL_DIR/deploy.yaml"
  export MONGO_GUI_SECRET_YAML="$MONGO_GUI_SECRETS_DIR/secrets.yaml"
  export MONGO_GUI_SERVICE_YAML="$MONGO_GUI_KUBECTL_DIR/service.yaml"
  export MONGO_GUI_INGRESS_YAML="$MONGO_GUI_KUBECTL_DIR/ingress.yaml"
  _auth_yaml="$MONGO_GUI_KUBECTL_DIR/basic-auth${SOPS_EXT}.yaml"
  export MONGO_GUI_AUTH_YAML="$_auth_yaml"
  # END: deprecated files
  # Files
  _auth_file="$MONGO_GUI_SECRETS_DIR/basic_auth${SOPS_EXT}.txt"
  export MONGO_GUI_AUTH_FILE="$_auth_file"
  _helm_values_yaml="$MONGO_GUI_HELM_DIR/values${SOPS_EXT}.yaml"
  export MONGO_GUI_HELM_VALUES_YAML="$_helm_values_yaml"
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
  for _d in "$MONGO_GUI_HELM_DIR" "$MONGO_GUI_KUBECTL_DIR" \
    "$MONGO_GUI_SECRETS_DIR"; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

apps_mongo_gui_clean_directories() {
  # Try to remove empty dirs, except if they contain secrets
  for _d in "$MONGO_GUI_HELM_DIR" "$MONGO_GUI_KUBECTL_DIR" \
    "$MONGO_GUI_SECRETS_DIR"; do
    if [ -d "$_d" ]; then
      rmdir "$_d" 2>/dev/null || true
    fi
  done
}

apps_mongo_gui_read_variables() {
  _app="mongo-gui"
  header "Reading $_app settings"
  read_value "Mongo-gui image" "${MONGO_GUI_IMAGE}"
  MONGO_GUI_IMAGE=${READ_VALUE}
}

apps_mongo_gui_print_variables() {
  _app="mongo-gui"
  cat <<EOF
# Deployment $_app settings
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
  _app="mongo-gui"
  if kubectl get -n "$_ns" "deployments/$_app" >/dev/null 2>&1; then
    kubectl -n "$_ns" logs "deployments/$_app" -f
  else
    echo "Deployment '$_app' not found on namespace '$_ns'"
  fi
}

apps_mongo_gui_sh() {
  _deployment="$1"
  _cluster="$2"
  apps_mongo_gui_export_variables "$_deployment" "$_cluster"
  _ns="$MONGO_GUI_NAMESPACE"
  _app="mongo-gui"
  if kubectl get -n "$_ns" "deployments/$_app" >/dev/null 2>&1; then
    kubectl -n "$_ns" exec -ti "deployments/$_app" -- /bin/sh
  else
    echo "Deployment '$_app' not found on namespace '$_ns'"
  fi
}

apps_mongo_gui_install() {
  _deployment="$1"
  _cluster="$2"
  apps_mongo_gui_export_variables "$_deployment" "$_cluster"
  # Initial test
  if ! find_namespace "$MONGODB_NAMESPACE"; then
    read_bool "mongodb namespace not found, abort install?" "Yes"
    if is_selected "${READ_VALUE}"; then
      return 1
    fi
  fi
  # check directories
  apps_mongo_gui_check_directories
  _app="mongo-gui"
  _ns="$MONGO_GUI_NAMESPACE"
  # directories
  _chart="$MONGO_GUI_CHART_DIR"
  # deprecated yaml files
  _auth_yaml="$MONGO_GUI_AUTH_YAML"
  _secret_yaml="$MONGO_GUI_SECRET_YAML"
  _deploy_yaml="$MONGO_GUI_DEPLOY_YAML"
  _ingress_yaml="$MONGO_GUI_INGRESS_YAML"
  _service_yaml="$MONGO_GUI_SERVICE_YAML"
  # files
  _helm_values_tmpl="$MONGO_GUI_HELM_VALUES_TMPL"
  _helm_values_yaml="$MONGO_GUI_HELM_VALUES_YAML"
  # auth data
  _auth_user="$MONGO_GUI_BASIC_AUTH_USER"
  if is_selected "$CLUSTER_USE_BASIC_AUTH"; then
    auth_file_update "$MONGO_GUI_BASIC_AUTH_USER" "$MONGO_GUI_AUTH_FILE"
    _auth_pass="$(
      file_to_stdout "$MONGO_GUI_AUTH_FILE" | sed -ne "s/^${_auth_user}://p"
    )"
  else
    _auth_pass=""
  fi
  _cert_yamls=""
  for _hostname in $DEPLOYMENT_HOSTNAMES; do
    _cert_yaml="$MONGO_GUI_KUBECTL_DIR/tls-$_hostname${SOPS_EXT}.yaml"
    _cert_yamls="$_cert_yamls $_cert_yaml"
  done
  if ! find_namespace "$_ns"; then
    # Remove old files, just in case ...
    # shellcheck disable=SC2086
    rm -f "$_helm_values_yaml" \
      "$_secret_yaml" "$_auth_yaml" "$_service_yaml" "$_deploy_yaml" \
      "$_ingress_yaml" $_cert_yamls
    # Create namespace
    create_namespace "$_ns"
  fi
  # If we have a legacy deployment, remove the old objects
  for _yaml in "$_secret_yaml" "$_auth_yaml" "$_service_yaml" \
    "$_deploy_yaml" "$_ingress_yaml"; do
    kubectl_delete "$_yaml" || true
  done
  # Image settings
  _image_repo="${MONGO_GUI_IMAGE%:*}"
  _image_tag="${MONGO_GUI_IMAGE#*:}"
  if [ "$_image_repo" = "$_image_tag" ]; then
    _image_tag="latest"
  fi
  # Service settings
  _server_port="$MONGO_GUI_SERVER_PORT"
  # Get the database uri
  _mongodb_root_database_uri="$(
    apps_mongodb_print_root_database_uri "$_deployment" "$_cluster"
  )"
  # Prepare values.yaml file
  sed \
    -e "s%__MONGO_GUI_REPLICAS__%$MONGO_GUI_REPLICAS%" \
    -e "s%__MONGO_GUI_IMAGE_REPO__%$_image_repo%" \
    -e "s%__MONGO_GUI_IMAGE_TAG__%$_image_tag%" \
    -e "s%__IMAGE_PULL_POLICY__%$DEPLOYMENT_IMAGE_PULL_POLICY%" \
    -e "s%__PULL_SECRETS_NAME__%$CLUSTER_PULL_SECRETS_NAME%" \
    -e "s%__MONGO_GUI_SERVER_PORT__%$_server_port%" \
    -e "s%__BASIC_AUTH_USER__%$_auth_user%" \
    -e "s%__BASIC_AUTH_PASS__%$_auth_pass%" \
    -e "s%__MONGODB_DATABASE_URI__%$_mongodb_root_database_uri%" \
    "$_helm_values_tmpl" | stdout_to_file "$_helm_values_yaml"
  # Apply ingress values
  replace_app_ingress_values "$_app" "$_helm_values_yaml"
  # Create certificate secrets if needed or remove them if not
  if is_selected "$DEPLOYMENT_INGRESS_TLS_CERTS"; then
    create_app_cert_yamls "$_ns" "$MONGO_GUI_KUBECTL_DIR"
  else
    for _cert_yaml in $_cert_yamls; do
      kubectl_delete "$_cert_yaml" || true
    done
  fi
  # Install certs
  for _yaml in $_cert_yamls; do
    kubectl_apply "$_yaml"
  done
  # Install helm chart
  helm_upgrade "$_ns" "$_helm_values_yaml" "$_app" "$_chart"
  # Wait until deployment succeds of fails
  kubectl rollout status deployment --timeout="$ROLLOUT_STATUS_TIMEOUT" \
    -n "$_ns" "$_app"
}

apps_mongo_gui_helm_history() {
  _deployment="$1"
  _cluster="$2"
  apps_mongo_gui_export_variables "$_deployment" "$_cluster"
  _app="mongo-gui"
  _ns="$MONGO_GUI_NAMESPACE"
  if find_namespace "$_ns"; then
    helm_history "$_ns" "$_app"
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

apps_mongo_gui_helm_rollback() {
  _deployment="$1"
  _cluster="$2"
  apps_mongo_gui_export_variables "$_deployment" "$_cluster"
  _app="mongo-gui"
  _ns="$MONGO_GUI_NAMESPACE"
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

apps_mongo_gui_reinstall() {
  _deployment="$1"
  _cluster="$2"
  apps_mongo_gui_export_variables "$_deployment" "$_cluster"
  _app="mongo-gui"
  _ns="$MONGO_GUI_NAMESPACE"
  if find_namespace "$_ns"; then
    _cimages="$(deployment_container_images "$_ns" "$_app")"
    _cname="mongo-gui"
    MONGO_GUI_IMAGE="$(echo "$_cimages" | sed -ne "s/^$_cname //p")"
    if [ "$MONGO_GUI_IMAGE" ]; then
      export MONGO_GUI_IMAGE
      apps_mongo_gui_install "$_deployment" "$_cluster"
    else
      echo "Image for '$_app' on '$_ns' not found!"
    fi
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

apps_mongo_gui_remove() {
  _deployment="$1"
  _cluster="$2"
  apps_mongo_gui_export_variables "$_deployment" "$_cluster"
  _app="mongo-gui"
  _ns="$MONGO_GUI_NAMESPACE"
  # deprecated yaml files
  _auth_yaml="$MONGO_GUI_AUTH_YAML"
  _secret_yaml="$MONGO_GUI_SECRET_YAML"
  _deploy_yaml="$MONGO_GUI_DEPLOY_YAML"
  _ingress_yaml="$MONGO_GUI_INGRESS_YAML"
  _service_yaml="$MONGO_GUI_SERVICE_YAML"
  # files
  _helm_values_yaml="$MONGO_GUI_HELM_VALUES_YAML"
  _cert_yamls=""
  for _hostname in $DEPLOYMENT_HOSTNAMES; do
    _cert_yaml="$MONGO_GUI_KUBECTL_DIR/tls-$_hostname${SOPS_EXT}.yaml"
    _cert_yamls="$_cert_yamls $_cert_yaml"
  done
  apps_mongo_gui_export_variables
  if find_namespace "$_ns"; then
    header "Removing '$_app' objects"
    # Uninstall chart
    if [ -f "$_helm_values_yaml" ]; then
      helm uninstall -n "$_ns" "$_app" || true
      rm -f "$_helm_values_yaml"
    fi
    # Remove objects
    for _yaml in $_cert_yamls; do
      kubectl_delete "$_yaml" || true
    done
    # Remove legacy objects
    for _yaml in "$_secret_yaml" "$_auth_yaml" "$_service_yaml" \
      "$_deploy_yaml" "$_ingress_yaml"; do
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
  apps_mongo_gui_export_variables "$_deployment" "$_cluster"
  _hostname="${DEPLOYMENT_HOSTNAMES%% *}"
  if is_selected "$CLUSTER_USE_BASIC_AUTH" &&
    [ -f "$MONGO_GUI_AUTH_FILE" ]; then
    _uap="$(file_to_stdout "$MONGO_GUI_AUTH_FILE")"
    echo "https://$_uap@$_hostname/mongo-gui/"
  else
    echo "https://$_hostname/mongo-gui/"
  fi
}

apps_mongo_gui_env_edit() {
  if [ "$EDITOR" ]; then
    _app="mongo-gui"
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

apps_mongo_gui_env_path() {
  _app="mongo-gui"
  _deployment="$1"
  _cluster="$2"
  apps_export_variables "$_deployment" "$_cluster"
  _env_file="$DEPLOY_ENVS_DIR/$_app.env"
  echo "$_env_file"
}

apps_mongo_gui_env_save() {
  _app="mongo-gui"
  _deployment="$1"
  _cluster="$2"
  _env_file="$3"
  apps_mongo_gui_check_directories
  apps_mongo_gui_print_variables "$_deployment" "$_cluster" |
    stdout_to_file "$_env_file"
}

apps_mongo_gui_env_update() {
  _app="mongo-gui"
  _deployment="$1"
  _cluster="$2"
  apps_export_variables "$_deployment" "$_cluster"
  _env_file="$DEPLOY_ENVS_DIR/$_app.env"
  header "$_app configuration variables"
  apps_mongo_gui_print_variables "$_deployment" "$_cluster" |
    grep -v "^#"
  if [ -f "$_env_file" ]; then
    footer
    read_bool "Update $_app env vars?" "No"
  else
    READ_VALUE="Yes"
  fi
  if is_selected "${READ_VALUE}"; then
    footer
    apps_mongo_gui_read_variables
    if [ -f "$_env_file" ]; then
      footer
      read_bool "Save updated $_app env vars?" "Yes"
    else
      READ_VALUE="Yes"
    fi
    if is_selected "${READ_VALUE}"; then
      apps_mongo_gui_env_save "$_deployment" "$_cluster" "$_env_file"
      footer
      echo "$_app configuration saved to '$_env_file'"
      footer
    fi
  fi
}

apps_mongo_gui_command() {
  _command="$1"
  _deployment="$2"
  _cluster="$3"
  case "$_command" in
  env-edit | env_edit)
    apps_mongo_gui_env_edit "$_deployment" "$_cluster"
    ;;
  env-path | env_path)
    apps_mongo_gui_env_path "$_deployment" "$_cluster"
    ;;
  env-show | env_show)
    apps_mongo_gui_print_variables "$_deployment" "$_cluster" | grep -v '^#'
    ;;
  env-update | env_update)
    apps_mongo_gui_env_update "$_deployment" "$_cluster"
    ;;
  helm-history) apps_mongo_gui_helm_history "$_deployment" "$_cluster" ;;
  helm-rollback) apps_mongo_gui_helm_rollback "$_deployment" "$_cluster" ;;
  install) apps_mongo_gui_install "$_deployment" "$_cluster" ;;
  logs) apps_mongo_gui_logs "$_deployment" "$_cluster" ;;
  reinstall) apps_mongo_gui_reinstall "$_deployment" "$_cluster" ;;
  remove) apps_mongo_gui_remove "$_deployment" "$_cluster" ;;
  restart) apps_mongo_gui_restart "$_deployment" "$_cluster" ;;
  sh) apps_mongo_gui_sh "$_deployment" "$_cluster" ;;
  status) apps_mongo_gui_status "$_deployment" "$_cluster" ;;
  summary) apps_mongo_gui_summary "$_deployment" "$_cluster" ;;
  uris) apps_mongo_gui_uris "$_deployment" "$_cluster" ;;
  *)
    echo "Unknown mongo-gui subcommand '$1'"
    exit 1
    ;;
  esac
}

apps_mongo_gui_command_list() {
  _cmnds="env-edit env-path env-show env-update helm-history helm-rollback"
  _cmnds="$_cmnds install logs reinstall remove restart sh status summary uris"
  echo "$_cmnds"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
