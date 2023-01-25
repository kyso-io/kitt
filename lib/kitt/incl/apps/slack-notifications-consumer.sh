#!/bin/sh
# ----
# File:        apps/slack-notifications-consumer.sh
# Description: Functions to manage slack-notifications-consumer deployments
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022-2023 Sergio Talens-Oliag <sto@kyso.io>
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
  export SLACK_NOTIFICATIONS_CONSUMER_CHART_DIR="$CHARTS_DIR/slack-notifications-consumer"
  _tmpl_dir="$TMPL_DIR/apps/slack-notifications-consumer"
  export SLACK_NOTIFICATIONS_CONSUMER_TMPL_DIR="$_tmpl_dir"
  _helm_dir="$DEPLOY_HELM_DIR/slack-notifications-consumer"
  export SLACK_NOTIFICATIONS_CONSUMER_HELM_DIR="$_helm_dir"
  _kubectl_dir="$DEPLOY_KUBECTL_DIR/slack-notifications-consumer"
  export SLACK_NOTIFICATIONS_CONSUMER_KUBECTL_DIR="$_kubectl_dir"
  # BEG: Deprecated directories
  _secrets_dir="$DEPLOY_SECRETS_DIR/slack-notifications-consumer"
  export SLACK_NOTIFICATIONS_CONSUMER_SECRETS_DIR="$_secrets_dir"
  # END: Deprecated directories
  # Templates
  export SLACK_NOTIFICATIONS_CONSUMER_SVC_MAP_TMPL="$_tmpl_dir/svc_map.yaml"
  export SLACK_NOTIFICATIONS_CONSUMER_HELM_VALUES_TMPL="$_tmpl_dir/values.yaml"
  # BEG: deprecated files
  _env_secret="$_secrets_dir/slack-notifications-consumer${SOPS_EXT}.env"
  export SLACK_NOTIFICATIONS_CONSUMER_ENV_SECRET="$_env_secret"
  export SLACK_NOTIFICATIONS_CONSUMER_DEPLOY_YAML="$_kubectl_dir/deploy.yaml"
  _secret_yaml="$_kubectl_dir/secrets${SOPS_EXT}.yaml"
  export SLACK_NOTIFICATIONS_CONSUMER_SECRET_YAML="$_secret_yaml"
  # END: deprecated files
  # Files
  _svc_map_yaml="$_kubectl_dir/svc_map.yaml"
  export SLACK_NOTIFICATIONS_CONSUMER_SVC_MAP_YAML="$_svc_map_yaml"
  _helm_values_yaml="$_helm_dir/values${SOPS_EXT}.yaml"
  export SLACK_NOTIFICATIONS_CONSUMER_HELM_VALUES_YAML="$_helm_values_yaml"
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
  for _d in "$SLACK_NOTIFICATIONS_CONSUMER_HELM_DIR" \
    "$SLACK_NOTIFICATIONS_CONSUMER_KUBECTL_DIR"; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

apps_slack_notifications_consumer_clean_directories() {
  # Try to remove empty dirs, except if they contain secrets
  for _d in "$SLACK_NOTIFICATIONS_CONSUMER_HELM_DIR" \
    "$SLACK_NOTIFICATIONS_CONSUMER_KUBECTL_DIR" \
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
  _app="slack-notifications-consumer"
  _ns="$SLACK_NOTIFICATIONS_CONSUMER_NAMESPACE"
  if kubectl get -n "$_ns" "deployments/$_app" >/dev/null 2>&1; then
    kubectl -n "$_ns" logs "deployments/$_app" -f
  else
    echo "Deployment '$_app' not found on namespace '$_ns'"
  fi
}

