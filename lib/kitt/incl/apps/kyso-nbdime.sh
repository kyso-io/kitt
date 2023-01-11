#!/bin/sh
# ----
# File:        apps/kyso-nbdime.sh
# Description: Functions to manage kyso-nbdime deployments
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2023 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_APPS_KYSO_NBDIME_SH="1"

# Fixed values
KYSO_NBDIME_PORT="3005"

# ---------
# Variables
# ---------

# CMND_DSC="kyso-nbdime: manage nbdime deployment for kyso"

# Defaults
export DEPLOYMENT_DEFAULT_KYSO_NBDIME_IMAGE=""
export DEPLOYMENT_DEFAULT_KYSO_NBDIME_REPLICAS="1"

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

apps_kyso_nbdime_export_variables() {
  [ -z "$__apps_kyso_nbdime_export_variables" ] || return 0
  _deployment="$1"
  _cluster="$2"
  apps_common_export_variables "$_deployment" "$_cluster"
  # Values
  _ns="kyso-nbdime-$DEPLOYMENT_NAME"
  export KYSO_NBDIME_NAMESPACE="$_ns"
  # Directories
  export KYSO_NBDIME_CHART_DIR="$CHARTS_DIR/kyso-nbdime"
  _tmpl_dir="$TMPL_DIR/apps/kyso-nbdime"
  export KYSO_NBDIME_TMPL_DIR="$_tmpl_dir"
  _helm_dir="$DEPLOY_HELM_DIR/kyso-nbdime"
  export KYSO_NBDIME_HELM_DIR="$_helm_dir"
  # Templates
  export KYSO_NBDIME_HELM_VALUES_TMPL="$_tmpl_dir/values.yaml"
  # Files
  _helm_values_yaml="$_helm_dir/values${SOPS_EXT}.yaml"
  export KYSO_NBDIME_HELM_VALUES_YAML="$_helm_values_yaml"
  # By default don't auto save the environment
  KYSO_NBDIME_AUTO_SAVE_ENV="false"
  # Use defaults for variables missing from config files / enviroment
  _image="$KYSO_NBDIME_IMAGE"
  if [ -z "$_image" ]; then
    if [ "$DEPLOYMENT_KYSO_NBDIME_IMAGE" ]; then
      _image="$DEPLOYMENT_KYSO_NBDIME_IMAGE"
    else
      _image="$DEPLOYMENT_DEFAULT_KYSO_NBDIME_IMAGE"
    fi
  else
    KYSO_NBDIME_AUTO_SAVE_ENV="true"
  fi
  export KYSO_NBDIME_IMAGE="$_image"
  if [ "$DEPLOYMENT_KYSO_NBDIME_REPLICAS" ]; then
    _replicas="$DEPLOYMENT_KYSO_NBDIME_REPLICAS"
  else
    _replicas="$DEPLOYMENT_DEFAULT_KYSO_NBDIME_REPLICAS"
  fi
  export KYSO_NBDIME_REPLICAS="$_replicas"
  # Export auto save environment flag
  export KYSO_NBDIME_AUTO_SAVE_ENV
  __apps_kyso_nbdime_export_variables="1"
}

apps_kyso_nbdime_check_directories() {
  apps_common_check_directories
  for _d in $KYSO_NBDIME_HELM_DIR; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

apps_kyso_nbdime_clean_directories() {
  # Try to remove empty dirs
  for _d in $KYSO_NBDIME_HELM_DIR; do
    if [ -d "$_d" ]; then
      rmdir "$_d" 2>/dev/null || true
    fi
  done
}

apps_kyso_nbdime_read_variables() {
  _app="kyso-nbdime"
  header "Reading $_app settings"
  _ex="registry.kyso.io/docker/kyso-nbdime:latest"
  _var="KYSO_NBDIME_IMAGE"
  read_value "kyso-nbdime Image URI (i.e. '$_ex' or export $_var env var)" \
    "${KYSO_NBDIME_IMAGE}"
  KYSO_NBDIME_IMAGE=${READ_VALUE}
  read_value "kyso-nbdime Replicas" "${KYSO_NBDIME_REPLICAS}"
  KYSO_NBDIME_REPLICAS=${READ_VALUE}
}

apps_kyso_nbdime_print_variables() {
  _app="kyso-nbdime"
  cat <<EOF
# Deployment $_app settings
# ---
# kyso-nbdime Image URI, examples for local testing:
# - 'registry.kyso.io/docker/kyso-nbdime:latest'
# - 'k3d-registry.lo.kyso.io:5000/kyso-nbdime:latest'
# If left empty the KYSO_NBDIME_IMAGE environment variable has to be
# set each time he kyso-nbdime service is installed
KYSO_NBDIME_IMAGE=$KYSO_NBDIME_IMAGE
# Number of pods to run in parallel
KYSO_NBDIME_REPLICAS=$KYSO_NBDIME_REPLICAS
# ---
EOF
}

apps_kyso_nbdime_logs() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_nbdime_export_variables "$_deployment" "$_cluster"
  _app="kyso-nbdime"
  _ns="$KYSO_NBDIME_NAMESPACE"
  if kubectl get -n "$_ns" "deployments/$_app" >/dev/null 2>&1; then
    kubectl -n "$_ns" logs "deployments/$_app" -f
  else
    echo "Deployment '$_app' not found on namespace '$_ns'"
  fi
}

