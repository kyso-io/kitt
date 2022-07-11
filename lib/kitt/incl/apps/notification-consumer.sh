#!/bin/sh
# ----
# File:        apps/notification-consumer.sh
# Description: Functions to manage notification-consumer deployments
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_APPS_NOTIFICATION_CONSUMER_SH="1"

# ---------
# Variables
# ---------

# CMND_DSC="notification-consumer: manage consumer deployment for kyso"

# Defaults
export DEPLOYMENT_DEFAULT_NOTIFICATION_CONSUMER_IMAGE=""
export DEPLOYMENT_DEFAULT_NOTIFICATION_CONSUMER_REPLICAS="1"

# Fixed values
export NOTIFICATION_CONSUMER_PORT="3000"

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

apps_notification_consumer_export_variables() {
  [ -z "$__apps_notification_consumer_export_variables" ] || return 0
  _deployment="$1"
  _cluster="$2"
  apps_common_export_variables "$_deployment" "$_cluster"
  apps_mongodb_export_variables "$_deployment" "$_cluster"
  # Values
  _ns="notification-consumer-$DEPLOYMENT_NAME"
  export NOTIFICATION_CONSUMER_NAMESPACE="$_ns"
  # Directories
  _tmpl_dir="$TMPL_DIR/apps/notification-consumer"
  _kubectl_dir="$DEPLOY_KUBECTL_DIR/notification-consumer"
  _secrets_dir="$DEPLOY_SECRETS_DIR/notification-consumer"
  export NOTIFICATION_CONSUMER_TMPL_DIR="$_tmpl_dir"
  export NOTIFICATION_CONSUMER_KUBECTL_DIR="$_kubectl_dir"
  export NOTIFICATION_CONSUMER_SECRETS_DIR="$_secrets_dir"
  # Templates
  _env_tmpl="$_tmpl_dir/notification-consumer.env"
  _deploy_tmpl="$_tmpl_dir/deploy.yaml"
  _service_tmpl="$_tmpl_dir/service.yaml"
  export NOTIFICATION_CONSUMER_ENV_TMPL="$_env_tmpl"
  export NOTIFICATION_CONSUMER_DEPLOY_TMPL="$_deploy_tmpl"
  export NOTIFICATION_CONSUMER_SERVICE_TMPL="$_service_tmpl"
  # Files
  _env_secret="$_secrets_dir/notification-consumer${SOPS_EXT}.env"
  _deploy_yaml="$_kubectl_dir/deploy.yaml"
  _secret_yaml="$_kubectl_dir/secrets${SOPS_EXT}.yaml"
  _service_yaml="$_kubectl_dir/service.yaml"
  export NOTIFICATION_CONSUMER_ENV_SECRET="$_env_secret"
  export NOTIFICATION_CONSUMER_DEPLOY_YAML="$_deploy_yaml"
  export NOTIFICATION_CONSUMER_SECRET_YAML="$_secret_yaml"
  export NOTIFICATION_CONSUMER_SERVICE_YAML="$_service_yaml"
  # Use defaults for variables missing from config files / enviroment
  _image="$NOTIFICATION_CONSUMER_IMAGE"
  if [ -z "$_image" ]; then
    if [ "$DEPLOYMENT_NOTIFICATION_CONSUMER_IMAGE" ]; then
      _image="$DEPLOYMENT_NOTIFICATION_CONSUMER_IMAGE"
    else
      _image="$DEPLOYMENT_DEFAULT_NOTIFICATION_CONSUMER_IMAGE"
    fi
  fi
  export NOTIFICATION_CONSUMER_IMAGE="$_image"
  if [ "$DEPLOYMENT_NOTIFICATION_CONSUMER_REPLICAS" ]; then
    _replicas="$DEPLOYMENT_NOTIFICATION_CONSUMER_REPLICAS"
  else
    _replicas="$DEPLOYMENT_DEFAULT_NOTIFICATION_CONSUMER_REPLICAS"
  fi
  export NOTIFICATION_CONSUMER_REPLICAS="$_replicas"
  __apps_notification_consumer_export_variables="1"
}

