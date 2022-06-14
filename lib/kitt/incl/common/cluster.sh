#!/bin/sh
# ----
# File:        common/cluster.sh
# Description: Auxiliary functions to manage kitt clusters
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_COMMON_CLUSTER_SH="1"

# ---------
# Functions
# ---------

# Adjust variables related to the current cluster value
cluster_export_variables() {
  # Check if we need to run the function
  [ -z "$__cluster_export_variables" ] || return 0
  _clust_name="$1"
  # Labels
  if [ "$_clust_name" ]; then
    export CLUST_NAME="$_clust_name"
  else
    export CLUST_NAME="${KITT_CLUSTER:-$APP_DEFAULT_CLUSTER_NAME}"
  fi
  if [ -z "$CLUST_NAME" ]; then
    echo "Missing cluster name, aborting!!!"
    exit 1
  fi
  # Directories
  export APP_DATA_DIR="${APP_DATA_DIR:-$APP_DEFAULT_DATA_DIR}"
  export CERTIFICATES_DIR="$APP_DATA_DIR/certificates"
  export CLUSTERS_DIR="$APP_DATA_DIR/clusters"
  export STORAGE_DIR="$APP_DATA_DIR/storage"
  export VOLUMES_DIR="$APP_DATA_DIR/volumes"
  export CLUSTER_DIR="$CLUSTERS_DIR/$CLUST_NAME"
  export CLUST_EKS_DIR="$CLUSTER_DIR/eks"
  export CLUST_EXTSVC_DIR="$CLUSTER_DIR/extsvc"
  export CLUST_HELM_DIR="$CLUSTER_DIR/helm"
  export CLUST_K3D_DIR="$CLUSTER_DIR/k3d"
  export CLUST_KUBECTL_DIR="$CLUSTER_DIR/kubectl"
  export CLUST_NS_KUBECTL_DIR="$CLUSTER_DIR/ns-kubectl"
  export CLUST_SECRETS_DIR="$CLUSTER_DIR/secrets"
  export CLUST_STORAGE_DIR="$STORAGE_DIR/$CLUST_NAME"
  export CLUST_VOLUMES_DIR="$VOLUMES_DIR/$CLUST_NAME"
  # Files
  export CLUSTER_CONFIG="$CLUSTER_DIR/config"
  # Export CLUSTER_CONFIG variables
  export_env_file_vars "$CLUSTER_CONFIG" "CLUSTER"
  # Check if configuration is right
  CLUSTER_NAME="${CLUSTER_NAME:-$CLUST_NAME}"
  if [ "$CLUSTER_NAME" != "$CLUST_NAME" ]; then
    cat <<EOF
Cluster name '$CLUSTER_NAME' does not match '$CLUST_NAME'.

Edit the '$CLUSTER_CONFIG' file to fix it.
EOF
    exit 1
  fi
  # Try to switch to the right kubectl context
  case "$CLUSTER_KIND" in
  k3d) export KUBECTL_CONTEXT="k3d-$CLUSTER_NAME" ;;
  eks)
    KUBECTL_CONTEXT="$(kubectx | grep "@$CLUSTER_NAME\.")" || true
    export KUBECTL_CONTEXT
    ;;
  *) export KUBECTL_CONTEXT="$CLUSTER_NAME" ;;
  esac
  kubectx "$KUBECTL_CONTEXT" >/dev/null 2>/dev/null || true
  # Adjust USE_SOPS first just in case any function needs the SOPS_EXT
  if [ -z "$CLUSTER_USE_SOPS" ]; then
    CLUSTER_USE_SOPS="${APP_DEFAULT_CLUSTER_USE_SOPS}"
  fi
  export CLUSTER_USE_SOPS
  if is_selected "$CLUSTER_USE_SOPS"; then
    export SOPS_EXT="${APP_DEFAULT_SOPS_EXT}"
  else
    export SOPS_EXT=""
  fi
  # Adjust the rest of the variables
  if [ -z "$CLUSTER_DOMAIN" ]; then
    CLUSTER_DOMAIN="${APP_DEFAULT_CLUSTER_DOMAIN}"
  fi
  export CLUSTER_DOMAIN
  if [ -z "$CLUSTER_DATA_IN_GIT" ]; then
    CLUSTER_DATA_IN_GIT="${APP_DEFAULT_CLUSTER_DATA_IN_GIT}"
  fi
  export CLUSTER_DATA_IN_GIT
  if [ -z "$CLUSTER_INGRESS_REPLICAS" ]; then
    CLUSTER_INGRESS_REPLICAS="${APP_DEFAULT_CLUSTER_INGRESS_REPLICAS}"
  fi
  export CLUSTER_INGRESS_REPLICAS
  if [ -z "$CLUSTER_FORCE_SSL_REDIRECT" ]; then
    CLUSTER_FORCE_SSL_REDIRECT="${APP_DEFAULT_CLUSTER_FORCE_SSL_REDIRECT}"
  fi
  export CLUSTER_FORCE_SSL_REDIRECT
  if [ -z "$CLUSTER_PULL_SECRETS_IN_NS" ]; then
    CLUSTER_PULL_SECRETS_IN_NS="${APP_DEFAULT_CLUSTER_PULL_SECRETS_IN_NS}"
  fi
  export CLUSTER_PULL_SECRETS_IN_NS
  if [ -z "$CLUSTER_PULL_SECRETS_NAME" ]; then
    CLUSTER_PULL_SECRETS_NAME="${APP_DEFAULT_CLUSTER_PULL_SECRETS_NAME}"
  fi
  export CLUSTER_PULL_SECRETS_NAME
  if [ -z "$CLUSTER_USE_BASIC_AUTH" ]; then
    CLUSTER_USE_BASIC_AUTH="${APP_DEFAULT_CLUSTER_USE_BASIC_AUTH}"
  fi
  export CLUSTER_USE_BASIC_AUTH
  if [ -z "$CLUSTER_USE_LOCAL_STORAGE" ]; then
    CLUSTER_USE_LOCAL_STORAGE="${APP_DEFAULT_CLUSTER_USE_LOCAL_STORAGE}"
  fi
  export CLUSTER_USE_LOCAL_STORAGE
  if [ -z "$CLUSTER_USE_SOPS" ]; then
    CLUSTER_USE_SOPS="${APP_DEFAULT_CLUSTER_USE_SOPS}"
  fi
  export CLUSTER_USE_SOPS
  __cluster_export_variables="1"
}