apps_slack_notifications_consumer_sh() {
  _deployment="$1"
  _cluster="$2"
  apps_slack_notifications_consumer_export_variables "$_deployment" "$_cluster"
  _app="slack-notifications-consumer"
  _ns="$SLACK_NOTIFICATIONS_CONSUMER_NAMESPACE"
  if kubectl get -n "$_ns" "deployments/$_app" >/dev/null 2>&1; then
    kubectl -n "$_ns" exec -ti "deployments/$_app" -- /bin/sh
  else
    echo "Deployment '$_app' not found on namespace '$_ns'"
  fi
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
  # Initial test
  if ! find_namespace "$MONGODB_NAMESPACE"; then
    read_bool "mongodb namespace not found, abort install?" "Yes"
    if is_selected "${READ_VALUE}"; then
      return 1
    fi
  fi
  # Load additional variables & check directories
  apps_common_export_service_hostnames "$_deployment" "$_cluster"
  apps_slack_notifications_consumer_check_directories
  # Auto save the configuration if requested
  if is_selected "$SLACK_NOTIFICATIONS_CONSUMER_AUTO_SAVE_ENV"; then
    apps_slack_notifications_consumer_env_save "$_deployment" "$_cluster"
  fi
  # Adjust variables
  _app="slack-notifications-consumer"
  _ns="$SLACK_NOTIFICATIONS_CONSUMER_NAMESPACE"
  # directories
  _chart="$SLACK_NOTIFICATIONS_CONSUMER_CHART_DIR"
  # deprecated files
  _secret_env="$SLACK_NOTIFICATIONS_CONSUMER_ENV_SECRET"
  _secret_yaml="$SLACK_NOTIFICATIONS_CONSUMER_SECRET_YAML"
  _svc_map_yaml="$SLACK_NOTIFICATIONS_CONSUMER_SVC_MAP_YAML"
  _deploy_tmpl="$SLACK_NOTIFICATIONS_CONSUMER_DEPLOY_TMPL"
  _deploy_yaml="$SLACK_NOTIFICATIONS_CONSUMER_DEPLOY_YAML"
  # files
  _helm_values_tmpl="$SLACK_NOTIFICATIONS_CONSUMER_HELM_VALUES_TMPL"
  _helm_values_yaml="$SLACK_NOTIFICATIONS_CONSUMER_HELM_VALUES_YAML"
  _svc_map_tmpl="$SLACK_NOTIFICATIONS_CONSUMER_SVC_MAP_TMPL"
  _svc_map_yaml="$SLACK_NOTIFICATIONS_CONSUMER_SVC_MAP_YAML"
  if ! find_namespace "$_ns"; then
    # Remove old files, just in case ...
    # shellcheck disable=SC2086
    rm -f "$_helm_values_yaml" "$_svc_map_yaml" \
      "$_service_yaml" "$_deploy_yaml" "$_ingress_yaml"
    # Create namespace
    create_namespace "$_ns"
  fi
  # If we have a legacy deployment, remove the old objects
  for _yaml in "$_secret_env" "$_secret_yaml" "$_deploy_yaml"; do
    kubectl_delete "$_yaml" || true
  done
  # Image settings
  _image_repo="${SLACK_NOTIFICATIONS_CONSUMER_IMAGE%:*}"
  _image_tag="${SLACK_NOTIFICATIONS_CONSUMER_IMAGE#*:}"
  if [ "$_image_repo" = "$_image_tag" ]; then
    _image_tag="latest"
  fi
  # Get the database uri
  _mongodb_user_database_uri="$(
    apps_mongodb_print_user_database_uri "$_deployment" "$_cluster"
  )"
  # Prepare values.yaml file
  _replicas="$SLACK_NOTIFICATIONS_CONSUMER_REPLICAS"
  sed \
    -e "s%__SLACK_NOTIFICATIONS_CONSUMER_REPLICAS__%$_replicas%" \
    -e "s%__SLACK_NOTIFICATIONS_CONSUMER_IMAGE_REPO__%$_image_repo%" \
    -e "s%__SLACK_NOTIFICATIONS_CONSUMER_IMAGE_TAG__%$_image_tag%" \
    -e "s%__IMAGE_PULL_POLICY__%$DEPLOYMENT_IMAGE_PULL_POLICY%" \
    -e "s%__PULL_SECRETS_NAME__%$CLUSTER_PULL_SECRETS_NAME%" \
    -e "s%__MONGODB_DATABASE_URI__%$_mongodb_user_database_uri%" \
    "$_helm_values_tmpl" | stdout_to_file "$_helm_values_yaml"
  # Prepare svc_map file
  sed \
    -e "s%__NAMESPACE__%$_ns%" \
    -e "s%__ELASTICSEARCH_SVC_HOSTNAME__%$ELASTICSEARCH_SVC_HOSTNAME%" \
    -e "s%__KYSO_SCS_SVC_HOSTNAME__%$KYSO_SCS_SVC_HOSTNAME%" \
    -e "s%__MONGODB_SVC_HOSTNAME__%$MONGODB_SVC_HOSTNAME%" \
    -e "s%__NATS_SVC_HOSTNAME__%$NATS_SVC_HOSTNAME%" \
    "$_svc_map_tmpl" >"$_svc_map_yaml"
  # Install map
  for _yaml in $_svc_map_yaml; do
    kubectl_apply "$_yaml"
  done
  # Install helm chart
  helm_upgrade "$_ns" "$_helm_values_yaml" "$_app" "$_chart"
  # Wait until deployment succeds or fails
  kubectl rollout status deployment --timeout="$ROLLOUT_STATUS_TIMEOUT" \
    -n "$_ns" "$_app"
}

