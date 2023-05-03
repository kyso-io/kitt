#!/bin/sh
# ----
# File:        common/cluster.sh
# Description: Auxiliary functions to manage kitt clusters
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022-2023 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_COMMON_CLUSTER_SH="1"

# ---------
# Functions
# ---------

# Guess kubectl context name
guess_kubectl_context() {
  _kind="$1"
  _name="$2"
  case "$_kind" in
  k3d) echo "k3d-$_name" ;;
  eks) kubectx | sed -n -e "/cluster\/$_name$/ {p}" || true ;;
  *) echo "$_name" ;;
  esac
}

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
  export CLUST_ENVS_DIR="$CLUSTER_DIR/envs"
  export CLUST_EXTSVC_DIR="$CLUSTER_DIR/extsvc"
  export CLUST_HELM_DIR="$CLUSTER_DIR/helm"
  export CLUST_K3D_DIR="$CLUSTER_DIR/k3d"
  export CLUST_KUBECTL_DIR="$CLUSTER_DIR/kubectl"
  export CLUST_NS_KUBECTL_DIR="$CLUSTER_DIR/ns-kubectl"
  export CLUST_SECRETS_DIR="$CLUSTER_DIR/secrets"
  export CLUST_STORAGE_DIR="$STORAGE_DIR/$CLUST_NAME"
  export CLUST_TERRAFORM_DIR="$CLUSTER_DIR/terraform"
  export CLUST_VOLUMES_DIR="$VOLUMES_DIR/$CLUST_NAME"
  # Files
  export CLUSTER_CONFIG="$CLUSTER_DIR/config"
  # Export CLUSTER_CONFIG variables
  export_env_file_vars "$CLUSTER_CONFIG" "CLUSTER"
  if [ -d "$CLUST_ENVS_DIR" ]; then
    while read -r _env_file; do
      export_env_file_vars "$_env_file" "CLUSTER"
    done <<EOF
$(find "$CLUST_ENVS_DIR" -name '*.env')
EOF
  fi
  # Check if configuration is right
  export CLUSTER_NAME="${CLUSTER_NAME:-$CLUST_NAME}"
  if [ "$CLUSTER_NAME" != "$CLUST_NAME" ]; then
    cat <<EOF
Cluster name '$CLUSTER_NAME' does not match '$CLUST_NAME'.

Edit the '$CLUSTER_CONFIG' file to fix it.
EOF
    exit 1
  fi
  # Try to switch to the right kubectl context
  if [ "$CLUSTER_KUBECTL_CONTEXT" ]; then
    KUBECTL_CONTEXT="$CLUSTER_KUBECTL_CONTEXT"
  else
    KUBECTL_CONTEXT="$(guess_kubectl_context "$CLUSTER_KIND" "$CLUSTER_NAME")"
    export CLUSTER_KUBECTL_CONTEXT="$KUBECTL_CONTEXT"
  fi
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
  if [ -z "$CLUSTER_USE_SOPS" ]; then
    CLUSTER_USE_SOPS="${APP_DEFAULT_CLUSTER_USE_SOPS}"
  fi
  export CLUSTER_USE_SOPS
  if [ -z "$CLUSTER_MAP_KYSO_DEV_PORTS" ]; then
    CLUSTER_MAP_KYSO_DEV_PORTS="${APP_DEFAULT_CLUSTER_MAP_KYSO_DEV_PORTS}"
  fi
  export CLUSTER_MAP_KYSO_DEV_PORTS
  if [ -z "$CLUSTER_USE_LOCAL_STORAGE" ]; then
    CLUSTER_USE_LOCAL_STORAGE="${APP_DEFAULT_CLUSTER_USE_LOCAL_STORAGE}"
  fi
  export CLUSTER_USE_LOCAL_STORAGE
  __cluster_export_variables="1"
}

cluster_check_directories() {
  for _d in "$APP_DATA_DIR" "$CERTIFICATES_DIR" "$CLUSTERS_DIR" "$CLUSTER_DIR" \
    "$CLUST_KUBECTL_DIR" "$CLUST_NS_KUBECTL_DIR"; do
    [ -d "$_d" ] || mkdir "$_d"
  done
  if is_selected "$CLUSTER_DATA_IN_GIT" && [ ! -d "$CLUSTER_DIR/.git" ]; then
    _git_user_email="kitt@apps.kyso.io"
    _git_user_name="Kyso Internal Tool of Tools"
    (
      cd "$CLUSTER_DIR"
      git init --quiet .
      [ "$(git config user.email)" ] || git config user.email "$_git_user_email"
      [ "$(git config user.name)" ] || git config user.name "$_git_user_name"
      touch .gitignore
      git add .
      git commit -m 'Initial commit' --quiet
    )
  fi
}

