#!/bin/sh
# ----
# File:        scs.sh
# Description: Functions to dump and restore the scs filesystem
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_SCS_SH="1"

# --------
# Includes
# --------

if [ -d "$INCL_DIR" ]; then
  # shellcheck source=./common.sh
  [ "$INCL_COMMON_SH" = "1" ] || . "$INCL_DIR/common.sh"
  # shellcheck source=./apps/kyso-scs.sh
  [ "$INCL_APPS_KYSO_SCS_SH" = "1" ] || . "$INCL_DIR/apps/kyso-scs.sh"
else
  echo "This file has to be sourced using kitt.sh"
  exit 1
fi

# ---------
# Functions
# ---------

scs_command() {
  _cmnd="$1"
  _arg="$2"
  _deployment="$3"
  _cluster="$4"
  apps_kyso_scs_export_variables "$_deployment" "$_cluster"
  if ! find_namespace "$KYSO_SCS_NAMESPACE"; then
    echo "Kyso SCS Namespace '$KYSO_SCS_NAMESPACE' not found, can't run command"
    return 1
  fi
  _cmnd=""
  _file=""
  case "$1" in
  dump)
    if [ "$_arg" ]; then
      _cmnd="cd /sftp/data && tar cf - ./"
      _fdir="stdout"
      _file="$_arg"
    fi
    ;;
  restore)
    if [ "$_arg" ]; then
      _cmnd="cd /sftp/data && tar xf -"
      _fdir="stdin"
      _file="$_arg"
    fi
    ;;
  esac
  _pod_name="kyso-scs-0"
  _container_name="mysecureshell"
  if [ "$_fdir" = "stdout" ]; then
    kubectl exec -n "$KYSO_SCS_NAMESPACE" "$_pod_name" -c "$_container_name" \
      -- /bin/sh -c "$_cmnd" >"$_file"
  else
    if [ -f "$_file" ]; then
      kubectl exec -n "$KYSO_SCS_NAMESPACE" "$_pod_name" -c "$_container_name" \
        -- /bin/sh -c "$_cmnd" <"$_file"
    else
      echo "Missing tar file '$_file', aborting"
      return 1
    fi
  fi
}

scs_command_list() {
  cat <<EOF
dump: Dump the scs filesystem to the passed file
restore: Restore the scs filesystem from the passed file
EOF
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2