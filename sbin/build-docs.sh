#!/bin/sh
# ----
# File:        build-docs.sh
# Description: Script to build kitt documentation using asciidoctor
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2023 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# ---------
# VARIABLES
# ---------

# Relative PATH to the workdir from this script (usually . or .., empty means .)
RELPATH_TO_WORKDIR=".."

# NOTE
# ----
# The relative path means that kitt.sh is always run from the root of the
# git repo or from the user home if the script is installed in "$HOME/bin"

# Variables
DOCS="docs"
DIST="share/doc/kitt"

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

# Change to working directory (script dir + the value of RELPATH_TO_WORKDIR)
cd_to_workdir() {
  _script="$(_readlinkf_posix "$0")"
  _script_dir="${_script%/*}"
  if [ "$RELPATH_TO_WORKDIR" ]; then
    cd "$(_readlinkf_posix "$_script_dir/$RELPATH_TO_WORKDIR")"
  else
    cd "$_script_dir"
  fi
}

# ----
# MAIN
# ----

cd_to_workdir

BASE_DIR="$(pwd)"
DOCS_DIR="$BASE_DIR/$DOCS"
DIST_DIR="$BASE_DIR/$DIST"
SRC_FILES="$(cd "$DOCS_DIR"; find . -maxdepth 2 -name '*.adoc')"


# remove dist dir
if [ -d "$DIST_DIR" ]; then
  rm -rf "$DIST_DIR"
fi


# Process docs
cd "$DOCS_DIR"

# Update revnumber.txt
"$BASE_DIR/bin/kitt.sh" version |
  sed -n -e 's/^  tag:/:revnumber:/p' >revnumber.txt

# Process files
for src in $SRC_FILES; do
  echo "Building file '$src'"
  base_doc="$(basename "$src")"
  dist_dir="${DIST_DIR}/$(dirname "$src")"
  file_html="${dist_dir}/${base_doc%%.adoc}.html"
  file_pdf="${dist_dir}/${base_doc%%.adoc}.pdf"
  [ -d "$dist_dir" ] || mkdir -p "$dist_dir"
  asciidoctor -o "$file_html" "$src"
  asciidoctor-pdf -o "$file_pdf" "$src"
done

rm -f revnumber.txt

# ----
# vim: ts=2:sw=2:et:ai:sts=2
