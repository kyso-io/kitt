#!/bin/sh
# ----
# File:        j2f/config.sh
# Description: Functions to configure json2file to process gitlab web hooks
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

# CMND_DSC="config: configure json2file to manage gitlab web hooks"

# --------
# Includes
# --------

if [ -d "$INCL_DIR" ]; then
  # shellcheck source=../common.sh
  [ "$INCL_COMMON_SH" = "1" ] || . "$INCL_DIR/common.sh"
  # shellcheck source=./common.sh
  [ "$INCL_J2F_COMMON_SH" = "1" ] || . "$INCL_DIR/j2f/common.sh"
fi

# ---------
# Functions
# ---------

j2f_config_export_variables() {
  # Check if we need to run the function
  [ -z "$__j2f_config_export_variables" ] || return 0
  j2f_common_export_variables
  j2f_spooler_export_variables
  j2f_systemd_export_variables
  j2f_webhook_export_variables
  # set variable to avoid running the function twice
  __j2f_config_export_variables="1"
}

j2f_config_check_directories() {
  j2f_common_check_directories
  j2f_spooler_check_directories
  j2f_systemd_check_directories
  j2f_webhook_check_directories
}

j2f_config_clean_directories() {
  j2f_common_clean_directories
  j2f_spooler_clean_directories
  j2f_systemd_clean_directories
  j2f_webhook_clean_directories
}

j2f_config_print_variables() {
  j2f_common_print_variables
  j2f_spooler_print_variables
  j2f_systemd_print_variables
  j2f_webhook_print_variables
}

j2f_config_read_variables() {
  header_with_note "Configuring json2file webhook processing"
  j2f_common_read_variables
  footer
#  j2f_spooler_read_variables
#  footer
  j2f_systemd_read_variables
  footer
  j2f_webhook_read_variables
}

j2f_config_edit_variables() {
  if [ "$EDITOR" ]; then
    j2f_config_export_variables
    exec "$EDITOR" "$J2F_CONFIG"
  else
    echo "Export the EDITOR environment variable to use this subcommand"
    exit 1
  fi
}

# Configure deployment
j2f_config_update_variables() {
  j2f_config_export_variables
  header "Configuration variables"
  j2f_config_print_variables | grep -v "^#"
  if [ -f "$J2F_CONFIG" ]; then
    footer
    read_bool "Update configuration?" "No"
  else
    READ_VALUE="Yes"
  fi
  if is_selected "${READ_VALUE}"; then
    footer
    j2f_config_read_variables
    if [ -f "$J2F_CONFIG" ]; then
      footer
      read_bool "Save updated configuration?" "Yes"
    else
      READ_VALUE="Yes"
    fi
    if is_selected "${READ_VALUE}"; then
      j2f_config_check_directories
      j2f_config_print_variables | stdout_to_file "$J2F_CONFIG"
      footer
      echo "Configuration saved to '$J2F_CONFIG'"
      footer
    fi
  fi
}

j2f_config_command() {
  _command="$1"
  case "$_command" in
    edit) j2f_config_edit_variables ;;
    show) j2f_config_print_variables | grep -v "^#" ;;
    update) j2f_config_update_variables ;;
    *) echo "Unknown config subcommand '$_command'"; exit 1 ;;
  esac
}

j2f_config_command_args() {
  echo "edit show update"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
