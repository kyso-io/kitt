#!/bin/sh
# ----
# File:        ctools/ext.sh
# Description: Functions to configure external clusters to use with kitt.
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022-2023 Kyso Inc.
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_CTOOLS_EXT_SH="1"

# ---------
# Variables
# ---------

# CMND_DSC="ext: configure clusters not managed with this tool"

# --------
# Includes
# --------

if [ -d "$INCL_DIR" ]; then
  # shellcheck source=../common.sh
  [ "$INCL_COMMON_SH" = "1" ] || . "$INCL_DIR/common.sh"
fi

# ---------
# Functions
# ---------

ctool_ext_export_variables() {
  # Check if we need to run the function
  [ -z "$__ctool_ext_export_variables" ] || return 0
  _cluster="$1"
  cluster_export_variables "$_cluster"
  # set variable to avoid running the function twice
  __ctool_ext_export_variables="1"
}

ctool_ext_check_directories() {
  cluster_check_directories
}

ctool_ext_read_variables() {
  cluster_read_variables
}

ctool_ext_print_variables() {
  cluster_print_variables
}

ctool_ext_remove() {
  _cluster="$1"
  ctool_ext_export_variables "$_cluster"
  cluster_remove_directories
}

ctool_ext_status() {
  _cluster="$1"
  ctool_ext_export_variables "$_cluster"
  kubectl 
}

# ----
# vim: ts=2:sw=2:et:ai:sts=3