apps_notification_consumer_check_directories() {
  apps_common_check_directories
  for _d in "$NOTIFICATION_CONSUMER_KUBECTL_DIR" \
    "$NOTIFICATION_CONSUMER_SECRETS_DIR"; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

apps_notification_consumer_clean_directories() {
  # Try to remove empty dirs, except if they contain secrets
  for _d in "$NOTIFICATION_CONSUMER_KUBECTL_DIR" \
    "$NOTIFICATION_CONSUMER_SECRETS_DIR"; do
    if [ -d "$_d" ]; then
      rmdir "$_d" 2>/dev/null || true
    fi
  done
}

apps_notification_consumer_read_variables() {
  _app="notification-consumer"
  header "Reading $_app settings"
  _ex="registry.kyso.io/kyso-io/consumers/notification-consumer/develop:latest"
  _var="NOTIFICATION_CONSUMER_IMAGE"
  read_value \
    "Notification Consumer Image URI (i.e. '$_ex' or export $_var env var)" \
    "${NOTIFICATION_CONSUMER_IMAGE}"
  NOTIFICATION_CONSUMER_IMAGE=${READ_VALUE}
  read_value "Notification Consumer Replicas" \
    "${NOTIFICATION_CONSUMER_REPLICAS}"
  NOTIFICATION_CONSUMER_REPLICAS=${READ_VALUE}
}

apps_notification_consumer_print_variables() {
  _app="notification-consumer"
  cat <<EOF
# Deployment $_app settings
# ---
# Notification Consumer Image URI, examples for local testing:
# - 'registry.kyso.io/kyso-io/consumers/notification-consumer/develop:latest'
# - 'k3d-registry.lo.kyso.io:5000/notification-consumer:latest'
# If left empty the NOTIFICATION_CONSUMER_IMAGE environment variable has to be
# set each time he notification-consumer service is installed
NOTIFICATION_CONSUMER_IMAGE=$NOTIFICATION_CONSUMER_IMAGE
# Number of pods to run in parallel
NOTIFICATION_CONSUMER_REPLICAS=$NOTIFICATION_CONSUMER_REPLICAS
# ---
EOF
}

apps_notification_consumer_logs() {
  _deployment="$1"
  _cluster="$2"
  apps_notification_consumer_export_variables "$_deployment" "$_cluster"
  _ns="$NOTIFICATION_CONSUMER_NAMESPACE"
  _label="app=notification-consumer"
  kubectl -n "$_ns" logs -l "$_label" -f
}

apps_notification_consumer_install() {
  _deployment="$1"
  _cluster="$2"
  apps_notification_consumer_export_variables "$_deployment" "$_cluster"
  if [ -z "$NOTIFICATION_CONSUMER_IMAGE" ]; then
    echo "The NOTIFICATION_CONSUMER_IMAGE variable is empty."
    echo "Export NOTIFICATION_CONSUMER_IMAGE or reconfigure."
    exit 1
  fi
  apps_notification_consumer_check_directories
  # Initial test
  if ! find_namespace "$MONGODB_NAMESPACE"; then
    read_bool "mongodb namespace not found, abort install?" "Yes"
    if is_selected "${READ_VALUE}"; then
      return 1
    fi
  fi
  # Adjust variables
  _app="notification-consumer"
  _ns="$NOTIFICATION_CONSUMER_NAMESPACE"
  _env_tmpl="$NOTIFICATION_CONSUMER_ENV_TMPL"
  _secret_env="$NOTIFICATION_CONSUMER_ENV_SECRET"
  _secret_yaml="$NOTIFICATION_CONSUMER_SECRET_YAML"
  _service_tmpl="$NOTIFICATION_CONSUMER_SERVICE_TMPL"
  _service_yaml="$NOTIFICATION_CONSUMER_SERVICE_YAML"
  _deploy_tmpl="$NOTIFICATION_CONSUMER_DEPLOY_TMPL"
  _deploy_yaml="$NOTIFICATION_CONSUMER_DEPLOY_YAML"
  if ! find_namespace "$_ns"; then
    # Remove old files, just in case ...
    # shellcheck disable=SC2086
    rm -f "$_service_yaml" "$_deploy_yaml" "$_ingress_yaml"
    # Create namespace
    create_namespace "$_ns"
  fi
  # Prepare secrets
  : >"$_secret_env"
  chmod 0600 "$_secret_env"
  _mongodb_user_database_uri="$(
    apps_mongodb_print_user_database_uri "$_deployment" "$_cluster"
  )"
  sed \
    -e "s%__MONGODB_DATABASE_URI__%$_mongodb_user_database_uri%" \
    -e "s%__SERVER_PORT__%$NOTIFICATION_CONSUMER_PORT%" \
    "$_env_tmpl" |
    stdout_to_file "$_secret_env"
  : >"$_secret_yaml"
  chmod 0600 "$_secret_yaml"
  tmp_dir="$(mktemp -d)"
  file_to_stdout "$_secret_env" >"$tmp_dir/env"
  kubectl create secret generic "$_app-secrets" --dry-run=client -o yaml \
    --from-file=env="$tmp_dir/env" --namespace="$_ns" |
    stdout_to_file "$_secret_yaml"
  rm -rf "$tmp_dir"
  # Prepare deployment file
  sed \
    -e "s%__APP__%$_app%" \
    -e "s%__NAMESPACE__%$_ns%" \
    -e "s%__SERVER_PORT__%$NOTIFICATION_CONSUMER_PORT%" \
    -e "s%__NOTIFICATION_CONSUMER_REPLICAS__%$NOTIFICATION_CONSUMER_REPLICAS%" \
    -e "s%__NOTIFICATION_CONSUMER_IMAGE__%$NOTIFICATION_CONSUMER_IMAGE%" \
    -e "s%__IMAGE_PULL_POLICY__%$DEPLOYMENT_IMAGE_PULL_POLICY%" \
    "$_deploy_tmpl" >"$_deploy_yaml"
  # Prepare service_yaml
  sed \
    -e "s%__APP__%$_app%" \
    -e "s%__NAMESPACE__%$_ns%" \
    -e "s%__SERVER_PORT__%$NOTIFICATION_CONSUMER_PORT%" \
    "$_service_tmpl" >"$_service_yaml"
  for _yaml in "$_secret_yaml" "$_service_yaml" "$_deploy_yaml"; do
    kubectl_apply "$_yaml"
  done
  # Wait until deployment succeds or fails (if there is one, of course)
  if [ -f "$_deploy_yaml" ]; then
    kubectl rollout status deployment --timeout="$ROLLOUT_STATUS_TIMEOUT" \
      -n "$_ns" "$_app"
  fi
}

