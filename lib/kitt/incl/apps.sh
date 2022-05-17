#!/bin/sh
# ----
# File:        apps.sh
# Description: Functions to configure, deploy & remove kyso applications on k8s
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022 Sergio Talens-Oliag <sto@kyso.io>
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
  [ "$INCL_KYSO_ELASTICSEARCH_SH" = "1" ] || . "$INCL_DIR/apps/elasticsearch.sh"
  # shellcheck source=./apps/mongodb.sh
  [ "$INCL_KYSO_MONGODB_SH" = "1" ] || . "$INCL_DIR/apps/mongodb.sh"
  # shellcheck source=./apps/mongo-gui.sh
  [ "$INCL_KYSO_MONGO_GUI_SH" = "1" ] || . "$INCL_DIR/apps/mongo-gui.sh"
  # shellcheck source=./apps/kyso-api.sh
  [ "$INCL_KYSO_API_SH" = "1" ] || . "$INCL_DIR/apps/kyso-api.sh"
  # shellcheck source=./apps/kyso-scs.sh
  [ "$INCL_KYSO_SCS_SH" = "1" ] || . "$INCL_DIR/apps/kyso-scs.sh"
  # shellcheck source=./apps/kyso-ui.sh
  [ "$INCL_KYSO_UI_SH" = "1" ] || . "$INCL_DIR/apps/kyso-ui.sh"
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
            apps_command "$_a" "$_command" "$_deployment" "$_cluster";
          fi
        fi
      done
    done
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
  kyso-scs)
    apps_kyso_scs_command "$_command" "$_deployment" "$_cluster"
    ;;
  kyso-ui)
    apps_kyso_ui_command "$_command" "$_deployment" "$_cluster"
    ;;
  mongodb)
    apps_mongodb_command "$_command" "$_deployment" "$_cluster"
    ;;
  mongo-gui | mongo_gui)
    apps_mongo_gui_command "$_command" "$_deployment" "$_cluster"
    ;;
  esac
}

apps_list() {
  echo "config elasticsearch mongodb mongo-gui kyso-api kyso-scs kyso-ui"
}

apps_command_list() {
  _app="$1"
  case "$_app" in
  config) apps_config_command_list ;;
  elasticsearch) apps_elasticsearch_command_list ;;
  mongodb) apps_mongodb_command_list ;;
  mongo-gui | mongo_gui) apps_mongo_gui_command_list ;;
  kyso-api) apps_kyso_api_command_list ;;
  kyso-scs) apps_kyso_scs_command_list ;;
  kyso-ui) apps_kyso_ui_command_list ;;
  esac
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
