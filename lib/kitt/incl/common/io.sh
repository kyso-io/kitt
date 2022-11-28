#!/bin/sh
# ----
# File:        common/io.sh
# Description: Auxiliary functions for input/output processing
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_COMMON_IO_SH="1"

# Terminal related variables
if [ "$TERM" ] && type tput >/dev/null; then
  bold="$(tput bold)"
  normal="$(tput sgr0)"
else
  bold=""
  normal=""
fi
export yes_no="(${bold}Y${normal}es/${bold}N${normal}o)"

header() {
  printf "%s\n-------------------------------------\n" "${bold}${1}${normal}"
}

footer() {
  echo "-------------------------------------"
}

header_with_note() {
  header "$1"
  cat <<EOF
When reading values an empty string or spaces keep the default value.
To adjust the value to an empty string use a single - or edit the file.
EOF
  footer
}

# $1 text to show - $2 default value
read_value() {
  printf "%s [%s]: " "${1}" "${bold}${2}${normal}"
  if [ "$KITT_NONINTERACTIVE" = "true" ]; then
    READ_VALUE=""
    echo ""
  else
    read -r READ_VALUE
  fi
  if [ "${READ_VALUE}" = "" ]; then
    READ_VALUE="$2"
  elif [ "${READ_VALUE}" = "-" ]; then
    READ_VALUE=""
  fi
}

# $1 text to show - $2 default value
read_bool() {
  case "${2}" in
  y | Y | yes | Yes | YES | true | True | TRUE) _yn="Yes" ;;
  *) _yn="No" ;;
  esac
  printf "%s ${yes_no} [%s]: " "${1}" "${bold}${_yn}${normal}"
  if [ "$KITT_NONINTERACTIVE" = "true" ]; then
    READ_VALUE=""
    echo ""
  else
    read -r READ_VALUE
  fi
  case "${READ_VALUE}" in
  '') [ "$_yn" = "Yes" ] && READ_VALUE="true" || READ_VALUE="false" ;;
  y | Y | yes | Yes | YES | true | True | TRUE) READ_VALUE="true" ;;
  *) READ_VALUE="false" ;;
  esac
}

# Check if a value is set to yes/true or not
is_selected() {
  case "${1}" in
  y | Y | yes | Yes | YES | true | True | TRUE) return 0 ;;
  *) return 1 ;;
  esac
}

# Write file using sops to encrypt the file if CLUSTER_USE_SOPS is set
stdout_to_file() {
  file="$1"
  if is_selected "$CLUSTER_USE_SOPS"; then
    ext="${file##*.}"
    sops="${file%%."$ext"}"
    base="${sops%%"$SOPS_EXT"}"
    if [ "$sops" = "$base" ]; then
      cat >"$file"
    else
      case "$ext" in
      yaml | yml) ftype="yaml" ;;
      json) ftype="json" ;;
      env) ftype="dotenv" ;;
      *) ftype="binary" ;;
      esac
      sops --encrypt --input-type "$ftype" --output-type "$ftype" /dev/stdin \
        >"$file"
    fi
  else
    cat >"$file"
  fi
}

# Cat file using sops to decrypt the file if CLUSTER_USE_SOPS is set
file_to_stdout() {
  file="$1"
  if is_selected "$CLUSTER_USE_SOPS" && [ -s "$file" ]; then
    ext="${file##*.}"
    sops="${file%%."$ext"}"
    base="${sops%%"$SOPS_EXT"}"
    if [ "$sops" = "$base" ]; then
      cat "$file"
    else
      case "$ext" in
      yaml | yml) ftype="yaml" ;;
      json) ftype="json" ;;
      env) ftype="dotenv" ;;
      *) ftype="binary" ;;
      esac
      sops --decrypt --input-type "$ftype" --output-type "$ftype" "$file"
    fi
  else
    cat "$file"
  fi
}

# Export variables from file adding the prefix passed as second argument (iff
# present).
#
# The function exports variables from a file with lines of the form VAR=VALUE,
# if a line contains a '#' sign, everything starting from the character is
# removed, after removing comments trailing spaces are also removed and if the
# VALUE is between single or double quotes the quotes are removed.
#
# Before the variables are exported their names are modified adding the preffix
# plus an underscore ('_') to all of them to avoid clashes with existing
# variables.
#
# Note that the value parsing is so simple that backslashes are not interpreted
# and quotes and single quotes are only removed when the value is between them,
# but if they appear inside the characters or are not well balanced ther are
# kept.
export_env_file_vars() {
  _file="$1"
  _prefix="$2"
  [ -f "$_file" ] || return 0
  while read -r _line; do
    _line="${_line%%#*}"                       # remove comments.
    _line="${_line%"${_line##*[![:space:]]}"}" # remove trailing spaces.
    _vname="${_line%=*}"                       # get variable name.
    _value="${_line#*=}"                       # get variable value.
    if [ "$_vname" ] && [ "$_vname" != "$_value" ]; then
      # Remove single or double quotes iff they are present at the beggining and
      # end of the value (only one or the other gets removed)
      if [ "$_value" != "${_value#\'}" ]; then
        _nvalue="${_value#\'}"
        [ "$_value" = "${_nvalue%\'}" ] || _value="${_nvalue%\'}"
      elif [ "$_value" != "${_value#\"}" ]; then
        _nvalue="${_value#\"}"
        [ "$_value" = "${_nvalue%\"}" ] || _value="${_nvalue%\"}"
      fi
      if [ "${_prefix}" ]; then
        export "${_prefix}_${_vname}=$_value" # export variable
      else
        export "${_vname}=$_value" # export variable
      fi
    fi
  done <<EOF
$(file_to_stdout "$_file")
EOF
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
