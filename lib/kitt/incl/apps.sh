#!/bin/sh
# ----
# File:        apps.sh
# Description: Functions to configure, deploy & remove kyso applications on k8s
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022-2023 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_APPS_SH="1"

# --------
# Includes
# --------

if [ -d "$INCL_DIR" ]; then
  # shellcheck source=./common.sh
  [ "$INCL_COMMON_SH" = "1" ] || . "$INCL_DIR/common.sh"
  # shellcheck source=./apps/common.sh
  [ "$INCL_APPS_COMMON_SH" = "1" ] || . "$INCL_DIR/apps/common.sh"
  # shellcheck source=./apps/config.sh
  [ "$INCL_APPS_CONFIG_SH" = "1" ] || . "$INCL_DIR/apps/config.sh"
  # shellcheck source=./apps/elasticsearch.sh
  [ "$INCL_APPS_ELASTICSEARCH_SH" = "1" ] || . "$INCL_DIR/apps/elasticsearch.sh"
  # shellcheck source=./apps/mongodb.sh
  [ "$INCL_APPS_MONGODB_SH" = "1" ] || . "$INCL_DIR/apps/mongodb.sh"
  # shellcheck source=./apps/nats.sh
  [ "$INCL_APPS_NATS_SH" = "1" ] || . "$INCL_DIR/apps/nats.sh"
  # shellcheck source=./apps/mongo-gui.sh
  [ "$INCL_APPS_MONGO_GUI_SH" = "1" ] || . "$INCL_DIR/apps/mongo-gui.sh"
  # shellcheck source=./apps/kyso-api.sh
  [ "$INCL_APPS_KYSO_API_SH" = "1" ] || . "$INCL_DIR/apps/kyso-api.sh"
  # shellcheck source=./apps/kyso-front.sh
  [ "$INCL_APPS_KYSO_FRONT_SH" = "1" ] || . "$INCL_DIR/apps/kyso-front.sh"
  # shellcheck source=./apps/kyso-scs.sh
  [ "$INCL_APPS_KYSO_SCS_SH" = "1" ] || . "$INCL_DIR/apps/kyso-scs.sh"
  # shellcheck source=./apps/activity-feed-consumer.sh
  [ "$INCL_APPS_ACTIVITY_FEED_CONSUMER_SH" = "1" ] ||
    . "$INCL_DIR/apps/activity-feed-consumer.sh"
  # shellcheck source=./apps/notification-consumer.sh
  [ "$INCL_APPS_NOTIFICATION_CONSUMER_SH" = "1" ] ||
    . "$INCL_DIR/apps/notification-consumer.sh"
  # shellcheck source=./apps/slack-notifications-consumer.sh
  [ "$INCL_APPS_SLACK_NOTIFICATIONS_CONSUMER_SH" = "1" ] ||
    . "$INCL_DIR/apps/slack-notifications-consumer.sh"
  # shellcheck source=./apps/teams-notification-consumer.sh
  [ "$INCL_APPS_TEAMS_NOTIFICATION_CONSUMER_SH" = "1" ] ||
    . "$INCL_DIR/apps/teams-notification-consumer.sh"
  # shellcheck source=./apps/file-metadata-postprocess-consumer.sh
  [ "$INCL_APPS_FILE_METADATA_POSTPROCESS_CONSUMER_SH" = "1" ] ||
    . "$INCL_DIR/apps/file-metadata-postprocess-consumer.sh"
  # shellcheck source=./apps/onlyoffice-ds.sh
  [ "$INCL_APPS_ONLYOFFICE_DS_SH" = "1" ] || . "$INCL_DIR/apps/onlyoffice-ds.sh"
  # shellcheck source=./apps/imagebox.sh
  [ "$INCL_APPS_IMAGEBOX_SH" = "1" ] || . "$INCL_DIR/apps/imagebox.sh"
  # shellcheck source=./apps/kyso-nbdime.sh
  [ "$INCL_APPS_KYSO_NBDIME_SH" = "1" ] || . "$INCL_DIR/apps/kyso-nbdime.sh"
  # shellcheck source=./apps/portmaps.sh
  [ "$INCL_APPS_PORTMAPS_SH" = "1" ] || . "$INCL_DIR/apps/portmaps.sh"
else
  echo "This file has to be sourced using kitt.sh"
  exit 1
fi

# ---------
# Functions
# ---------

