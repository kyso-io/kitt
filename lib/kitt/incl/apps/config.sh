#!/bin/sh
# ----
# File:        apps/config.sh
# Description: Functions to configure a kyso application deployment
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_APPS_CONFIG_SH="1"

# ---------
# Variables
# ---------

# CMND_DSC="config: configure a kyso application deployment"

# --------
# Includes
# --------

if [ -d "$INCL_DIR" ]; then
  # shellcheck source=../common.sh
  [ "$INCL_COMMON_SH" = "1" ] || . "$INCL_DIR/common.sh"
  # shellcheck source=./common.sh
  [ "$INCL_APPS_COMMON_SH" = "1" ] || . "$INCL_DIR/apps/common.sh"
  # shellcheck source=./elasticsearch.sh
  [ "$INCL_APPS_ELASTICSEARCH_SH" = "1" ] || . "$INCL_DIR/apps/elasticsearch.sh"
  # shellcheck source=./mongodb.sh
  [ "$INCL_APPS_MONGODB_SH" = "1" ] || . "$INCL_DIR/apps/mongodb.sh"
  # shellcheck source=./nats.sh
  [ "$INCL_APPS_NATS_SH" = "1" ] || . "$INCL_DIR/apps/nats.sh"
  # shellcheck source=./mongo-gui.sh
  [ "$INCL_APPS_MONGO_GUI_SH" = "1" ] || . "$INCL_DIR/apps/mongo-gui.sh"
  # shellcheck source=./kyso-api.sh
  [ "$INCL_APPS_KYSO_API_SH" = "1" ] || . "$INCL_DIR/apps/kyso-api.sh"
  # shellcheck source=./kyso-front.sh
  [ "$INCL_APPS_KYSO_FRONT_SH" = "1" ] || . "$INCL_DIR/apps/kyso-front.sh"
  # shellcheck source=./kyso-scs.sh
  [ "$INCL_APPS_KYSO_SCS_SH" = "1" ] || . "$INCL_DIR/apps/kyso-scs.sh"
  # shellcheck source=./activity-feed-consumer.sh
  [ "$INCL_APPS_ACTIVITY_FEED_CONSUMER_SH" = "1" ] ||
    . "$INCL_DIR/apps/activity-feed-consumer.sh"
  # shellcheck source=./notification-consumer.sh
  [ "$INCL_APPS_NOTIFICATION_CONSUMER_SH" = "1" ] ||
    . "$INCL_DIR/apps/notification-consumer.sh"
  # shellcheck source=./slack-notifications-consumer.sh
  [ "$INCL_APPS_SLACK_NOTIFICATIONS_CONSUMER_SH" = "1" ] ||
    . "$INCL_DIR/apps/slack-notifications-consumer.sh"
  # shellcheck source=./onlyoffice-ds.sh
  [ "$INCL_APPS_ONLYOFFICE_DS_SH" = "1" ] || . "$INCL_DIR/apps/onlyoffice-ds.sh"
  # shellcheck source=./portmaps.sh
  [ "$INCL_APPS_PORTMAPS_SH" = "1" ] || . "$INCL_DIR/apps/portmaps.sh"
fi

# ---------
# Functions
# ---------

apps_export_variables() {
  # Check if we need to run the function
  [ -z "$__apps_export_variables" ] || return 0
  _deployment="$1"
  _cluster="$2"
  apps_common_export_variables "$_deployment" "$_cluster"
  apps_elasticsearch_export_variables "$_deployment" "$_cluster"
  apps_mongodb_export_variables "$_deployment" "$_cluster"
  apps_nats_export_variables "$_deployment" "$_cluster"
  apps_mongo_gui_export_variables "$_deployment" "$_cluster"
  apps_kyso_api_export_variables "$_deployment" "$_cluster"
  apps_kyso_front_export_variables "$_deployment" "$_cluster"
  apps_kyso_scs_export_variables "$_deployment" "$_cluster"
  apps_activity_feed_consumer_export_variables "$_deployment" "$_cluster"
  apps_notification_consumer_export_variables "$_deployment" "$_cluster"
  apps_slack_notifications_consumer_export_variables "$_deployment" "$_cluster"
  apps_onlyoffice_ds_export_variables "$_deployment" "$_cluster"
  apps_imagebox_export_variables "$_deployment" "$_cluster"
  apps_kyso_nbdime_export_variables "$_deployment" "$_cluster"
  # set variable to avoid running the function twice
  __apps_export_variables="1"
}

apps_check_directories() {
  apps_common_check_directories
  apps_elasticsearch_check_directories
  apps_mongodb_check_directories
  apps_nats_check_directories
  apps_mongo_gui_check_directories
  apps_kyso_api_check_directories
  apps_kyso_front_check_directories
  apps_kyso_scs_check_directories
  apps_activity_feed_consumer_check_directories
  apps_notification_consumer_check_directories
  apps_slack_notifications_consumer_check_directories
  apps_onlyoffice_ds_check_directories
  apps_imagebox_check_directories
  apps_portmaps_check_directories
}

