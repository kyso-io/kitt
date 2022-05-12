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
  [ "$INCL_KYSO_ELASTICSEARCH_SH" = "1" ] || . "$INCL_DIR/apps/elasticsearch.sh"
  # shellcheck source=./mongodb.sh
  [ "$INCL_KYSO_MONGODB_SH" = "1" ] || . "$INCL_DIR/apps/mongodb.sh"
  # shellcheck source=./mongo-gui.sh
  [ "$INCL_KYSO_MONGO_GUI_SH" = "1" ] || . "$INCL_DIR/apps/mongo-gui.sh"
  # shellcheck source=./kyso-api.sh
  [ "$INCL_KYSO_API_SH" = "1" ] || . "$INCL_DIR/apps/kyso-api.sh"
  # shellcheck source=./kyso-scs.sh
  [ "$INCL_KYSO_SCS_SH" = "1" ] || . "$INCL_DIR/apps/kyso-scs.sh"
  # shellcheck source=./kyso-ui.sh
  [ "$INCL_KYSO_UI_SH" = "1" ] || . "$INCL_DIR/apps/kyso-ui.sh"
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
  apps_mongo_gui_export_variables "$_deployment" "$_cluster"
  apps_kyso_api_export_variables "$_deployment" "$_cluster"
  apps_kyso_scs_export_variables "$_deployment" "$_cluster"
  apps_kyso_ui_export_variables "$_deployment" "$_cluster"
  # set variable to avoid running the function twice
  __apps_export_variables="1"
}

apps_check_directories() {
  apps_common_check_directories
  apps_elasticsearch_check_directories
  apps_mongodb_check_directories
  apps_mongo_gui_check_directories
  apps_kyso_api_check_directories
  apps_kyso_scs_check_directories
  apps_kyso_ui_check_directories
}

apps_print_variables() {
  apps_common_print_variables
  apps_elasticsearch_print_variables
  apps_mongodb_print_variables
  apps_mongo_gui_print_variables
  apps_kyso_api_print_variables
  apps_kyso_scs_print_variables
  apps_kyso_ui_print_variables
}

apps_read_variables() {
  header_with_note "Configuring kyso deployment"
  apps_common_read_variables
  footer
  apps_elasticsearch_read_variables
  footer
  apps_mongodb_read_variables
  footer
  apps_mongo_gui_read_variables
  footer
  apps_kyso_api_read_variables
  footer
  apps_kyso_scs_read_variables
  footer
  apps_kyso_ui_read_variables
}

apps_edit_variables() {
  if [ "$EDITOR" ]; then
    _deployment="$1"
    _cluster="$2"
    apps_export_variables "$_deployment" "$_cluster"
    exec "$EDITOR" "$DEPLOYMENT_CONFIG"
  else
    echo "Export the EDITOR environment variable to use this subcommand"
    exit 1
  fi
}

# Configure deployment
apps_update_variables() {
  _deployment="$1"
  _cluster="$2"
  apps_export_variables "$_deployment" "$_cluster"
  header "Configuration variables"
  apps_print_variables "$_deployment" "$_cluster" | grep -v "^#"
  if [ -f "$DEPLOYMENT_CONFIG" ]; then
    footer
    read_bool "Update configuration?" "No"
  else
    READ_VALUE="Yes"
  fi
  if is_selected "${READ_VALUE}"; then
    footer
    apps_read_variables
    if [ -f "$DEPLOYMENT_CONFIG" ]; then
      footer
      read_bool "Save updated configuration?" "Yes"
    else
      READ_VALUE="Yes"
    fi
    if is_selected "${READ_VALUE}"; then
      apps_check_directories
      apps_print_variables "$_deployment" "$_cluster" |
        stdout_to_file "$DEPLOYMENT_CONFIG"
      footer
      echo "Configuration saved to '$DEPLOYMENT_CONFIG'"
      footer
    fi
  fi
}

apps_config_command() {
  _command="$1"
  _deployment="$2"
  _cluster="$3"
  case "$_command" in
    edit) apps_edit_variables "$_deployment" "$_cluster" ;;
    show) apps_print_variables "$_deployment" "$_cluster" | grep -v "^#" ;;
    update) apps_update_variables "$_deployment" "$_cluster" ;;
    *) echo "Unknown config subcommand '$_command'"; exit 1 ;;
  esac
}

apps_config_command_list() {
  echo "edit show update"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
