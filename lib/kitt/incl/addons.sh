#!/bin/sh
# ----
# File:        addons.sh
# Description: Functions to install and remove addons from k8s clusters
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_ADDONS_SH="1"

# --------
# Includes
# --------

if [ -d "$INCL_DIR" ]; then
  # shellcheck source=./common.sh
  [ "$INCL_COMMON_SH" = "1" ] || . "$INCL_DIR/common.sh"
  # Start loading addons
  ADDON_LIST=""
  # shellcheck source=./addons/dashboard.sh
  if [ -f "$INCL_DIR/addons/dashboard.sh" ]; then
    [ "$INCL_ADDONS_DASHBOARD_SH" = "1" ] || . "$INCL_DIR/addons/dashboard.sh"
    ADDON_LIST="$ADDON_LIST dashboard"
  fi
  # shellcheck source=./addons/efs.sh
  if [ -f "$INCL_DIR/addons/efs.sh" ]; then
    [ "$INCL_ADDONS_EFS_SH" = "1" ] || . "$INCL_DIR/addons/efs.sh"
    ADDON_LIST="$ADDON_LIST efs"
  fi
  # shellcheck source=./addons/ingress.sh
  if [ -f "$INCL_DIR/addons/ingress.sh" ]; then
    [ "$INCL_ADDONS_INGRESS_SH" = "1" ] || . "$INCL_DIR/addons/ingress.sh"
    ADDON_LIST="$ADDON_LIST ingress"
  fi
  # shellcheck source=./addons/loki.sh
  if [ -f "$INCL_DIR/addons/loki.sh" ]; then
    [ "$INCL_ADDONS_LOKI_SH" = "1" ] || . "$INCL_DIR/addons/loki.sh"
    ADDON_LIST="$ADDON_LIST loki"
  fi
  # shellcheck source=./addons/minio.sh
  if [ -f "$INCL_DIR/addons/minio.sh" ]; then
    [ "$INCL_ADDONS_MINIO_SH" = "1" ] || . "$INCL_DIR/addons/minio.sh"
    ADDON_LIST="$ADDON_LIST minio"
  fi
  # shellcheck source=./addons/prometheus.sh
  if [ -f "$INCL_DIR/addons/prometheus.sh" ]; then
    [ "$INCL_ADDONS_PROMETHEUS_SH" = "1" ] || . "$INCL_DIR/addons/prometheus.sh"
    ADDON_LIST="$ADDON_LIST prometheus"
  fi
  # shellcheck source=./addons/promtail.sh
  if [ -f "$INCL_DIR/addons/promtail.sh" ]; then
    [ "$INCL_ADDONS_PROMTAIL_SH" = "1" ] || . "$INCL_DIR/addons/promtail.sh"
    ADDON_LIST="$ADDON_LIST promtail"
  fi
  # shellcheck source=./addons/velero.sh
  if [ -f "$INCL_DIR/addons/velero.sh" ]; then
    [ "$INCL_ADDONS_VELERO_SH" = "1" ] || . "$INCL_DIR/addons/velero.sh"
    ADDON_LIST="$ADDON_LIST velero"
  fi
else
  echo "This file has to be sourced using kitt.sh"
  exit 1
fi

# ---------
# Functions
# ---------

check_addon_directories() {
  cluster_check_directories
  for _d in "$CLUST_HELM_DIR" "$CLUST_KUBECTL_DIR" "$CLUST_NS_KUBECTL_DIR" \
    "$CLUST_SECRETS_DIR"; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

addon_command() {
  _addon="$1"
  _command="$2"
  check_addon_directories
  case "$_addon" in
  dashboard) addon_dashboard_command "$_command" ;;
  efs) addon_efs_command "$_command" ;;
  ingress) addon_ingress_command "$_command" ;;
  loki) addon_loki_command "$_command" ;;
  minio) addon_minio_command "$_command" ;;
  prometheus) addon_prometheus_command "$_command" ;;
  promtail) addon_promtail_command "$_command" ;;
  velero) addon_velero_command "$_command" ;;
  esac
}

addon_list() {
  [ "$1" ] && _order="$1" ||
    _order="ingress dashboard efs prometheus loki promtail minio velero"
  for _a in $_order; do
    if echo "$ADDON_LIST" | grep -q -w "$_a"; then
      echo "$_a"
    fi
  done
}

addon_command_list() {
  _addon="$1"
  case "$_addon" in
  dashboard) addon_dashboard_command_list ;;
  efs) addon_efs_command_list ;;
  ingress) addon_ingress_command_list ;;
  loki) addon_loki_command_list ;;
  minio) addon_minio_command_list ;;
  prometheus) addon_prometheus_command_list ;;
  promtail) addon_promtail_command_list ;;
  velero) addon_velero_command_list ;;
  esac
}

addon_sets() {
  echo "all eks-all eks-backups k3d-all k3d-backups monitoring"
}

addon_set_list() {
  case "$1" in
  all) addon_list;;
  eks-all) addon_list "ingress dashboard efs prometheus loki promtail velero" ;;
  eks-backups) addon_list "velero" ;;
  k3d-all) addon_list "ingress dashboard prometheus loki promtail minio velero" ;;
  k3d-backups) addon_list "minio velero" ;;
  monitoring) addon_list "prometheus loki promtail" ;;
  esac
}

addon_set_command_list() {
  _addon_set="$1"
  _addon_cmnd_list=""
  for _addon in $(addon_set_list "$_addon_set"); do
    for _addon_cmnd in $(addon_command_list "$_addon"); do
      if ! echo "$_addon_cmnd_list" | grep -q -w "${_addon_cmnd}"; then
        _addon_cmnd_list="$_addon_cmnd_list ${_addon_cmnd}"
      fi
    done
  done
  echo "${_addon_cmnd_list% }"
}    

addon_set_command() {
  _addon_set="$1"
  _command="$2"
  for _addon in $(addon_set_list "$_addon_set"); do
    if addon_command_list "$_addon" | grep -q -w "${_command}"; then
      if [ "$_command" != "summary" ]; then
        read_bool "Execute command '$_command' for addon '$_addon'" "Yes"
      else
        READ_VALUE="true"
      fi
      if is_selected "${READ_VALUE}"; then
        addon_command "$_addon" "$_command"
      fi
    fi
  done
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
