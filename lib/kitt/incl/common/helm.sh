#!/bin/sh
# ----
# File:        common/helm.sh
# Description: Auxiliary functions to work with helm.
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022-2023 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_COMMON_HELM_SH="1"

# --------
# Includes
# --------

if [ -d "$INCL_DIR" ]; then
  # shellcheck source=./io.sh
  [ "$INCL_COMMON_IO_SH" = "1" ] || . "$INCL_DIR/common/io.sh"
fi

# ---------
# Functions
# ---------

# Check helm repo
check_helm_repo() {
  repo_name="$1"
  repo_url="$2"
  repo_added="$(
    helm repo list -o yaml 2>/dev/null |
      sed -ne "/name: $repo_name/ {n; s%.*url: $repo_url$%yes%p; q;}"
  )" || true
  if [ "$repo_added" != "yes" ]; then
    helm repo add "$repo_name" "$repo_url"
    helm repo update "$repo_name"
  fi
}

check_helm_chart() {
  chart="$1"
  version="$2"
  if [ "$version" ]; then
    # Check if the version is available
    [ "$(helm search repo "$chart" -l -o json --version "$version")" = "[]" ] ||
      return 0
    # Maybe an update is needed, we update all just in case
    helm repo update
    # Check again
    [ "$(helm search repo "$chart" -l -o json --version "$version")" = "[]" ] ||
      return 0
  else
    # If no version is passed check first if it is a local chart
    if [ -f "$chart/Chart.yaml" ]; then
      return 0
    fi
    # Check if the chart is in our repos otherwise
    [ "$(helm search repo "$chart" -l -o json)" = "[]" ] || return 0
  fi
  # If we arrive here the chart or the chart + version is not available
  return 1
}


# Call helm upgrade
helm_upgrade() {
  _ns="$1"
  _values_yaml="$2"
  _release="$3"
  _chart="$4"
  _version="$5"
  if [ "$_version" ]; then
    if check_helm_chart "$_chart" "$_version"; then
      _version_op="--version=$_version"
    else
      echo "Version '$_version' of chart '$_chart' not found, check settings!"
      return 1
    fi
  else
    if check_helm_chart "$_chart" "$_version"; then
      _version_op=""
    else
      echo "Chart '$_chart' not found, check settings!"
      return 1
    fi
  fi
  # shellcheck disable=SC2086
  if [ "$_values_yaml" ]; then
    file_to_stdout "$_values_yaml" |
      helm upgrade --install -n "$_ns" -f - "$_release" "$_chart" $_version_op
  else
    helm upgrade --install -n "$_ns" "$_release" "$_chart" $_version_op
  fi
}

helm_history() {
  _ns="$1"
  _release="$2"
  helm history -n "$_ns" "$_release"
}

helm_rollback() {
  _ns="$1"
  _release="$2"
  _revision="$3"
  # shellcheck disable=SC2086
  helm rollback -n "$_ns" "$_release" $_revision
}

print_helm_summary() {
  _ns="$1"
  _app="$2"
  _release="$3"
  _json="$(helm -n "$_ns" list -f "$_release" -o json)" || true
  if [ "$_json" != "[]" ]; then
    _rinfo="$(echo "$_json" | jq -c '.[0]|{status},{chart},{app_version}')"
    echo "FOUND '$_app' on namespace '$_ns':"
    echo "$_rinfo" | sed -e 's/"//g;s/{//;s/}//;s/:/: /;s/^/- /'
  else
    echo "MISSING '$_app' on namespace '$_ns'!"
  fi
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
