#!/bin/sh
# ----
# File:        dam/config.sh
# Description: Functions to configure a kyso-dam deployment
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2023 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_DAM_CONFIG_SH="1"

# ---------
# Variables
# ---------

# CMND_DSC="config: configure a DAM deployment"

# --------
# Includes
# --------

if [ -d "$INCL_DIR" ]; then
  # shellcheck source=../common.sh
  [ "$INCL_COMMON_SH" = "1" ] || . "$INCL_DIR/common.sh"
  # shellcheck source=./common.sh
  [ "$INCL_DAM_COMMON_SH" = "1" ] || . "$INCL_DIR/dam/common.sh"
  # shellcheck source=./kyso-dam.sh
  [ "$INCL_DAM_KYSO_DAM_SH" = "1" ] || . "$INCL_DIR/dam/kyso-dam.sh"
  # shellcheck source=./zot.sh
  [ "$INCL_DAM_ZOT_SH" = "1" ] || . "$INCL_DIR/dam/zot.sh"
fi

# ---------
# Functions
# ---------

dam_export_variables() {
  # Check if we need to run the function
  [ -z "$__dam_export_variables" ] || return 0
  _deployment="$1"
  _cluster="$2"
  dam_common_export_variables "$_deployment" "$_cluster"
  dam_kyso_dam_export_variables "$_deployment" "$_cluster"
  dam_zot_export_variables "$_deployment" "$_cluster"
  # set variable to avoid running the function twice
  __dam_export_variables="1"
}

dam_check_directories() {
  dam_common_check_directories
  dam_kyso_dam_check_directories
  dam_zot_check_directories
}

dam_print_variables() {
  dam_common_print_variables
  dam_kyso_dam_print_variables
  dam_zot_print_variables
}

dam_print_conf_path() {
  _deployment="$1"
  _cluster="$2"
  dam_export_variables "$_deployment" "$_cluster"
  echo "$DEPLOY_ENVS_DIR"
}

dam_update_variables() {
  _deployment="$1"
  _cluster="$2"
  dam_export_variables "$_deployment" "$_cluster"
  header_with_note "Configuring DAM deployment"
  dam_common_env_update
  footer
  dam_kyso_dam_env_update
  footer
  dam_zot_env_update
}

dam_config_command() {
  _command="$1"
  _deployment="$2"
  _cluster="$3"
  case "$_command" in
  path) dam_print_conf_path "$_deployment" "$_cluster" ;;
  show) dam_print_variables "$_deployment" "$_cluster" | grep -v "^#" ;;
  update) dam_update_variables "$_deployment" "$_cluster" ;;
  *)
    echo "Unknown config subcommand '$_command'"
    exit 1
    ;;
  esac
}

dam_config_command_list() {
  echo "path show update"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
