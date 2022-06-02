#!/bin/sh
# ----
# File:        j2f.sh
# Description: Functions to manage deployments with gitlab-hooks & json2file
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_J2F_SH="1"

# ---------
# Variables
# ---------

# CMND_DSC="j2f: manage deployments with gitlab-hooks & json2file"

# --------
# Includes
# --------

if [ -d "$INCL_DIR" ]; then
  # shellcheck source=./common.sh
  [ "$INCL_COMMON_SH" = "1" ] || . "$INCL_DIR/common.sh"
  # shellcheck source=./j2f/common.sh
  [ "$INCL_J2F_COMMON_SH" = "1" ] || . "$INCL_DIR/j2f/common.sh"
  # shellcheck source=./j2f/config.sh
  [ "$INCL_J2F_CONFIG_SH" = "1" ] || . "$INCL_DIR/j2f/config.sh"
  # shellcheck source=./j2f/spooler.sh
  [ "$INCL_J2F_SPOOLER_SH" = "1" ] || . "$INCL_DIR/j2f/spooler.sh"
  # shellcheck source=./j2f/systemd.sh
  [ "$INCL_J2F_SYSTEMD_SH" = "1" ] || . "$INCL_DIR/j2f/systemd.sh"
  # shellcheck source=./j2f/webhook.sh
  [ "$INCL_J2F_WEBHOOK_SH" = "1" ] || . "$INCL_DIR/j2f/webhook.sh"
else
  echo "This file has to be sourced using kitt.sh"
  exit 1
fi

# ---------
# Functions
# ---------

j2f_check_directories() {
  j2f_common_check_directories
  j2f_config_check_directories
  j2f_spooler_check_directories
  j2f_systemd_check_directories
  j2f_webhook_check_directories
}

j2f_command() {
  _command="$1"
  shift 1
  case "$_command" in
  config) j2f_config_command "$@" ;;
  spooler) j2f_spooler_command "$@" ;;
  systemd) j2f_systemd_command "$@" ;;
  webhook) j2f_webhook_command "$@" ;;
  esac
  cluster_git_update
}

j2f_command_list() {
  echo "config spooler systemd webhook"
}

j2f_command_args() {
  _command="$1"
  case "$_command" in
  config) j2f_config_command_args ;;
  spooler) j2f_spooler_command_args ;;
  systemd) j2f_systemd_command_args ;;
  webhook) j2f_webhook_command_args ;;
  esac
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
