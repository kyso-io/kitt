#!/bin/sh
# ----
# File:        addons.sh
# Description: Functions to install and remove addons from k8s clusters
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022-2023 Sergio Talens-Oliag <sto@kyso.io>
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
  # shellcheck source=./addons/ebs.sh
  if [ -f "$INCL_DIR/addons/ebs.sh" ]; then
    [ "$INCL_ADDONS_EBS_SH" = "1" ] || . "$INCL_DIR/addons/ebs.sh"
    ADDON_LIST="$ADDON_LIST ebs"
  fi
  # shellcheck source=./addons/efs.sh
  if [ -f "$INCL_DIR/addons/efs.sh" ]; then
    [ "$INCL_ADDONS_EFS_SH" = "1" ] || . "$INCL_DIR/addons/efs.sh"
    ADDON_LIST="$ADDON_LIST efs"
  fi
  # shellcheck source=./addons/goldilocks.sh
  if [ -f "$INCL_DIR/addons/goldilocks.sh" ]; then
    [ "$INCL_ADDONS_GOLDILOCKS_SH" = "1" ] || . "$INCL_DIR/addons/goldilocks.sh"
    ADDON_LIST="$ADDON_LIST goldilocks"
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
  # shellcheck source=./addons/metrics-server.sh
  if [ -f "$INCL_DIR/addons/metrics-server.sh" ]; then
    [ "$INCL_ADDONS_METRICS_SERVER_SH" = "1" ] ||
      . "$INCL_DIR/addons/metrics-server.sh"
    ADDON_LIST="$ADDON_LIST metrics-server"
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
  # shellcheck source=./addons/vpa.sh
  if [ -f "$INCL_DIR/addons/vpa.sh" ]; then
    [ "$INCL_ADDONS_VPA_SH" = "1" ] || . "$INCL_DIR/addons/vpa.sh"
    ADDON_LIST="$ADDON_LIST vpa"
  fi
  # shellcheck source=./addons/zabbix.sh
  if [ -f "$INCL_DIR/addons/zabbix.sh" ]; then
    [ "$INCL_ADDONS_ZABBIX_SH" = "1" ] || . "$INCL_DIR/addons/zabbix.sh"
    ADDON_LIST="$ADDON_LIST zabbix"
  fi
else
  echo "This file has to be sourced using kitt.sh"
  exit 1
fi

# ---------
# Functions
# ---------

addons_check_directories() {
  for _d in "$CLUST_ENVS_DIR" "$CLUST_HELM_DIR" "$CLUST_KUBECTL_DIR" \
    "$CLUST_NS_KUBECTL_DIR" "$CLUST_SECRETS_DIR"; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

addons_export_variables() {
  # Check if we need to run the function
  [ -z "$__addons_export_variables" ] || return 0
  _cluster="$1"
  cluster_export_variables "$_cluster"  
  addons_ingress_export_variables "$_cluster"
  addons_zabbix_export_variables "$_cluster"
  # set variable to avoid running the function twice
  __apps_export_variables="1"
}

addons_command() {
  _addon="$1"
  _command="$2"
  _cluster="$3"
  addons_check_directories
  case "$_addon" in
  dashboard) addons_dashboard_command "$_command" "$_cluster" ;;
  ebs) addons_ebs_command "$_command" "$_cluster" ;;
  efs) addons_efs_command "$_command" "$_cluster" ;;
  goldilocks) addons_goldilocks_command "$_command" "$_cluster" ;;
  ingress) addons_ingress_command "$_command" "$_cluster" ;;
  loki) addons_loki_command "$_command" "$_cluster" ;;
  minio) addons_minio_command "$_command" "$_cluster" ;;
  metrics-server) addons_metrics_server_command "$_command" "$_cluster" ;;
  prometheus) addons_prometheus_command "$_command" "$_cluster" ;;
  promtail) addons_promtail_command "$_command" "$_cluster" ;;
  velero) addons_velero_command "$_command" "$_cluster" ;;
  vpa) addons_vpa_command "$_command" "$_cluster" ;;
  zabbix) addons_zabbix_command "$_command" "$_cluster" ;;
  esac
  case "$_command" in
  status | summary) ;;
  *) cluster_git_update ;;
  esac
}

addons_list() {
  _default_order="ingress dashboard ebs efs prometheus loki promtail zabbix"
  _default_order="$_default_order minio velero metrics-server vpa goldilocks"
  [ "$1" ] && _order="$1" || _order="$_default_order"
  for _a in $_order; do
    if echo "$ADDON_LIST" | grep -q -w "$_a"; then
      echo "$_a"
    fi
  done
}

addons_command_list() {
  _addon="$1"
  case "$_addon" in
  dashboard) addons_dashboard_command_list ;;
  ebs) addons_ebs_command_list ;;
  efs) addons_efs_command_list ;;
  goldilocks) addons_goldilocks_command_list ;;
  ingress) addons_ingress_command_list ;;
  loki) addons_loki_command_list ;;
  minio) addons_minio_command_list ;;
  metrics-server) addons_metrics_server_command_list ;;
  prometheus) addons_prometheus_command_list ;;
  promtail) addons_promtail_command_list ;;
  velero) addons_velero_command_list ;;
  vpa) addons_vpa_command_list ;;
  zabbix) addons_zabbix_command_list ;;
  esac
}

addons_sets() {
  echo "all eks-all eks-backups k3d-all k3d-backups monitoring"
}

addons_set_list() {
  case "$1" in
  all) addons_list ;;
  eks-all)
    addons_list "ingress dashboard ebs efs prometheus loki promtail zabbix " \
      "velero metrics-server vpa goldilocks"
    ;;
  eks-backups) addons_list "velero" ;;
  k3d-all)
    addons_list "ingress dashboard prometheus loki promtail zabbix minio " \
      "velero vpa goldilocks"
    ;;
  k3d-backups) addons_list "minio velero" ;;
  monitoring) addons_list "prometheus loki promtail zabbix" ;;
  esac
}

addons_set_command_list() {
  _addons_set="$1"
  _addons_cmnd_list=""
  for _addon in $(addons_set_list "$_addons_set"); do
    for _addons_cmnd in $(addons_command_list "$_addon"); do
      if ! echo "$_addons_cmnd_list" | grep -q -w "${_addons_cmnd}"; then
        _addons_cmnd_list="$_addons_cmnd_list ${_addons_cmnd}"
      fi
    done
  done
  echo "${_addons_cmnd_list% }"
}

addons_set_command() {
  _addons_set="$1"
  _command="$2"
  _cluster="$3"
  for _addon in $(addons_set_list "$_addons_set"); do
    if addons_command_list "$_addon" | grep -q -w "${_command}"; then
      if [ "$_command" != "summary" ]; then
        read_bool "Execute command '$_command' for addon '$_addon'" "Yes"
      else
        READ_VALUE="true"
      fi
      if is_selected "${READ_VALUE}"; then
        addons_command "$_addon" "$_command" "$_cluster"
      fi
    fi
  done
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
