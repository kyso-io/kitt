#!/bin/sh
# ----
# File:        ctools/remove.sh
# Description: Common functions to remove clusters used with kitt.
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022-2023 Kyso Inc.
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_CTOOLS_CONFIG_SH="1"
 
# CMND_DSC="remove: remove cluster deployments created with this tool"

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

ctool_remove_nodes() {
  [ -f "$CLUSTER_CONFIG" ] || exit 0
  cluster_export_variables "$_cluster"
  case "$CLUSTER_KIND" in
  eks) ctool_eks_remove "$_cluster" ;;
  ext) ctool_ext_remove "$_cluster" ;;
  k3d) ctool_k3d_remove "$_cluster" ;;
  *) echo "Unknown cluster kind"; exit 1 ;;
  esac
}

ctool_remove_all(){
  ctool_remove_nodes
  read_bool "Remove all configuration files in '$CLUSTER_DIR'?" "No"
  if is_selected "${READ_VALUE}"; then
    rm -rf "$CLUSTER_DIR"
  fi
}

ctool_remove_command() {
  _command="$1"
  _cluster="$2"
  case "$_command" in
    all) ctool_remove_all "$_cluster" ;;
    nodes) ctool_remove_nodes "$_cluster" ;;
    *) echo "Unknown remove subcommand '$_command'"; exit 1 ;;
  esac
}

ctool_remove_command_list() {
  echo "all nodes"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=3
