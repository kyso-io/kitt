#!/bin/sh
# ----
# File:        apps/slack-notifications-consumer.sh
# Description: Functions to manage slack-notifications-consumer deployments
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_APPS_SLACK_NOTIFICATIONS_CONSUMER_SH="1"

# ---------
# Variables
# ---------

# CMND_DSC="slack-notifications-consumer: manage consumer deployment for kyso"

# Defaults
export DEPLOYMENT_DEFAULT_SLACK_NOTIFICATIONS_CONSUMER_IMAGE=""
export DEPLOYMENT_DEFAULT_SLACK_NOTIFICATIONS_CONSUMER_REPLICAS="1"

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

apps_slack_notifications_consumer_export_variables() {
  [ -z "$__apps_slack_notifications_consumer_export_variables" ] || return 0
  _deployment="$1"
  _cluster="$2"
  apps_common_export_variables "$_deployment" "$_cluster"
  apps_mongodb_export_variables "$_deployment" "$_cluster"
  # Values
  _ns="slack-notifications-consumer-$DEPLOYMENT_NAME"
  export SLACK_NOTIFICATIONS_CONSUMER_NAMESPACE="$_ns"
  # Directories
  _tmpl_dir="$TMPL_DIR/apps/slack-notifications-consumer"
  _kubectl_dir="$DEPLOY_KUBECTL_DIR/slack-notifications-consumer"
  _secrets_dir="$DEPLOY_SECRETS_DIR/slack-notifications-consumer"
  export SLACK_NOTIFICATIONS_CONSUMER_TMPL_DIR="$_tmpl_dir"
  export SLACK_NOTIFICATIONS_CONSUMER_KUBECTL_DIR="$_kubectl_dir"
  export SLACK_NOTIFICATIONS_CONSUMER_SECRETS_DIR="$_secrets_dir"
  # Templates
  _env_tmpl="$_tmpl_dir/slack-notifications-consumer.env"
  _deploy_tmpl="$_tmpl_dir/deploy.yaml"
  _svc_map_tmpl="$_tmpl_dir/svc_map.yaml"
  export SLACK_NOTIFICATIONS_CONSUMER_ENV_TMPL="$_env_tmpl"
  export SLACK_NOTIFICATIONS_CONSUMER_DEPLOY_TMPL="$_deploy_tmpl"
  export SLACK_NOTIFICATIONS_CONSUMER_SVC_MAP_TMPL="$_svc_map_tmpl"
  # Files
  _env_secret="$_secrets_dir/slack-notifications-consumer${SOPS_EXT}.env"
  _deploy_yaml="$_kubectl_dir/deploy.yaml"
  _secret_yaml="$_kubectl_dir/secrets${SOPS_EXT}.yaml"
  _svc_map_yaml="$_kubectl_dir/svc_map.yaml"
  export SLACK_NOTIFICATIONS_CONSUMER_ENV_SECRET="$_env_secret"
  export SLACK_NOTIFICATIONS_CONSUMER_DEPLOY_YAML="$_deploy_yaml"
  export SLACK_NOTIFICATIONS_CONSUMER_SECRET_YAML="$_secret_yaml"
  export SLACK_NOTIFICATIONS_CONSUMER_SVC_MAP_YAML="$_svc_map_yaml"
  # By default don't auto save the environment
  SLACK_NOTIFICATIONS_CONSUMER_AUTO_SAVE_ENV="false"
  # Use defaults for variables missing from config files / enviroment
  _image="$SLACK_NOTIFICATIONS_CONSUMER_IMAGE"
  if [ -z "$_image" ]; then
    if [ "$DEPLOYMENT_SLACK_NOTIFICATIONS_CONSUMER_IMAGE" ]; then
      _image="$DEPLOYMENT_SLACK_NOTIFICATIONS_CONSUMER_IMAGE"
    else
      _image="$DEPLOYMENT_DEFAULT_SLACK_NOTIFICATIONS_CONSUMER_IMAGE"
    fi
  else
    SLACK_NOTIFICATIONS_CONSUMER_AUTO_SAVE_ENV="true"
  fi
  export SLACK_NOTIFICATIONS_CONSUMER_IMAGE="$_image"
  if [ "$DEPLOYMENT_SLACK_NOTIFICATIONS_CONSUMER_REPLICAS" ]; then
    _replicas="$DEPLOYMENT_SLACK_NOTIFICATIONS_CONSUMER_REPLICAS"
  else
    _replicas="$DEPLOYMENT_DEFAULT_SLACK_NOTIFICATIONS_CONSUMER_REPLICAS"
  fi
  export SLACK_NOTIFICATIONS_CONSUMER_REPLICAS="$_replicas"
  # Export auto save environment flag
  export SLACK_NOTIFICATIONS_CONSUMER_AUTO_SAVE_ENV
  __apps_slack_notifications_consumer_export_variables="1"
}

