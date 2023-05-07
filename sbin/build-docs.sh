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
# Compute DIRECTORIES
SCRIPT="$(readlink -f "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT")"
BASE_DIR_RELPATH=".."
BASE_DIR="$(readlink -f "$SCRIPT_DIR/$BASE_DIR_RELPATH")"

# Variables
DOCS_DIR="$BASE_DIR/docs"
DIST_DIR="$BASE_DIR/share/doc/kitt"

# ----
# MAIN
# ----

# remove dist dir
if [ -d "$DIST_DIR" ]; then
  rm -rf "$DIST_DIR"
fi

# get list of source files
SRC_FILES="$(cd "$DOCS_DIR"; find . -maxdepth 2 -name '*.adoc')"

if [ "$SRC_FILES" ]; then
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
fi

# ----
# vim: ts=2:sw=2:et:ai:sts=2