apps_migrate_variables() {
  _deployment="$1"
  _cluster="$2"
  apps_export_variables "$_deployment" "$_cluster"
  if [ -f "$DEPLOYMENT_CONFIG" ]; then
    echo "Migrating '$DEPLOYMENT_CONFIG' to multiple files"
    _env_file="$(apps_common_env_path)"
    apps_common_env_save "$_deployment" "$_cluster" "$_env_file"
    _env_file="$(apps_elasticsearch_env_path)"
    apps_elasticsearch_env_save "$_deployment" "$_cluster" "$_env_file"
    _env_file="$(apps_mongodb_env_path)"
    apps_mongodb_env_save "$_deployment" "$_cluster" "$_env_file"
    _env_file="$(apps_nats_env_path)"
    apps_nats_env_save "$_deployment" "$_cluster" "$_env_file"
    _env_file="$(apps_mongo_gui_env_path)"
    apps_mongo_gui_env_save "$_deployment" "$_cluster" "$_env_file"
    _env_file="$(apps_kyso_api_env_path)"
    apps_kyso_api_env_save "$_deployment" "$_cluster" "$_env_file"
    _env_file="$(apps_kyso_front_env_path)"
    apps_kyso_front_env_save "$_deployment" "$_cluster" "$_env_file"
    _env_file="$(apps_kyso_scs_env_path)"
    apps_kyso_scs_env_save "$_deployment" "$_cluster" "$_env_file"
    _env_file="$(apps_activity_feed_consumer_env_path)"
    apps_activity_feed_consumer_env_save "$_deployment" "$_cluster" "$_env_file"
    _env_file="$(apps_notification_consumer_env_path)"
    apps_notification_consumer_env_save "$_deployment" "$_cluster" "$_env_file"
    _env_file="$(apps_slack_notifications_consumer_env_path)"
    apps_slack_notifications_consumer_env_save "$_deployment" "$_cluster" \
      "$_env_file"
    _env_file="$(apps_onlyoffice_ds_env_path)"
    apps_onlyoffice_ds_env_save "$_deployment" "$_cluster" "$_env_file"
    _env_file="$(apps_imagebox_env_path)"
    apps_imagebox_env_save "$_deployment" "$_cluster" "$_env_file"
    rm -f "$DEPLOYMENT_CONFIG"
  else
    echo "No '$DEPLOYMENT_CONFIG' found, nothing to migrate!"
    exit 1
  fi
}

apps_print_variables() {
  apps_common_print_variables
  apps_elasticsearch_print_variables
  apps_mongodb_print_variables
  apps_nats_print_variables
  apps_mongo_gui_print_variables
  apps_kyso_api_print_variables
  apps_kyso_front_print_variables
  apps_kyso_scs_print_variables
  apps_activity_feed_consumer_print_variables
  apps_notification_consumer_print_variables
  apps_slack_notifications_consumer_print_variables
  apps_onlyoffice_ds_print_variables
  apps_imagebox_print_variables
}

apps_print_conf_path() {
  _deployment="$1"
  _cluster="$2"
  apps_export_variables "$_deployment" "$_cluster"
  echo "$DEPLOY_ENVS_DIR"
}

apps_update_variables() {
  _deployment="$1"
  _cluster="$2"
  apps_export_variables "$_deployment" "$_cluster"
  header_with_note "Configuring kyso deployment"
  apps_common_env_update
  footer
  apps_elasticsearch_env_update
  footer
  apps_mongodb_env_update
  footer
  apps_nats_env_update
  footer
  apps_mongo_gui_env_update
  footer
  apps_kyso_api_env_update
  footer
  apps_kyso_front_env_update
  footer
  apps_kyso_scs_env_update
  footer
  apps_activity_feed_consumer_env_update
  footer
  apps_notification_consumer_env_update
  footer
  apps_slack_notifications_consumer_env_update
  footer
  apps_onlyoffice_ds_env_update
  footer
  apps_imagebox_env_update
}

apps_config_command() {
  _command="$1"
  _deployment="$2"
  _cluster="$3"
  case "$_command" in
  migrate) apps_migrate_variables "$_deployment" "$_cluster" ;;
  path) apps_print_conf_path "$_deployment" "$_cluster" ;;
  show) apps_print_variables "$_deployment" "$_cluster" | grep -v "^#" ;;
  settings) apps_kyso_update_api_settings "$_deployment" "$_cluster" ;;
  settings-csv) apps_kyso_print_api_settings "$_deployment" "$_cluster" ;;
  update) apps_update_variables "$_deployment" "$_cluster" ;;
  *)
    echo "Unknown config subcommand '$_command'"
    exit 1
    ;;
  esac
}

apps_config_command_list() {
  echo "migrate path settings settings-csv show update"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