apps_kyso_nbdime_sh() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_nbdime_export_variables "$_deployment" "$_cluster"
  _app="kyso-nbdime"
  _ns="$KYSO_NBDIME_NAMESPACE"
  if kubectl get -n "$_ns" "deployments/$_app" >/dev/null 2>&1; then
    kubectl -n "$_ns" exec -ti "deployments/$_app" -- /bin/sh
  else
    echo "Deployment '$_app' not found on namespace '$_ns'"
  fi
}

apps_kyso_nbdime_install() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_nbdime_export_variables "$_deployment" "$_cluster"
  if [ -z "$KYSO_NBDIME_IMAGE" ]; then
    echo "The KYSO_NBDIME_IMAGE variable is empty."
    echo "Export KYSO_NBDIME_IMAGE or reconfigure."
    exit 1
  fi
  # Initial test
  if ! find_namespace "$MONGODB_NAMESPACE"; then
    read_bool "mongodb namespace not found, abort install?" "Yes"
    if is_selected "${READ_VALUE}"; then
      return 1
    fi
  fi
  # Load additional variables & check directories
  apps_common_export_service_hostnames "$_deployment" "$_cluster"
  apps_kyso_nbdime_check_directories
  # Auto save the configuration if requested
  if is_selected "$KYSO_NBDIME_AUTO_SAVE_ENV"; then
    apps_kyso_nbdime_env_save "$_deployment" "$_cluster"
  fi
  # Adjust variables
  _app="kyso-nbdime"
  _ns="$KYSO_NBDIME_NAMESPACE"
  # directories
  _chart="$KYSO_NBDIME_CHART_DIR"
  # files
  _helm_values_tmpl="$KYSO_NBDIME_HELM_VALUES_TMPL"
  _helm_values_yaml="$KYSO_NBDIME_HELM_VALUES_YAML"
  if ! find_namespace "$_ns"; then
    # Remove old files, just in case ...
    # shellcheck disable=SC2086
    rm -f "$_helm_values_yaml"
    # Create namespace
    create_namespace "$_ns"
  fi
  # Image settings
  _image_repo="${KYSO_NBDIME_IMAGE%:*}"
  _image_tag="${KYSO_NBDIME_IMAGE#*:}"
  if [ "$_image_repo" = "$_image_tag" ]; then
    _image_tag="latest"
  fi
  # Prepare values.yaml file
  sed \
    -e "s%__KYSO_NBDIME_REPLICAS__%$KYSO_NBDIME_REPLICAS%" \
    -e "s%__KYSO_NBDIME_IMAGE_REPO__%$_image_repo%" \
    -e "s%__KYSO_NBDIME_IMAGE_TAG__%$_image_tag%" \
    -e "s%__IMAGE_PULL_POLICY__%$DEPLOYMENT_IMAGE_PULL_POLICY%" \
    -e "s%__PULL_SECRETS_NAME__%$CLUSTER_PULL_SECRETS_NAME%" \
    -e "s%__KYSO_NBDIME_PORT__%$KYSO_NBDIME_PORT%" \
    "$_helm_values_tmpl" | stdout_to_file "$_helm_values_yaml"
  # Install helm chart
  helm_upgrade "$_ns" "$_helm_values_yaml" "$_app" "$_chart"
  # Wait until deployment succeds or fails
  kubectl rollout status deployment --timeout="$ROLLOUT_STATUS_TIMEOUT" \
    -n "$_ns" "$_app"
}

apps_kyso_nbdime_helm_history() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_nbdime_export_variables "$_deployment" "$_cluster"
  _app="kyso-nbdime"
  _ns="$KYSO_NBDIME_NAMESPACE"
  if find_namespace "$_ns"; then
    helm_history "$_ns" "$_app"
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

apps_kyso_nbdime_helm_rollback() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_nbdime_export_variables "$_deployment" "$_cluster"
  _app="kyso-nbdime"
  _ns="$KYSO_NBDIME_NAMESPACE"
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

apps_kyso_nbdime_reinstall() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_nbdime_export_variables "$_deployment" "$_cluster"
  _app="kyso-nbdime"
  _ns="$KYSO_NBDIME_NAMESPACE"
  if find_namespace "$_ns"; then
    _cimages="$(deployment_container_images "$_ns" "$_app")"
    _cname="kyso-nbdime"
    KYSO_NBDIME_IMAGE="$(echo "$_cimages" | sed -ne "s/^$_cname //p")"
    if [ "$KYSO_NBDIME_IMAGE" ]; then
      export KYSO_NBDIME_IMAGE
      apps_kyso_nbdime_install "$_deployment" "$_cluster"
    else
      echo "Image for '$_app' on '$_ns' not found!"
    fi
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

