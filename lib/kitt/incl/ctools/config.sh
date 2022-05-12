#!/bin/sh
# ----
# File:        ctools/config.sh
# Description: Common functions to configure clusters to use with kitt.
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_CTOOLS_CONFIG_SH="1"
 
# CMND_DSC="config: configure cluster deployments with this tool"

# --------
# Includes
# --------

if [ -d "$INCL_DIR" ]; then
  # shellcheck source=../common.sh
  [ "$INCL_COMMON_SH" = "1" ] || . "$INCL_DIR/common.sh"
  # shellcheck source=./eks.sh
  [ "$INCL_CTOOLS_EKS_SH" = "1" ] || . "$INCL_DIR/ctools/eks.sh"
  # shellcheck source=./ext.sh
  [ "$INCL_CTOOLS_EXT_SH" = "1" ] || . "$INCL_DIR/ctools/ext.sh"
  # shellcheck source=./k3d.sh
  [ "$INCL_CTOOLS_K3D_SH" = "1" ] || . "$INCL_DIR/ctools/k3d.sh"
fi

# ---------
# Functions
# ---------

# Edit the application configuration file
ctool_config_edit() {
  if [ "$EDITOR" ]; then
    _deployment="$1"
    _cluster="$2"
    exec "$EDITOR" "$CLUSTER_CONFIG"
  else
    echo "Export the EDITOR environment variable to use this subcommand"
    exit 1
  fi
}

ctool_config_show() {
  _cluster="$1"
  if [ -f "$CLUSTER_CONFIG" ]; then
    cluster_export_variables "$_cluster"
    _ckind="$CLUSTER_KIND"
  else
    echo "Cluster not configured, call this command with the update option"
    exit 1
  fi
  case "$_ckind" in
  eks) ctool_eks_export_variables "$_cluster" ;;
  ext) ctool_ext_export_variables "$_cluster" ;;
  k3d) ctool_k3d_export_variables "$_cluster" ;;
  *) echo "Unknown cluster kind"; exit 1 ;;
  esac
  header "Configuration variables"
  case "$_ckind" in
  eks) ctool_eks_print_variables | grep -v "^#" ;;
  ext) ctool_ext_print_variables | grep -v "^#" ;;
  k3d) ctool_k3d_print_variables | grep -v "^#" ;;
  esac
}

ctool_config_update() {
  _cluster="$1"
  if [ -f "$CLUSTER_CONFIG" ]; then
    cluster_export_variables "$_cluster"
    _ckind="$CLUSTER_KIND"
  else
    read_value "Cluster kind? (eks|ext|k3d)" "$CLUSTER_DEFAULT_CLUSTER_KIND"
    _ckind=${READ_VALUE}
  fi
  case "$_ckind" in
  eks) ctool_eks_export_variables "$_cluster" ;;
  ext) ctool_ext_export_variables "$_cluster" ;;
  k3d) ctool_k3d_export_variables "$_cluster" ;;
  *) echo "Unknown cluster kind"; exit 1 ;;
  esac
  header "Configuration variables"
  [ "$CLUSTER_KIND" ] || export CLUSTER_KIND="$_ckind"
  case "$CLUSTER_KIND" in
  eks) ctool_eks_print_variables | grep -v "^#" ;;
  ext) ctool_ext_print_variables | grep -v "^#" ;;
  k3d) ctool_k3d_print_variables | grep -v "^#" ;;
  esac
  if [ "$CLUSTER_KIND" != "$_ckind" ]; then
    footer
    cat <<EOF
Wrong cluster kind (it was '$CLUSTER_KIND' and we are using '$_ckind')!!!
EOF
    footer
    exit 1
  fi
  if [ -f "$CLUSTER_CONFIG" ]; then
    footer
    read_bool "Update configuration?" "false"
  else
    READ_VALUE="true"
  fi
  if is_selected "${READ_VALUE}"; then
    header_with_note "Configuring cluster '$CLUSTER_NAME'"
    read_value "Cluster kind? (eks|ext|k3d)" "$_ckind"
    _ckind=${READ_VALUE}
    case "$_ckind" in
    eks) ctool_eks_read_variables ;;
    ext) ctool_ext_read_variables ;;
    k3d) ctool_k3d_read_variables ;;
    *) echo "Unknown cluster kind"; exit 1 ;;
    esac
    if [ -f "$CLUSTER_CONFIG" ]; then
      read_bool "Save updated configuration?" "Yes"
    else
      READ_VALUE="Yes"
    fi
    if is_selected "${READ_VALUE}"; then
      case "$_ckind" in
      eks)
        ctool_eks_check_directories
        ctool_eks_print_variables | stdout_to_file "$CLUSTER_CONFIG"
        ;;
      ext)
        ctool_ext_check_directories
        ctool_ext_print_variables | stdout_to_file "$CLUSTER_CONFIG"
        ;;
      k3d)
        ctool_k3d_check_directories
        ctool_k3d_print_variables | stdout_to_file "$CLUSTER_CONFIG"
        ;;
      esac
      footer
      echo "Configuration saved to '$CLUSTER_CONFIG'"
      footer
    fi
  fi
  if is_selected "$CLUSTER_USE_REMOTE_REGISTRY" ||
    is_selected "$CLUSTER_PULL_SECRETS_IN_NS"; then
    update_registry_conf "$_cluster"
  fi
}

ctool_config_command() {
  _command="$1"
  _cluster="$2"
  case "$_command" in
    edit) ctool_config_edit "$_cluster" ;;
    show) ctool_config_show "$_cluster" ;;
    update) ctool_config_update "$_cluster" ;;
    *) echo "Unknown config subcommand '$_command'"; exit 1 ;;
  esac
}

ctool_config_command_list() {
  echo "edit show update"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=3
