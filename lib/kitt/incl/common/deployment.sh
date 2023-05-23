#!/bin/sh
# ----
# File:        common/deployment.sh
# Description: Auxiliary functions to manage deployments in kitt
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022-2023 Kyso Inc.
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_COMMON_DEPLOYMENT_SH="1"

# --------
# Includes
# --------

if [ -d "$INCL_DIR" ]; then
  # shellcheck source=./cluster.sh
  [ "$INCL_COMMON_CLUSTER_SH" = "1" ] || . "$INCL_DIR/common/cluster.sh"
fi

# ---------
# Functions
# ---------

# Adjust variables related to the current cluster & deployment values
deployment_export_variables() {
  # Check if we need to run the function
  [ -z "$__deployment_export_variables" ] || return 0
  _deploy_name="$1"
  _clust_name="$2"
  # First adjust cluster related values
  cluster_export_variables "$_clust_name"
  # Labels
  if [ "$_deploy_name" ]; then
    export DEPLOY_NAME="$_deploy_name"
  else
    export DEPLOY_NAME="${KITT_DEPLOYMENT:-$APP_DEFAULT_DEPLOYMENT_NAME}"
  fi
  if [ -z "$DEPLOY_NAME" ]; then
    echo "Missing deployment name, aborting!!!"
    exit 1
  fi
  # Directories
  export DEPLOYMENTS_DIR="$CLUSTER_DIR/deployments"
  export DEPLOYMENT_DIR="$DEPLOYMENTS_DIR/$DEPLOY_NAME"
  export DEPLOY_ANNOTATIONS_DIR="$DEPLOYMENT_DIR/annotations"
  export DEPLOY_HELM_DIR="$DEPLOYMENT_DIR/helm"
  export DEPLOY_KUBECTL_DIR="$DEPLOYMENT_DIR/kubectl"
  export DEPLOY_PF_DIR="$DEPLOYMENT_DIR/pf"
  export DEPLOY_SECRETS_DIR="$DEPLOYMENT_DIR/secrets"
  export DEPLOY_ENVS_DIR="$DEPLOYMENT_DIR/envs"
  # Files
  export DEPLOYMENT_CONFIG="$DEPLOYMENT_DIR/config"
  # Export DEPLOYMENT_CONFIG variables
  export_env_file_vars "$DEPLOYMENT_CONFIG" "DEPLOYMENT"
  if [ -d "$DEPLOY_ENVS_DIR" ]; then
    while read -r _env_file; do
      export_env_file_vars "$_env_file" "DEPLOYMENT"
    done <<EOF
$(find "$DEPLOY_ENVS_DIR" -name '*.env')
EOF
  fi
  # Check if configuration is right
  DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-$DEPLOY_NAME}"
  if [ "$DEPLOYMENT_NAME" != "$DEPLOY_NAME" ]; then
    cat <<EOF
Deployment name '$DEPLOYMENT_NAME' does not match '$DEPLOY_NAME'.

Edit the '$DEPLOYMENT_CONFIG' file to fix it.
EOF
    exit 1
  fi
  # Adjust variable to avoid exporting variables more than once
  __deployment_export_variables="1"
}

deployment_check_directories() {
  for _d in "$DEPLOYMENTS_DIR" "$DEPLOYMENT_DIR" "$DEPLOY_ANNOTATIONS_DIR" \
    "$DEPLOY_ENVS_DIR" "$DEPLOY_HELM_DIR" "$DEPLOY_KUBECTL_DIR" \
    "$DEPLOY_PF_DIR" "$DEPLOY_SECRETS_DIR"; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

remove_deployment_directories() {
  for _d in "$DEPLOY_ANNOTATIONS_DIR" "$DEPLOY_HELM_DIR" "$DEPLOY_KUBECTL_DIR" \
    "$DEPLOY_PF_DIR" "$DEPLOY_SECRETS_DIR" "$DEPLOY_ENVS_DIR" \
    "$DEPLOYMENT_DIR" "$DEPLOYMENTS_DIR"; do
    if [ -d "$_d" ]; then
      rm -rf "$_d"
    fi
  done
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