cluster_check_directories() {
  for _d in "$APP_DATA_DIR" "$CERTIFICATES_DIR" "$CLUSTERS_DIR" "$CLUSTER_DIR" \
    "$CLUST_K3D_DIR" "$CLUST_KUBECTL_DIR" "$CLUST_NS_KUBECTL_DIR"; do
    [ -d "$_d" ] || mkdir "$_d"
  done
  if is_selected "$CLUSTER_DATA_IN_GIT" && [ ! -d "$CLUSTER_DIR/.git" ]; then
    (
      cd "$CLUSTER_DIR"
      git init -b main --quiet .
      git add .
      git commit -m 'Initial commit' --quiet
    )
  fi
}

cluster_git_update() {
  if is_selected "$CLUSTER_DATA_IN_GIT"; then
    (
      cd "$CLUSTER_DIR"
      # If the status command shows something there are changes to commit
      if [ "$(git status --porcelain)" ]; then
        git add .
        git commit -m "$APP_CALL_PATH $APP_CALL_ARGS" --quiet
      fi
    )
  fi
}

cluster_remove_directories() {
  for _d in "$CLUST_EKS_DIR" "$CLUST_EXTSVC_DIR" "$CLUST_HELM_DIR" \
    "$CLUST_K3D_DIR" "$CLUST_KUBECTL_DIR" "$CLUST_NS_KUBECTL_DIR"; do
    if [ -d "$_d" ]; then
      rm -rf "$_d"
    fi
  done
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
