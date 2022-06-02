#!/bin/sh
# ----
# File:        ctools.sh
# Description: Functions to configure, create and destroy k8s clusters
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_CTOOLS_SH="1"

# --------
# Includes
# --------

if [ -d "$INCL_DIR" ]; then
  # shellcheck source=./common.sh
  [ "$INCL_COMMON_SH" = "1" ] || . "$INCL_DIR/common.sh"
  CTOOL_LIST=""
  # shellcheck source=./ctools/config.sh
  if [ -f "$INCL_DIR/ctools/config.sh" ]; then
    [ "$INCL_CTOOLS_CONFIG_SH" = "1" ] || . "$INCL_DIR/ctools/config.sh"
    CTOOL_LIST="$CTOOL_LIST config"
  fi
  # shellcheck source=./ctools/eks.sh
  if [ -f "$INCL_DIR/ctools/eks.sh" ]; then
    [ "$INCL_CTOOLS_EKS_SH" = "1" ] || . "$INCL_DIR/ctools/eks.sh"
    CTOOL_LIST="$CTOOL_LIST eks"
  fi
  # shellcheck source=./ctools/k3d.sh
  if [ -f "$INCL_DIR/ctools/k3d.sh" ]; then
    [ "$INCL_CTOOLS_K3D_SH" = "1" ] || . "$INCL_DIR/ctools/k3d.sh"
    CTOOL_LIST="$CTOOL_LIST k3d"
  fi
  # shellcheck source=./ctools/remove.sh
  if [ -f "$INCL_DIR/ctools/remove.sh" ]; then
    [ "$INCL_CTOOLS_REMOVE_SH" = "1" ] || . "$INCL_DIR/ctools/remove.sh"
    CTOOL_LIST="$CTOOL_LIST remove"
  fi
else
  echo "This file has to be sourced using kitt.sh"
  exit 1
fi

# ---------
# Functions
# ---------

ctool_command() {
  _ctool="$1"
  _command="$2"
  _cluster="$3"
  case "$_ctool" in
  config) ctool_config_command "$_command" "$_cluster" ;;
  eks) ctool_eks_command "$_command" "$_cluster" ;;
  k3d) ctool_k3d_command "$_command" "$_cluster" ;;
  remove) ctool_remove_command "$_command" "$_cluster" ;;
  esac
  cluster_git_update
}

ctool_list() {
  _order="config eks k3d remove"
  for _ct in $_order; do
    if echo "$CTOOL_LIST" | grep -q -w "$_ct"; then
      echo "$_ct"
    fi
  done
}

ctool_command_list() {
  _ctool="$1"
  case "$_ctool" in
  config) ctool_config_command_list ;;
  eks) ctool_eks_command_list ;;
  k3d) ctool_k3d_command_list ;;
  remove) ctool_remove_command_list ;;
  esac
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