apps_slack_notifications_consumer_helm_history() {
  _deployment="$1"
  _cluster="$2"
  apps_slack_notifications_consumer_export_variables "$_deployment" "$_cluster"
  _app="slack-notifications-consumer"
  _ns="$SLACK_NOTIFICATIONS_CONSUMER_NAMESPACE"
  if find_namespace "$_ns"; then
    helm_history "$_ns" "$_app"
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

apps_slack_notifications_consumer_helm_rollback() {
  _deployment="$1"
  _cluster="$2"
  apps_slack_notifications_consumer_export_variables "$_deployment" "$_cluster"
  _app="slack-notifications-consumer"
  _ns="$SLACK_NOTIFICATIONS_CONSUMER_NAMESPACE"
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
    # Uninstall chart
    if [ -f "$_helm_values_yaml" ]; then
      helm uninstall -n "$_ns" "$_app" || true
      rm -f "$_helm_values_yaml"
    fi
    # Remove objects
    for _yaml in $_svc_map_yaml; do
      kubectl_delete "$_yaml" || true
    done
    # Remove legacy objects
    for _yaml in "$_secret_yaml" "$_deploy_yaml"; do
      kubectl_delete "$_yaml" || true
    done
    # Remove legacy files
    if [ -f "$_secret_env" ]; then
      rm -f "$_secret_env"
    fi
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
    [ "$KITT_AUTOUPDATE" = "true" ] && _update="Yes" || _update="No"
    read_bool "Update $_app env vars?" "$_update"
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
  helm-history)
    apps_slack_notifications_consumer_helm_history "$_deployment" "$_cluster"
    ;;
  helm-rollback)
    apps_slack_notifications_consumer_helm_rollback "$_deployment" "$_cluster"
    ;;
  install)
    apps_slack_notifications_consumer_install "$_deployment" "$_cluster"
    ;;
  logs) apps_slack_notifications_consumer_logs "$_deployment" "$_cluster" ;;
  reinstall)
    apps_slack_notifications_consumer_reinstall "$_deployment" "$_cluster"
    ;;
  remove) apps_slack_notifications_consumer_remove "$_deployment" "$_cluster" ;;
  restart)
    apps_slack_notifications_consumer_restart "$_deployment" "$_cluster"
    ;;
  sh) apps_slack_notifications_consumer_sh "$_deployment" "$_cluster" ;;
  status)
    apps_slack_notifications_consumer_status "$_deployment" "$_cluster"
    ;;
  summary)
    apps_slack_notifications_consumer_summary "$_deployment" "$_cluster"
    ;;
  *)
    echo "Unknown slack-notifications-consumer subcommand '$1'"
    exit 1
    ;;
  esac
}

apps_slack_notifications_consumer_command_list() {
  _cmnds="env-edit env-path env-show env-update helm-history helm-rollback"
  _cmnds="$_cmnds install logs reinstall remove restart sh status summary"
  echo "$_cmnds"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
