#!/bin/sh
# ----
# File:        backup.sh
# Description: Functions to backup kyso data on k8s clusters
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_BACKUP_SH="1"

# --------
# Includes
# --------

if [ -d "$INCL_DIR" ]; then
  # shellcheck source=./common.sh
  [ "$INCL_COMMON_SH" = "1" ] || . "$INCL_DIR/common.sh"
  # shellcheck source=./apps.sh
  [ "$INCL_APPS_SH" = "1" ] || . "$INCL_DIR/apps.sh"
else
  echo "This file has to be sourced using kitt.sh"
  exit 1
fi

# ---------
# Functions
# ---------

backup_export_variables() {
  # Check if we need to run the function
  [ -z "$__backup_export_variables" ] || return 0
  _deployment="$1"
  _cluster="$2"
  apps_export_variables "$_deployment" "$_cluster"
  # set variable to avoid running the function twice
  __backup_export_variables="1"
}

backup_app_list() {
  echo "elasticsearch mongodb kyso-scs mongo-gui kyso-api kyso-ui"
}

backup_app_namespace() {
  _app="$1"
  case "$_app" in
  elasticsearch) echo "$ELASTICSEARCH_NAMESPACE" ;;
  mongodb) echo "$MONGODB_NAMESPACE" ;;
  mongo-gui) echo "$MONGO_GUI_NAMESPACE" ;;
  kyso-api) echo "$KYSO_API_NAMESPACE" ;;
  kyso-scs) echo "$KYSO_SCS_NAMESPACE" ;;
  kyso-ui) echo "$KYSO_UI_NAMESPACE" ;;
  *) echo "" ;;
  esac
}

backup_create_backup() {
  _app="$1"
  _ns=""
  for _a in $(backup_app_list); do
    if [ "$_app" = "$_a" ]; then
      _ns="$(backup_app_namespace "$_a")"
      break
    fi
  done
  if [ "$_ns" ]; then
    _bk_name="$_ns-$(date +%Y%m%d%H%M%S)"
    velero backup create "$_bk_name" \
      --include-namespaces "$_ns" \
      --include-resources '*'
  else
    echo "Unknown application"
  fi
}

backup_schedule_backup() {
  _app="$1"
  _ns=""
  _hour="0"
  _minute="0"
  # app backups are scheduled 15' apart
  for _a in $(backup_app_list); do
    _minute="$(((_minute+15)%60))"
    if [ "$_minute" -eq "0" ]; then
      _hour="$((_hour+1))"
    fi
    if [ "$_app" = "$_a" ]; then
      _ns="$(backup_app_namespace "$_a")"
      break
    fi
  done
  if [ "$_ns" ]; then
    velero create schedule "$_ns" \
      --schedule="$_minute $_hour * * *" \
      --include-namespaces "$_ns" \
      --include-resources '*'
  else
    echo "Unknown application"
  fi
}
backup_command() {
  _command="$1"
  _app="$2"
  case "$_command" in
  create)
    if [ "$_app" = "all" ]; then
      for _a in $(backup_app_list); do
        backup_create_backup "$_a"
      done
    else
      backup_create_backup "$_app"
    fi
    ;;
  restore) echo "Not implemented yet" ;;
  schedule)
    if [ "$_app" = "all" ]; then
      for _a in $(backup_app_list); do
        backup_schedule_backup "$_a"
      done
    else
      backup_schedule_backup "$_app"
    fi
    ;;
  esac
#  case "$_command" in
#    status|summary) ;;
#    *) cluster_git_update ;;
#  esac
}

backup_command_list() {
  echo "create restore schedule"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
