#!/bin/sh
# ----
# File:        kitt.sh
# Description: Orchestration script to deploy and manage kyso instances.
#              Includes subcommands to deploy k3d clusters, applications on k8s
#              clusters, run programs using containers, etc.
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022-2023 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Relative PATH to the basedir from this script (empty means .)
RELPATH_TO_BASEDIR=".."

# Application name
APP_NAME="kitt"

# ---------
# FUNCTIONS
# ---------

# POSIX compliant version of readlinkf (MacOS does not have coreutils) copied
# from https://github.com/ko1nksm/readlinkf/blob/master/readlinkf.sh
readlinkf_posix() {
  [ "${1:-}" ] || return 1
  max_symlinks=40
  CDPATH='' # to avoid changing to an unexpected directory
  target=$1
  [ -e "${target%/}" ] || target=${1%"${1##*[!/]}"} # trim trailing slashes
  [ -d "${target:-/}" ] && target="$target/"
  cd -P . 2>/dev/null || return 1
  while [ "$max_symlinks" -ge 0 ] && max_symlinks=$((max_symlinks - 1)); do
    if [ ! "$target" = "${target%/*}" ]; then
      case $target in
      /*) cd -P "${target%/*}/" 2>/dev/null || break ;;
      *) cd -P "./${target%/*}" 2>/dev/null || break ;;
      esac
      target=${target##*/}
    fi
    if [ ! -L "$target" ]; then
      target="${PWD%/}${target:+/}${target}"
      printf '%s\n' "${target:-/}"
      return 0
    fi
    # `ls -dl` format: "%s %u %s %s %u %s %s -> %s\n",
    #   <file mode>, <number of links>, <owner name>, <group name>,
    #   <size>, <date and time>, <pathname of link>, <contents of link>
    # https://pubs.opengroup.org/onlinepubs/9699919799/utilities/ls.html
    link=$(ls -dl -- "$target" 2>/dev/null) || break
    target=${link#*" $target -> "}
  done
  return 1
}

# Print base directory (script dir + the value of RELPATH_TO_BASEDIR)
print_basedir() {
  _script="$(readlinkf_posix "$0")"
  _script_dir="${_script%/*}"
  if [ "$RELPATH_TO_BASEDIR" ]; then
    (cd "$(readlinkf_posix "$_script_dir/$RELPATH_TO_BASEDIR")"; pwd)
  else
    (cd "$_script_dir"; pwd)
  fi
}

# Setup application directories
setup_app_dirs() {
  # Compute base directory
  BASE_DIR="$(print_basedir)"
  export BASE_DIR
  # Set paths for the directories
  export LIB_DIR="$BASE_DIR/lib/$APP_NAME"
  export CHARTS_DIR="$LIB_DIR/charts"
  export CMND_DIR="$LIB_DIR/cmnd"
  export INCL_DIR="$LIB_DIR/incl"
  export TMPL_DIR="$LIB_DIR/tmpl"
  _missing_dirs=""
  for _dir in "$LIB_DIR" "$CMND_DIR" "$INCL_DIR"; do
    [ -d "$_dir" ] || _missing_dirs="$_missing_dirs '$_dir'"
  done
  if [ "$_missing_dirs" ]; then
    echo "Missing dirs:$_missing_dirs"
    return 1
  fi
}

list_commands() {
  find "$CMND_DIR" -maxdepth 1 -type f -executable | while read -r _cmnd; do
    sed -ne "s/CMND_DSC=\"*\(.*\)\" *$/\1/p" "$_cmnd"
  done | sort
}

# Usage function
usage() {
  ret="$1"
  cat <<EOF
KITT (Kyso Internal Tool of Tools).

Usage:

  $APP_BASE_NAME [--debug] COMMAND {ARGS}

Where COMMAND can be one of:

$(list_commands | sed -e 's/^/- /')

Pass the COMMAND without ARGS to print help about it.
EOF
  return "$ret"
}

# ----
# MAIN
# ----

export APP_CALL_PATH="$0"
export APP_CALL_ARGS="$*"
APP_BASE_NAME="$(basename "$APP_CALL_PATH")"
export APP_BASE_NAME
APP_REAL_PATH="$(readlinkf_posix "$APP_CALL_PATH")"
export APP_REAL_PATH

# Check that the required directories exist & export their paths
setup_app_dirs

# Load defaults and configuration related functions
if [ -f "$INCL_DIR/config.sh" ]; then
  # shellcheck source=../lib/kitt/incl/config.sh
  . "$INCL_DIR/config.sh"
  # Load the user defined application variables
  config_app_load_variables
fi

if [ "$1" = "--debug" ]; then
  EXEC_CMND="exec sh -x"
  shift 1
else
  EXEC_CMND="exec sh"
fi

# Run command
CMND="$CMND_DIR/$1"
if [ -f "$CMND" ] && [ -x "$CMND" ]; then
  shift 1
  $EXEC_CMND "$CMND" "$@"
else
  usage 0
fi

# ----
# vim: ts=2:sw=2:et:ai:sts=2
