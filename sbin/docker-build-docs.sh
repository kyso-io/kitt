#!/bin/sh
# ----
# File:        docker-build-docs.sh
# Description: Script to build kitt docs with a container.
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022-2023 Kyso Inc.
# ----

set -e

# ---------
# VARIABLES
# ---------

RELPATH_TO_WORKDIR=".."
BUILD_SCRIPT="sbin/build-docs.sh"
IMAGE_NAME="${IMAGE_NAME:-registry.kyso.io/docker/docker-asciidoctor}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
IMAGE_URI="$IMAGE_NAME:$IMAGE_TAG"

# ---------
# FUNCTIONS
# ---------

# POSIX compliant version of readlinkf (MacOS does not have coreutils) copied
# from https://github.com/ko1nksm/readlinkf/blob/master/readlinkf.sh
_readlinkf_posix() {
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

# ----
# MAIN
# ----

_script="$(_readlinkf_posix "$0")"
_script_dir="${_script%/*}"
_base_dir="$(_readlinkf_posix "$_script_dir/$RELPATH_TO_WORKDIR")"

docker run --rm --user "$(id -u):$(id -g)" --volume "${_base_dir}:/documents" \
  "$IMAGE_URI" "$BUILD_SCRIPT"

# ----
# vim: ts=2:sw=2:et:ai:sts=2
