#!/bin/sh
# ----
# File:        dam.sh
# Description: Functions to configure, deploy & remove dam applications on k8s
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2023 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_DAM_SH="1"

# --------
# Includes
# --------

if [ -d "$INCL_DIR" ]; then
  # shellcheck source=./common.sh
  [ "$INCL_COMMON_SH" = "1" ] || . "$INCL_DIR/common.sh"
  # shellcheck source=./dam/common.sh
  [ "$INCL_DAM_COMMON_SH" = "1" ] || . "$INCL_DIR/dam/common.sh"
  # shellcheck source=./dam/config.sh
  [ "$INCL_DAM_CONFIG_SH" = "1" ] || . "$INCL_DIR/dam/config.sh"
  # shellcheck source=./dam/kyso-dam.sh
  [ "$INCL_DAM_KYSO_DAM_SH" = "1" ] || . "$INCL_DIR/dam/kyso-dam.sh"
  # shellcheck source=./dam/zot.sh
  [ "$INCL_DAM_ZOT_SH" = "1" ] || . "$INCL_DIR/dam/zot.sh"
  # shellcheck source=./dam/portmaps.sh
  [ "$INCL_DAM_PORTMAPS_SH" = "1" ] || . "$INCL_DIR/dam/portmaps.sh"
else
  echo "This file has to be sourced using kitt.sh"
  exit 1
fi

# ---------
# Functions
# ---------

dam_check_directories() {
  dam_common_check_directories
}

dam_command() {
  _app="$1"
  _command="$2"
  _deployment="$3"
  _cluster="$4"
  case "$_app" in
  all)
    for _a in $(dam_list); do
      for _c in $(dam_command_list "$_a"); do
        if [ "$_c" = "$_command" ]; then
          if [ "$_command" != "summary" ]; then
            read_bool "Execute command '$_c' for app '$_a'?" "Yes"
          else
            READ_VALUE="true"
          fi
          if is_selected "${READ_VALUE}"; then
            dam_command "$_a" "$_command" "$_deployment" "$_cluster"
          fi
        fi
      done
    done
    ;;
  common)
    dam_common_command "$_command" "$_deployment" "$_cluster"
    ;;
  config)
    dam_config_command "$_command" "$_deployment" "$_cluster"
    ;;
  kyso-dam)
    dam_kyso_dam_command "$_command" "$_deployment" "$_cluster"
    ;;
  zot)
    dam_zot_command "$_command" "$_deployment" "$_cluster"
    ;;
  portmaps)
    dam_portmaps_command "$_command" "$_deployment" "$_cluster"
    ;;
  esac
  case "$_command" in
  status | summary) ;;
  *) cluster_git_update ;;
  esac
}

dam_list() {
  _apps="common config kyso-dam zot portmaps"
  echo "$_apps"
}

dam_command_list() {
  _app="$1"
  case "$_app" in
  common) dam_common_command_list ;;
  config) dam_config_command_list ;;
  kyso-dam) dam_kyso_dam_command_list ;;
  zot) dam_zot_command_list ;;
  portmaps) dam_portmaps_command_list ;;
  esac
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