cluster_git_update() {
  if [ -d "$CLUSTER_DIR" ] && is_selected "$CLUSTER_DATA_IN_GIT"; then
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

cluster_read_variables() {
  # Read external cluster settings
  read_value "Cluster Kubectl Context" "${CLUSTER_KUBECTL_CONTEXT}"
  CLUSTER_KUBECTL_CONTEXT=${READ_VALUE}
  read_value "Cluster DNS Domain" "${CLUSTER_DOMAIN}"
  CLUSTER_DOMAIN=${READ_VALUE}
  read_bool "Keep cluster data in git" "${CLUSTER_DATA_IN_GIT}"
  CLUSTER_DATA_IN_GIT=${READ_VALUE}
  read_bool "Force SSL redirect on ingress" "${CLUSTER_FORCE_SSL_REDIRECT}"
  CLUSTER_FORCE_SSL_REDIRECT=${READ_VALUE}
  read_value "Cluster Ingress Replicas" "${CLUSTER_INGRESS_REPLICAS}"
  CLUSTER_INGRESS_REPLICAS=${READ_VALUE}
  read_bool "Add pull secrets to namespaces" "${CLUSTER_PULL_SECRETS_IN_NS}"
  CLUSTER_PULL_SECRETS_IN_NS=${READ_VALUE}
  read_bool "Use basic auth" "${CLUSTER_USE_BASIC_AUTH}"
  CLUSTER_USE_BASIC_AUTH=${READ_VALUE}
  read_bool "Use SOPS" "${CLUSTER_USE_SOPS}"
  CLUSTER_USE_SOPS=${READ_VALUE}
  if is_selected "$CLUSTER_USE_SOPS"; then
    if [ ! -f "$SOPS_YAML" ]; then
      read_bool "File '$SOPS_YAML' not found, configure SOPS?" "true"
      CONFIGURE_SOPS=${READ_VALUE}
      if is_selected "$CONFIGURE_SOPS"; then
        if [ ! -f "$SOPS_AGE_KEYS" ]; then
          read_bool "Create '$SOPS_AGE_KEYS' file?" "true"
          CREATE_AGE_KEYS=${READ_VALUE}
          if is_selected "$CREATE_AGE_KEYS"; then
            [ -d "$SOPS_AGE_DIR" ] || mkdir -p "$SOPS_AGE_DIR"
            age-keygen -o "$SOPS_AGE_KEYS"
          fi
        fi
        if [ -f "$SOPS_AGE_KEYS" ]; then
          _age_pub_key="$(
            sed -ne 's/^# public key: //p' "$SOPS_AGE_KEYS" | head -1
          )"
          cat >"$SOPS_YAML" <<EOF
creation_rules:
- age: ${_age_pub_key}
EOF
        else
          echo "Can't autoconfigure SOPS without the '$SOPS_AGE_KEYS' file"
          return 1
        fi
      fi
    fi
    export SOPS_EXT="${APP_DEFAULT_SOPS_EXT}"
  else
    export SOPS_EXT=""
  fi
}

cluster_print_variables() {
  cat <<EOF
# KITT Cluster Configuration File
# ---
# Cluster kind (one of eks, ext or k3d for now)
KIND=$CLUSTER_KIND
# Cluster name
NAME=$CLUSTER_NAME
# Kubectl context
KUBECTL_CONTEXT=$CLUSTER_KUBECTL_CONTEXT
# Public DNS domain used with the cluster ingress by default
DOMAIN=$CLUSTER_DOMAIN
# Force SSL redirect on ingress
FORCE_SSL_REDIRECT=$CLUSTER_FORCE_SSL_REDIRECT
# Number of ingress replicas
INGRESS_REPLICAS=$CLUSTER_INGRESS_REPLICAS
# Keep cluster data in git or not
DATA_IN_GIT=$CLUSTER_DATA_IN_GIT
# Enable to add credentials to namespaces to pull images from a private registry
PULL_SECRETS_IN_NS=$CLUSTER_PULL_SECRETS_IN_NS
# Enable basic auth for sensible services (disable only on dev deployments)
USE_BASIC_AUTH=$CLUSTER_USE_BASIC_AUTH
# Use sops to encrypt files (needs a ~/.sops.yaml file to be useful)
USE_SOPS=$CLUSTER_USE_SOPS
EOF
}

cluster_remove_directories() {
  for _d in "$CLUST_EKS_DIR" "$CLUST_ENVS_DIR" "$CLUST_EXTSVC_DIR" \
    "$CLUST_HELM_DIR" "$CLUST_K3D_DIR" "$CLUST_KUBECTL_DIR" \
    "$CLUST_NS_KUBECTL_DIR" "$CLUST_TERRAFORM_DIR"; do
    if [ -d "$_d" ]; then
      rm -rf "$_d"
    fi
  done
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