apps_check_directories() {
  apps_common_check_directories
}

apps_command() {
  _app="$1"
  _command="$2"
  _deployment="$3"
  _cluster="$4"
  case "$_app" in
  all)
    for _a in $(apps_list); do
      for _c in $(apps_command_list "$_a"); do
        if [ "$_c" = "$_command" ]; then
          if [ "$_command" != "summary" ]; then
            read_bool "Execute command '$_c' for app '$_a'?" "Yes"
          else
            READ_VALUE="true"
          fi
          if is_selected "${READ_VALUE}"; then
            apps_command "$_a" "$_command" "$_deployment" "$_cluster"
          fi
        fi
      done
    done
    ;;
  common)
    apps_common_command "$_command" "$_deployment" "$_cluster"
    ;;
  config)
    apps_config_command "$_command" "$_deployment" "$_cluster"
    ;;
  elasticsearch)
    apps_elasticsearch_command "$_command" "$_deployment" "$_cluster"
    ;;
  kyso-api)
    apps_kyso_api_command "$_command" "$_deployment" "$_cluster"
    ;;
  kyso-front)
    apps_kyso_front_command "$_command" "$_deployment" "$_cluster"
    ;;
  kyso-scs)
    apps_kyso_scs_command "$_command" "$_deployment" "$_cluster"
    ;;
  mongodb)
    apps_mongodb_command "$_command" "$_deployment" "$_cluster"
    ;;
  mongo-gui | mongo_gui)
    apps_mongo_gui_command "$_command" "$_deployment" "$_cluster"
    ;;
  nats)
    apps_nats_command "$_command" "$_deployment" "$_cluster"
    ;;
  activity-feed-consumer)
    apps_activity_feed_consumer_command "$_command" "$_deployment" "$_cluster"
    ;;
  notification-consumer)
    apps_notification_consumer_command "$_command" "$_deployment" "$_cluster"
    ;;
  slack-notifications-consumer)
    apps_slack_notifications_consumer_command "$_command" "$_deployment" \
      "$_cluster"
    ;;
  teams-notification-consumer)
    apps_teams_notification_consumer_command "$_command" "$_deployment" \
      "$_cluster"
    ;;
  onlyoffice-ds | onlyoffice_ds)
    apps_onlyoffice_ds_command "$_command" "$_deployment" "$_cluster"
    ;;
  imagebox)
    apps_imagebox_command "$_command" "$_deployment" "$_cluster"
    ;;
  kyso-nbdime)
    apps_kyso_nbdime_command "$_command" "$_deployment" "$_cluster"
    ;;
  portmaps)
    apps_portmaps_command "$_command" "$_deployment" "$_cluster"
    ;;
  esac
  case "$_command" in
  status | summary) ;;
  *) cluster_git_update ;;
  esac
}

apps_list() {
  _apps="common config elasticsearch mongodb nats mongo-gui"
  _apps="$_apps kyso-api kyso-front kyso-scs"
  _apps="$_apps activity-feed-consumer notification-consumer"
  _apps="$_apps slack-notifications-consumer"
  _apps="$_apps teams-notification-consumer"
  _apps="$_apps onlyoffice-ds imagebox kyso-nbdime portmaps"
  echo "$_apps"
}

apps_command_list() {
  _app="$1"
  case "$_app" in
  common) apps_common_command_list ;;
  config) apps_config_command_list ;;
  elasticsearch) apps_elasticsearch_command_list ;;
  mongodb) apps_mongodb_command_list ;;
  nats) apps_nats_command_list ;;
  mongo-gui | mongo_gui) apps_mongo_gui_command_list ;;
  kyso-api) apps_kyso_api_command_list ;;
  kyso-front) apps_kyso_front_command_list ;;
  kyso-scs) apps_kyso_scs_command_list ;;
  activity-feed-consumer) apps_activity_feed_consumer_command_list ;;
  notification-consumer) apps_notification_consumer_command_list ;;
  slack-notifications-consumer)
    apps_slack_notifications_consumer_command_list
    ;;
  teams-notification-consumer)
    apps_teams_notification_consumer_command_list
    ;;
  onlyoffice-ds | onlyoffice_ds) apps_onlyoffice_ds_command_list ;;
  imagebox) apps_imagebox_command_list ;;
  kyso-nbdime) apps_kyso_nbdime_command_list ;;
  portmaps) apps_portmaps_command_list ;;
  esac
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