apps_notification_consumer_reinstall() {
  _deployment="$1"
  _cluster="$2"
  apps_notification_consumer_export_variables "$_deployment" "$_cluster"
  _app="notification-consumer"
  _ns="$NOTIFICATION_CONSUMER_NAMESPACE"
  if find_namespace "$_ns"; then
    _cimages="$(deployment_container_images "$_ns" "$_app")"
    _cname="notification-consumer"
    NOTIFICATION_CONSUMER_IMAGE="$(echo "$_cimages" | sed -ne "s/^$_cname //p")"
    if [ "$NOTIFICATION_CONSUMER_IMAGE" ]; then
      export NOTIFICATION_CONSUMER_IMAGE
      apps_notification_consumer_install "$_deployment" "$_cluster"
    else
      echo "Image for '$_app' on '$_ns' not found!"
    fi
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

apps_notification_consumer_remove() {
  _deployment="$1"
  _cluster="$2"
  apps_notification_consumer_export_variables "$_deployment" "$_cluster"
  _app="notification-consumer"
  _ns="$NOTIFICATION_CONSUMER_NAMESPACE"
  _secret_yaml="$NOTIFICATION_CONSUMER_SECRET_YAML"
  _svc_yaml="$NOTIFICATION_CONSUMER_SVC_YAML"
  _deploy_yaml="$NOTIFICATION_CONSUMER_DEPLOY_YAML"
  apps_notification_consumer_export_variables
  if find_namespace "$_ns"; then
    header "Removing '$_app' objects"
    for _yaml in "$_svc_yaml" "$_deploy_yaml" "$_secret_yaml"; do
      kubectl_delete "$_yaml" || true
    done
    delete_namespace "$_ns"
    footer
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
  apps_notification_consumer_clean_directories
}

apps_notification_consumer_restart() {
  _deployment="$1"
  _cluster="$2"
  apps_notification_consumer_export_variables "$_deployment" "$_cluster"
  _app="notification-consumer"
  _ns="$NOTIFICATION_CONSUMER_NAMESPACE"
  if find_namespace "$_ns"; then
    deployment_restart "$_ns" "$_app"
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

apps_notification_consumer_status() {
  _deployment="$1"
  _cluster="$2"
  apps_notification_consumer_export_variables "$_deployment" "$_cluster"
  _app="notification-consumer"
  _ns="$NOTIFICATION_CONSUMER_NAMESPACE"
  if find_namespace "$_ns"; then
    kubectl get all,endpoints,ingress,secrets -n "$_ns"
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

apps_notification_consumer_summary() {
  _deployment="$1"
  _cluster="$2"
  apps_notification_consumer_export_variables "$_deployment" "$_cluster"
  _ns="$NOTIFICATION_CONSUMER_NAMESPACE"
  _app="notification-consumer"
  deployment_summary "$_ns" "$_app"
}

apps_notification_consumer_env_edit() {
  if [ "$EDITOR" ]; then
    _app="notification-consumer"
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

apps_notification_consumer_env_path() {
  _app="notification-consumer"
  _deployment="$1"
  _cluster="$2"
  apps_export_variables "$_deployment" "$_cluster"
  _env_file="$DEPLOY_ENVS_DIR/$_app.env"
  echo "$_env_file"
}

apps_notification_consumer_env_save() {
  _app="notification-consumer"
  _deployment="$1"
  _cluster="$2"
  _env_file="$3"
  apps_notification_consumer_check_directories
  apps_notification_consumer_print_variables "$_deployment" "$_cluster" |
    stdout_to_file "$_env_file"
}

apps_notification_consumer_env_update() {
  _app="notification-consumer"
  _deployment="$1"
  _cluster="$2"
  apps_export_variables "$_deployment" "$_cluster"
  _env_file="$DEPLOY_ENVS_DIR/$_app.env"
  header "$_app configuration variables"
  apps_notification_consumer_print_variables "$_deployment" "$_cluster" |
    grep -v "^#"
  if [ -f "$_env_file" ]; then
    footer
    read_bool "Update $_app env vars?" "No"
  else
    READ_VALUE="Yes"
  fi
  if is_selected "${READ_VALUE}"; then
    footer
    apps_notification_consumer_read_variables
    if [ -f "$_env_file" ]; then
      footer
      read_bool "Save updated $_app env vars?" "Yes"
    else
      READ_VALUE="Yes"
    fi
    if is_selected "${READ_VALUE}"; then
      apps_notification_consumer_env_save "$_deployment" "$_cluster" "$_env_file"
      footer
      echo "$_app configuration saved to '$_env_file'"
      footer
    fi
  fi
}

apps_notification_consumer_command() {
  _command="$1"
  _deployment="$2"
  _cluster="$3"
  case "$_command" in
  env-edit | env_edit)
    apps_notification_consumer_env_edit "$_deployment" "$_cluster"
    ;;
  env-path | env_path)
    apps_notification_consumer_env_path "$_deployment" "$_cluster"
    ;;
  env-show | env_show)
    apps_notification_consumer_print_variables "$_deployment" "$_cluster" |
      grep -v '^#'
    ;;
  env-update | env_update)
    apps_notification_consumer_env_update "$_deployment" "$_cluster"
    ;;
  logs) apps_notification_consumer_logs "$_deployment" "$_cluster" ;;
  install) apps_notification_consumer_install "$_deployment" "$_cluster" ;;
  reinstall) apps_notification_consumer_reinstall "$_deployment" "$_cluster" ;;
  remove) apps_notification_consumer_remove "$_deployment" "$_cluster" ;;
  restart) apps_notification_consumer_restart "$_deployment" "$_cluster" ;;
  status) apps_notification_consumer_status "$_deployment" "$_cluster" ;;
  summary) apps_notification_consumer_summary "$_deployment" "$_cluster" ;;
  *)
    echo "Unknown notification-consumer subcommand '$1'"
    exit 1
    ;;
  esac
}

apps_notification_consumer_command_list() {
  _cmnds="env-edit env-path env-show env-update install logs reinstall remove"
  _cmnds="$_cmnds restart status summary"
  echo "$_cmnds"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