apps_kyso_nbdime_remove() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_nbdime_export_variables "$_deployment" "$_cluster"
  _app="kyso-nbdime"
  _ns="$KYSO_NBDIME_NAMESPACE"
  # files
  _helm_values_yaml="$KYSO_NBDIME_HELM_VALUES_YAML"
  apps_kyso_nbdime_export_variables
  if find_namespace "$_ns"; then
    header "Removing '$_app' objects"
    # Uninstall chart
    if [ -f "$_helm_values_yaml" ]; then
      helm uninstall -n "$_ns" "$_app" || true
      rm -f "$_helm_values_yaml"
    fi
    delete_namespace "$_ns"
    footer
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
  apps_kyso_nbdime_clean_directories
}

apps_kyso_nbdime_restart() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_nbdime_export_variables "$_deployment" "$_cluster"
  _app="kyso-nbdime"
  _ns="$KYSO_NBDIME_NAMESPACE"
  if find_namespace "$_ns"; then
    deployment_restart "$_ns" "$_app"
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

apps_kyso_nbdime_status() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_nbdime_export_variables "$_deployment" "$_cluster"
  _app="kyso-nbdime"
  _ns="$KYSO_NBDIME_NAMESPACE"
  if find_namespace "$_ns"; then
    kubectl get all,endpoints,ingress,secrets -n "$_ns"
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

apps_kyso_nbdime_summary() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_nbdime_export_variables "$_deployment" "$_cluster"
  _ns="$KYSO_NBDIME_NAMESPACE"
  _app="kyso-nbdime"
  deployment_summary "$_ns" "$_app"
}

apps_kyso_nbdime_env_edit() {
  if [ "$EDITOR" ]; then
    _app="kyso-nbdime"
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

apps_kyso_nbdime_env_path() {
  _app="kyso-nbdime"
  _deployment="$1"
  _cluster="$2"
  apps_export_variables "$_deployment" "$_cluster"
  _env_file="$DEPLOY_ENVS_DIR/$_app.env"
  echo "$_env_file"
}

apps_kyso_nbdime_env_save() {
  _app="kyso-nbdime"
  _deployment="$1"
  _cluster="$2"
  apps_export_variables "$_deployment" "$_cluster"
  _env_file="$DEPLOY_ENVS_DIR/$_app.env"
  apps_kyso_nbdime_check_directories
  apps_kyso_nbdime_print_variables "$_deployment" "$_cluster" |
    stdout_to_file "$_env_file"
}

apps_kyso_nbdime_env_update() {
  _app="kyso-nbdime"
  _deployment="$1"
  _cluster="$2"
  apps_export_variables "$_deployment" "$_cluster"
  _env_file="$DEPLOY_ENVS_DIR/$_app.env"
  header "$_app configuration variables"
  apps_kyso_nbdime_print_variables "$_deployment" "$_cluster" |
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
    apps_kyso_nbdime_read_variables
    if [ -f "$_env_file" ]; then
      footer
      read_bool "Save updated $_app env vars?" "Yes"
    else
      READ_VALUE="Yes"
    fi
    if is_selected "${READ_VALUE}"; then
      apps_kyso_nbdime_env_save "$_deployment" "$_cluster"
      footer
      echo "$_app configuration saved to '$_env_file'"
      footer
    fi
  fi
}

apps_kyso_nbdime_command() {
  _command="$1"
  _deployment="$2"
  _cluster="$3"
  case "$_command" in
  env-edit | env_edit)
    apps_kyso_nbdime_env_edit "$_deployment" "$_cluster"
    ;;
  env-path | env_path)
    apps_kyso_nbdime_env_path "$_deployment" "$_cluster"
    ;;
  env-show | env_show)
    apps_kyso_nbdime_print_variables "$_deployment" "$_cluster" |
      grep -v '^#'
    ;;
  env-update | env_update)
    apps_kyso_nbdime_env_update "$_deployment" "$_cluster"
    ;;
  helm-history)
    apps_kyso_nbdime_helm_history "$_deployment" "$_cluster"
    ;;
  helm-rollback)
    apps_kyso_nbdime_helm_rollback "$_deployment" "$_cluster"
    ;;
  install) apps_kyso_nbdime_install "$_deployment" "$_cluster" ;;
  logs) apps_kyso_nbdime_logs "$_deployment" "$_cluster" ;;
  reinstall) apps_kyso_nbdime_reinstall "$_deployment" "$_cluster" ;;
  remove) apps_kyso_nbdime_remove "$_deployment" "$_cluster" ;;
  restart) apps_kyso_nbdime_restart "$_deployment" "$_cluster" ;;
  sh) apps_kyso_nbdime_sh "$_deployment" "$_cluster" ;;
  status) apps_kyso_nbdime_status "$_deployment" "$_cluster" ;;
  summary) apps_kyso_nbdime_summary "$_deployment" "$_cluster" ;;
  *)
    echo "Unknown kyso-nbdime subcommand '$1'"
    exit 1
    ;;
  esac
}

apps_kyso_nbdime_command_list() {
  _cmnds="env-edit env-path env-show env-update helm-history helm-rollback"
  _cmnds="$_cmnds install logs reinstall remove restart sh status summary"
  echo "$_cmnds"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
