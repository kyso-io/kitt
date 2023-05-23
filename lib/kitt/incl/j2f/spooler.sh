#!/bin/sh
# ----
# File:        j2f/spooler.sh
# Description: Functions to queue calls to the webhook command for json files
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022-2023 Kyso Inc.
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_J2F_SPOOLER_SH="1"

# ---------
# Variables
# ---------

# CMND_DSC="spooler: queue calls to 'j2f webhook' for files saved by json2file"

# ---------
# Functions
# ---------

j2f_spooler_export_variables() {
  # Check if we need to run the function
  [ -z "$__j2f_spooler_export_variables" ] || return 0
  j2f_common_export_variables
  # Compute tsp tmp dir
  export J2F_TSP_TMP_DIR="$J2F_DIR/tsp"
  # set variable to avoid running the function twice
  __j2f_spooler_export_variables="1"
}

j2f_spooler_check_directories() {
  for _d in $J2F_TSP_TMP_DIR; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

j2f_spooler_clean_directories() {
  # Try to remove empty dirs
  for _d in $J2F_TSP_TMP_DIR; do
    if [ -d "$_d" ]; then
      rmdir "$_d" 2>/dev/null || true
    fi
  done
}

j2f_spooler_read_variables() {
  :
}

j2f_spooler_print_variables() {
  :
}

j2f_spooler_queue_job() {
  echo "Queuing job to process file '$1'"
  TMPDIR="$J2F_TSP_TMP_DIR" TS_SLOTS="1" TS_MAXFINISHED="10" \
    tsp -n "$APP_REAL_PATH" j2f webhook "$1"
}

j2f_spooler_command() {
  _base_dir="$1"
  if [ ! -d "$_base_dir" ]; then
    echo "Base directory '$_base_dir' does not exist, aborting!"
    exit 1
  fi
  j2f_spooler_export_variables
  echo "Processing existing files under '$_base_dir'"
  find "$_base_dir" -type f | sort | while read -r _filename; do
    j2f_spooler_queue_job "$_filename"
  done
  # Use inotifywatch to process new files
  echo "Watching for new files under '$_base_dir'"
  # shellcheck disable=SC2046
  inotifywait -q -m -e close_write,moved_to --format "%w%f" -r "$_base_dir" |
    while read -r _filename; do
      j2f_spooler_queue_job "$_filename"
    done
}

j2f_spooler_command_args() {
  echo "BASE_DIR_TO_PROCESS"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
