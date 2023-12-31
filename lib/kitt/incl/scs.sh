#!/bin/sh
# ----
# File:        scs.sh
# Description: Functions to dump and restore the scs filesystem
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022-2023 Kyso Inc.
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

# FIXME: use a configuration file to get the token for the right user
scs_reindex() {
  _suffix="$1"
  _user="${2:-baby_yoda}"
  _hostname="$(echo "$DEPLOYMENT_HOSTNAMES" | head -1)"
  _api_base="https://${_hostname}/api/v1"
  _user_data="\"email\":\"lo+$_user@dev.kyso.io\",\"password\":\"n0tiene\""
  _user_data="$_user_data,\"provider\":\"kyso\""
  _auth_json="$(
    curl -s -X 'POST' "${_api_base}/auth/login" \
      -H 'accept: application/json' \
      -H 'Content-Type: application/json' \
      -d "{$_user_data}"
  )"
  _token="$(echo "$_auth_json" | jq -r '.data')"
  _output="$(
    curl -s -X 'GET' \
      "${_api_base}/search/reindex${_suffix}?pathToIndex=%2Fsftp%2Fdata%2Fscs" \
      -H 'accept: application/json' \
      -H "Authorization: Bearer $_token"
  )"
  echo "reindex call output: '$_output'"
}

scs_command() {
  _command="$1"
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
  case "$_command" in
  dump)
    if [ "$_arg" ]; then
      _cmnd="cd /sftp/data && tar cf - ./"
      _fdir="stdout"
      _file="$_arg"
    fi
    ;;
  reindex) scs_reindex "" "$_arg"; exit 0 ;;
  reindex-reports) scs_reindex "-reports" "$_arg"; exit 0 ;;
  reindex-comments) scs_reindex "-comments" "$_arg"; exit 0 ;;
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
        -i -- /bin/sh -c "$_cmnd" <"$_file"
    else
      echo "Missing tar file '$_file', aborting"
      return 1
    fi
  fi
#  case "$_command" in
#    status|summary) ;;
#    *) cluster_git_update ;;
#  esac
}

scs_command_list() {
  cat <<EOF
dump: Dump the scs filesystem to the passed file
reindex: Reindex all the scs contents
reindex-comments: Reindex the scs comments contents
reindex-reports: Reindex the scs reports contents
restore: Restore the scs filesystem from the passed file
EOF
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
