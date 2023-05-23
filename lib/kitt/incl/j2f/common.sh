#!/bin/sh
# ----
# File:        j2f/common.sh
# Description: Functions to manage deployments with json2file & gitlab hooks
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022-2023 Kyso Inc.
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_J2F_COMMON_SH="1"

# ---------
# Variables
# ---------

# CMND_DSC="config: configure json2file to manage deployments with gitlab hooks"

export DEFAULT_J2F_GITLAB_URL="https://gitlab.kyso.io"
export DEFAULT_J2F_REGISTRY_URI="registry.kyso.io"

# --------
# Includes
# --------

if [ -d "$INCL_DIR" ]; then
  # shellcheck source=../common.sh
  [ "$INCL_COMMON_SH" = "1" ] || . "$INCL_DIR/common.sh"
else
  echo "This file has to be sourced using kitt.sh"
  exit 1
fi

# ---------
# Functions
# ---------

j2f_common_export_variables() {
  # Check if we need to run the function
  [ -z "$__j2f_common_export_variables" ] || return 0
  # Directories
  export APP_DATA_DIR="${APP_DATA_DIR:-$APP_DEFAULT_DATA_DIR}"
  export J2F_DIR="${APP_DATA_DIR}/j2f"
  # Files
  export J2F_CONFIG="${J2F_DIR}/config"
  # Load configuration if present
  export_env_file_vars "$J2F_CONFIG" "J2F"
  # Adjust derived variables
  [ "$J2F_GITLAB_URL" ] || export J2F_GITLAB_URL="${DEFAULT_J2F_GITLAB_URL}"
  [ "$J2F_REGISTRY_URI" ] ||
    export J2F_REGISTRY_URI="${DEFAULT_J2F_REGISTRY_URI}"
  # set variable to avoid running the function twice
  __j2f_common_export_variables="1"
}

j2f_common_check_directories() {
  for _d in "$APP_DATA_DIR" "$J2F_DIR"; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

j2f_common_clean_directories() {
  # Try to remove empty dirs
  for _d in "$J2F_DIR" "$APP_DATA_DIR"; do
    if [ -d "$_d" ]; then
      rmdir "$_d" 2>/dev/null || true
    fi
  done
}

j2f_common_read_variables() {
  header "Configuring j2f"
  read_value "Gitlab server base URL" "$J2F_GITLAB_URL"
  J2F_GITLAB_URL=${READ_VALUE}
  read_value "Docker registry base URI" "$J2F_REGISTRY_URI"
  J2F_REGISTRY_URI=${READ_VALUE}
}

j2f_common_print_variables() {
  cat <<EOF
GITLAB_URL=$J2F_GITLAB_URL
REGISTRY_URI=$J2F_REGISTRY_URI
EOF
}

j2f_common_check_tools() {
  ret=0
  apps="$*"
  if [ -z "$apps" ]; then
    apps="inotifywait json2file-go mkcert tsp uuid"
  fi
  for _app in $apps; do
    _type="$(type "$_app" 2>/dev/null)" && found="true" || found="false"
    if [ "$found" = "false" ]; then
      echo "The application '$_app' could not be found, install it to continue"
      ret=1
    fi
  done
  if [ "$ret" != "0" ]; then
    echo "Call '$APP_BASE_NAME tool pkgs' to install missing packages"
  fi
  return $ret
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