apps_slack_notifications_consumer_check_directories() {
  apps_common_check_directories
  for _d in "$SLACK_NOTIFICATIONS_CONSUMER_KUBECTL_DIR" \
    "$SLACK_NOTIFICATIONS_CONSUMER_SECRETS_DIR"; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

apps_slack_notifications_consumer_clean_directories() {
  # Try to remove empty dirs, except if they contain secrets
  for _d in "$SLACK_NOTIFICATIONS_CONSUMER_KUBECTL_DIR" \
    "$SLACK_NOTIFICATIONS_CONSUMER_SECRETS_DIR"; do
    if [ -d "$_d" ]; then
      rmdir "$_d" 2>/dev/null || true
    fi
  done
}

apps_slack_notifications_consumer_read_variables() {
  _app="slack-notifications-consumer"
  header "Reading $_app settings"
  _ex="registry.kyso.io/kyso-io/consumers/slack-notifications-consumer/develop"
  _var="SLACK_NOTIFICATIONS_CONSUMER_IMAGE"
  read_value \
    "Notification Consumer Image URI (i.e. '$_ex' or export $_var env var)" \
    "${SLACK_NOTIFICATIONS_CONSUMER_IMAGE}"
  SLACK_NOTIFICATIONS_CONSUMER_IMAGE=${READ_VALUE}
  read_value "Notification Consumer Replicas" \
    "${SLACK_NOTIFICATIONS_CONSUMER_REPLICAS}"
  SLACK_NOTIFICATIONS_CONSUMER_REPLICAS=${READ_VALUE}
}

apps_slack_notifications_consumer_print_variables() {
  _app="slack-notifications-consumer"
  cat <<EOF
# Deployment $_app settings
# ---
# Notification Consumer Image URI, examples for local testing:
# - 'registry.kyso.io/kyso-io/consumers/slack-notifications-consumer/develop'
# - 'k3d-registry.lo.kyso.io:5000/slack-notifications-consumer:latest'
# If left empty the SLACK_NOTIFICATIONS_CONSUMER_IMAGE environment variable has
# to be set each time he slack-notifications-consumer service is installed
SLACK_NOTIFICATIONS_CONSUMER_IMAGE=$SLACK_NOTIFICATIONS_CONSUMER_IMAGE
# Number of pods to run in parallel
SLACK_NOTIFICATIONS_CONSUMER_REPLICAS=$SLACK_NOTIFICATIONS_CONSUMER_REPLICAS
# ---
EOF
}

apps_slack_notifications_consumer_logs() {
  _deployment="$1"
  _cluster="$2"
  apps_slack_notifications_consumer_export_variables "$_deployment" "$_cluster"
  _ns="$SLACK_NOTIFICATIONS_CONSUMER_NAMESPACE"
  _label="app=slack-notifications-consumer"
  kubectl -n "$_ns" logs -l "$_label" -f
}

apps_slack_notifications_consumer_install() {
  _deployment="$1"
  _cluster="$2"
  apps_slack_notifications_consumer_export_variables "$_deployment" "$_cluster"
  if [ -z "$SLACK_NOTIFICATIONS_CONSUMER_IMAGE" ]; then
    echo "The SLACK_NOTIFICATIONS_CONSUMER_IMAGE variable is empty."
    echo "Export SLACK_NOTIFICATIONS_CONSUMER_IMAGE or reconfigure."
    exit 1
  fi
  apps_common_export_service_hostnames "$_deployment" "$_cluster"
  apps_slack_notifications_consumer_check_directories
  # Initial test
  if ! find_namespace "$MONGODB_NAMESPACE"; then
    read_bool "mongodb namespace not found, abort install?" "Yes"
    if is_selected "${READ_VALUE}"; then
      return 1
    fi
  fi
  # Auto save the configuration if requested
  if is_selected "$SLACK_NOTIFICATIONS_CONSUMER_AUTO_SAVE_ENV"; then
    apps_slack_notifications_consumer_env_save "$_deployment" "$_cluster"
  fi
  # Adjust variables
  _app="slack-notifications-consumer"
  _ns="$SLACK_NOTIFICATIONS_CONSUMER_NAMESPACE"
  _env_tmpl="$SLACK_NOTIFICATIONS_CONSUMER_ENV_TMPL"
  _secret_env="$SLACK_NOTIFICATIONS_CONSUMER_ENV_SECRET"
  _secret_yaml="$SLACK_NOTIFICATIONS_CONSUMER_SECRET_YAML"
  _svc_map_tmpl="$SLACK_NOTIFICATIONS_CONSUMER_SVC_MAP_TMPL"
  _svc_map_yaml="$SLACK_NOTIFICATIONS_CONSUMER_SVC_MAP_YAML"
  _deploy_tmpl="$SLACK_NOTIFICATIONS_CONSUMER_DEPLOY_TMPL"
  _deploy_yaml="$SLACK_NOTIFICATIONS_CONSUMER_DEPLOY_YAML"
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
  _replicas="$SLACK_NOTIFICATIONS_CONSUMER_REPLICAS"
  _image="$SLACK_NOTIFICATIONS_CONSUMER_IMAGE"
  # Prepare deployment file
  sed \
    -e "s%__APP__%$_app%" \
    -e "s%__NAMESPACE__%$_ns%" \
    -e "s%__SLACK_NOTIFICATIONS_CONSUMER_REPLICAS__%$_replicas%" \
    -e "s%__SLACK_NOTIFICATIONS_CONSUMER_IMAGE__%$_image%" \
    -e "s%__IMAGE_PULL_POLICY__%$DEPLOYMENT_IMAGE_PULL_POLICY%" \
    "$_deploy_tmpl" >"$_deploy_yaml"
  # Prepare svc_map file
  sed \
    -e "s%__NAMESPACE__%$_ns%" \
    -e "s%__ELASTICSEARCH_SVC_HOSTNAME__%$ELASTICSEARCH_SVC_HOSTNAME%" \
    -e "s%__KYSO_SCS_SVC_HOSTNAME__%$KYSO_SCS_SVC_HOSTNAME%" \
    -e "s%__MONGODB_SVC_HOSTNAME__%$MONGODB_SVC_HOSTNAME%" \
    -e "s%__NATS_SVC_HOSTNAME__%$NATS_SVC_HOSTNAME%" \
    "$_svc_map_tmpl" >"$_svc_map_yaml"
  # update secret, svc_map & deployment
  for _yaml in "$_secret_yaml" "$_svc_map_yaml" "$_deploy_yaml"; do
    kubectl_apply "$_yaml"
  done
  # Wait until deployment succeds or fails (if there is one, of course)
  if [ -f "$_deploy_yaml" ]; then
    kubectl rollout status deployment --timeout="$ROLLOUT_STATUS_TIMEOUT" \
      -n "$_ns" "$_app"
  fi
}

apps_slack_notifications_consumer_reinstall() {
  _deployment="$1"
  _cluster="$2"
  apps_slack_notifications_consumer_export_variables "$_deployment" "$_cluster"
  _app="slack-notifications-consumer"
  _ns="$SLACK_NOTIFICATIONS_CONSUMER_NAMESPACE"
  if find_namespace "$_ns"; then
    _cimages="$(deployment_container_images "$_ns" "$_app")"
    _cname="slack-notifications-consumer"
    SLACK_NOTIFICATIONS_CONSUMER_IMAGE="$(echo "$_cimages" |
      sed -ne "s/^$_cname //p")"
    if [ "$SLACK_NOTIFICATIONS_CONSUMER_IMAGE" ]; then
      export SLACK_NOTIFICATIONS_CONSUMER_IMAGE
      apps_slack_notifications_consumer_install "$_deployment" "$_cluster"
    else
      echo "Image for '$_app' on '$_ns' not found!"
    fi
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

apps_slack_notifications_consumer_remove() {
  _deployment="$1"
  _cluster="$2"
  apps_slack_notifications_consumer_export_variables "$_deployment" "$_cluster"
  _app="slack-notifications-consumer"
  _ns="$SLACK_NOTIFICATIONS_CONSUMER_NAMESPACE"
  _secret_yaml="$SLACK_NOTIFICATIONS_CONSUMER_SECRET_YAML"
  _svc_map_yaml="$SLACK_NOTIFICATIONS_CONSUMER_SVC_MAP_YAML"
  _deploy_yaml="$SLACK_NOTIFICATIONS_CONSUMER_DEPLOY_YAML"
  apps_slack_notifications_consumer_export_variables
  if find_namespace "$_ns"; then
    header "Removing '$_app' objects"
    for _yaml in "$_svc_map_yaml" "$_deploy_yaml" "$_secret_yaml"; do
      kubectl_delete "$_yaml" || true
    done
    delete_namespace "$_ns"
    footer
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
  apps_slack_notifications_consumer_clean_directories
}

apps_slack_notifications_consumer_restart() {
  _deployment="$1"
  _cluster="$2"
  apps_slack_notifications_consumer_export_variables "$_deployment" "$_cluster"
  _app="slack-notifications-consumer"
  _ns="$SLACK_NOTIFICATIONS_CONSUMER_NAMESPACE"
  if find_namespace "$_ns"; then
    deployment_restart "$_ns" "$_app"
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

apps_slack_notifications_consumer_status() {
  _deployment="$1"
  _cluster="$2"
  apps_slack_notifications_consumer_export_variables "$_deployment" "$_cluster"
  _app="slack-notifications-consumer"
  _ns="$SLACK_NOTIFICATIONS_CONSUMER_NAMESPACE"
  if find_namespace "$_ns"; then
    kubectl get all,endpoints,ingress,secrets -n "$_ns"
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

apps_slack_notifications_consumer_summary() {
  _deployment="$1"
  _cluster="$2"
  apps_slack_notifications_consumer_export_variables "$_deployment" "$_cluster"
  _ns="$SLACK_NOTIFICATIONS_CONSUMER_NAMESPACE"
  _app="slack-notifications-consumer"
  deployment_summary "$_ns" "$_app"
}

apps_slack_notifications_consumer_env_edit() {
  if [ "$EDITOR" ]; then
    _app="slack-notifications-consumer"
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

apps_slack_notifications_consumer_env_path() {
  _app="slack-notifications-consumer"
  _deployment="$1"
  _cluster="$2"
  apps_export_variables "$_deployment" "$_cluster"
  _env_file="$DEPLOY_ENVS_DIR/$_app.env"
  echo "$_env_file"
}

apps_slack_notifications_consumer_env_save() {
  _app="slack-notifications-consumer"
  _deployment="$1"
  _cluster="$2"
  apps_export_variables "$_deployment" "$_cluster"
  _env_file="$DEPLOY_ENVS_DIR/$_app.env"
  apps_slack_notifications_consumer_check_directories
  apps_slack_notifications_consumer_print_variables "$_deployment" "$_cluster" |
    stdout_to_file "$_env_file"
}

apps_slack_notifications_consumer_env_update() {
  _app="slack-notifications-consumer"
  _deployment="$1"
  _cluster="$2"
  apps_export_variables "$_deployment" "$_cluster"
  _env_file="$DEPLOY_ENVS_DIR/$_app.env"
  header "$_app configuration variables"
  apps_slack_notifications_consumer_print_variables "$_deployment" "$_cluster" |
    grep -v "^#"
  if [ -f "$_env_file" ]; then
    footer
    read_bool "Update $_app env vars?" "No"
  else
    READ_VALUE="Yes"
  fi
  if is_selected "${READ_VALUE}"; then
    footer
    apps_slack_notifications_consumer_read_variables
    if [ -f "$_env_file" ]; then
      footer
      read_bool "Save updated $_app env vars?" "Yes"
    else
      READ_VALUE="Yes"
    fi
    if is_selected "${READ_VALUE}"; then
      apps_slack_notifications_consumer_env_save "$_deployment" "$_cluster"
      footer
      echo "$_app configuration saved to '$_env_file'"
      footer
    fi
  fi
}

apps_slack_notifications_consumer_command() {
  _command="$1"
  _deployment="$2"
  _cluster="$3"
  case "$_command" in
  env-edit | env_edit)
    apps_slack_notifications_consumer_env_edit "$_deployment" "$_cluster"
    ;;
  env-path | env_path)
    apps_slack_notifications_consumer_env_path "$_deployment" "$_cluster"
    ;;
  env-show | env_show)
    apps_slack_notifications_consumer_print_variables "$_deployment" \
      "$_cluster" | grep -v '^#'
    ;;
  env-update | env_update)
    apps_slack_notifications_consumer_env_update "$_deployment" "$_cluster"
    ;;
  logs) apps_slack_notifications_consumer_logs "$_deployment" "$_cluster" ;;
  install) apps_slack_notifications_consumer_install "$_deployment" \
    "$_cluster" ;;
  reinstall) apps_slack_notifications_consumer_reinstall "$_deployment" \
    "$_cluster" ;;
  remove) apps_slack_notifications_consumer_remove "$_deployment" "$_cluster" ;;
  restart) apps_slack_notifications_consumer_restart "$_deployment" \
    "$_cluster" ;;
  status) apps_slack_notifications_consumer_status "$_deployment" "$_cluster" ;;
  summary) apps_slack_notifications_consumer_summary "$_deployment" \
    "$_cluster" ;;
  *)
    echo "Unknown slack-notifications-consumer subcommand '$1'"
    exit 1
    ;;
  esac
}

apps_slack_notifications_consumer_command_list() {
  _cmnds="env-edit env-path env-show env-update install logs reinstall remove"
  _cmnds="$_cmnds restart status summary"
  echo "$_cmnds"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
