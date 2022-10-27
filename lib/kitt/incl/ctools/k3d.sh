#!/bin/sh
# ----
# File:        ctools/k3d.sh
# Description: Funtions to manage k3d cluster deployments with kitt.
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_CTOOLS_K3D_SH="1"

# ---------
# Variables
# ---------

# CMND_DSC="k3d: manage k3d cluster deployments with this tool"

# K3D defaults
export APP_DEFAULT_CLUSTER_K3D_SERVERS="1"
export APP_DEFAULT_CLUSTER_K3D_WORKERS="0"
export APP_DEFAULT_CLUSTER_API_HOST="127.0.0.1"
export APP_DEFAULT_CLUSTER_API_PORT="6443"
export APP_DEFAULT_CLUSTER_LB_HOST_IP="127.0.0.1"
export APP_DEFAULT_CLUSTER_LB_HTTP_PORT="80"
export APP_DEFAULT_CLUSTER_LB_HTTPS_PORT="443"
export APP_DEFAULT_CLUSTER_FORCE_SSL_REDIRECT="true"
export APP_DEFAULT_CLUSTER_USE_LOCAL_STORAGE="true"
export APP_DEFAULT_CLUSTER_USE_LOCAL_REGISTRY="false"
export APP_DEFAULT_CLUSTER_USE_REMOTE_REGISTRY="true"

# --------
# Includes
# --------

if [ -d "$INCL_DIR" ]; then
  # shellcheck source=../common.sh
  [ "$INCL_COMMON_SH" = "1" ] || . "$INCL_DIR/common.sh"
  # shellcheck source=../tools.sh
  [ "$INCL_TOOLS_SH" = "1" ] || . "$INCL_DIR/tools.sh"
fi

# ---------
# Functions
# ---------

ctool_k3d_export_variables() {
  # Check if we need to run the function
  [ -z "$__ctool_k3d_export_variables" ] || return 0
  _cluster="$1"
  cluster_export_variables "$_cluster"
  # Variables
  [ "$CLUSTER_DOMAIN" ] || CLUSTER_DOMAIN="${APP_DEFAULT_CLUSTER_DOMAIN}"
  export CLUSTER_DOMAIN
  [ "$CLUSTER_NUM_SERVERS" ] ||
    CLUSTER_NUM_SERVERS="${APP_DEFAULT_CLUSTER_K3D_SERVERS}"
  export CLUSTER_NUM_SERVERS
  [ "$CLUSTER_NUM_WORKERS" ] ||
    CLUSTER_NUM_WORKERS="${APP_DEFAULT_CLUSTER_K3D_WORKERS}"
  export CLUSTER_NUM_WORKERS
  [ "$CLUSTER_K3S_IMAGE" ] ||
    CLUSTER_K3S_IMAGE="$(k3d config init -o - | sed -n -e 's/^image: //p')" \
      2>/dev/null
  if [ -z "$CLUSTER_K3S_IMAGE" ]; then
    echo "Empty CLUSTER_K3S_IMAGE variable, is k3d installed?"
    exit 1
  fi
  export CLUSTER_K3S_IMAGE
  [ "$CLUSTER_API_HOST" ] ||
    CLUSTER_API_HOST="${APP_DEFAULT_CLUSTER_API_HOST}"
  export CLUSTER_API_HOST
  [ "$CLUSTER_API_PORT" ] ||
    CLUSTER_API_PORT="${APP_DEFAULT_CLUSTER_API_PORT}"
  export CLUSTER_API_PORT
  [ "$CLUSTER_LB_HOST_IP" ] ||
    CLUSTER_LB_HOST_IP="${APP_DEFAULT_CLUSTER_LB_HOST_IP}"
  export CLUSTER_LB_HOST_IP
  [ "$CLUSTER_LB_HTTP_PORT" ] ||
    CLUSTER_LB_HTTP_PORT="${APP_DEFAULT_CLUSTER_LB_HTTP_PORT}"
  export CLUSTER_LB_HTTP_PORT
  [ "$CLUSTER_LB_HTTPS_PORT" ] ||
    CLUSTER_LB_HTTPS_PORT="${APP_DEFAULT_CLUSTER_LB_HTTPS_PORT}"
  export CLUSTER_LB_HTTPS_PORT
  [ "$CLUSTER_USE_LOCAL_REGISTRY" ] ||
    CLUSTER_USE_LOCAL_REGISTRY="${APP_DEFAULT_CLUSTER_USE_LOCAL_REGISTRY}"
  export CLUSTER_USE_LOCAL_REGISTRY
  [ "$CLUSTER_USE_REMOTE_REGISTRY" ] ||
    CLUSTER_USE_REMOTE_REGISTRY="${APP_DEFAULT_CLUSTER_USE_REMOTE_REGISTRY}"
  export CLUSTER_USE_REMOTE_REGISTRY
  # If we are using the remote registry in k3d we don't need to add pull
  # secrets to the namespaces
  if is_selected "$CLUSTER_USE_REMOTE_REGISTRY"; then
    export CLUSTER_PULL_SECRETS_IN_NS="false"
  fi
  # Directories
  export K3D_TMPL_DIR="$TMPL_DIR/k3d"
  # Templates
  export K3D_CONFIG_TMPL="$K3D_TMPL_DIR/config.yaml"
  # Generated files
  export K3D_CONFIG_YAML="$CLUST_K3D_DIR/config${SOPS_EXT}.yaml"
  # set variable to avoid running the function twice
  __ctool_k3d_export_variables="1"
}

ctool_k3d_check_directories() {
  cluster_check_directories
  for _d in "$CLUST_K3D_DIR" "$STORAGE_DIR" "$CLUST_STORAGE_DIR" \
    "$VOLUMES_DIR" "$CLUST_VOLUMES_DIR"; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

ctool_k3d_read_variables() {
  read_value "Cluster Kubectl Context" "${CLUSTER_KUBECTL_CONTEXT}"
  CLUSTER_KUBECTL_CONTEXT=${READ_VALUE}
  read_value "Cluster DNS Domain" "${CLUSTER_DOMAIN}"
  CLUSTER_DOMAIN=${READ_VALUE}
  read_value "Number of servers (Master + Agent)" "${CLUSTER_NUM_SERVERS}"
  CLUSTER_NUM_SERVERS=${READ_VALUE}
  read_value "Number of workers (Agents)" "${CLUSTER_NUM_WORKERS}"
  CLUSTER_NUM_WORKERS=${READ_VALUE}
  read_value "K3s Image" "${CLUSTER_K3S_IMAGE}"
  CLUSTER_K3S_IMAGE=${READ_VALUE}
  read_value "API Host" "${CLUSTER_API_HOST}"
  CLUSTER_API_HOST=${READ_VALUE}
  read_value "API Port" "${CLUSTER_API_PORT}"
  CLUSTER_API_PORT=${READ_VALUE}
  read_value "LoadBalancer Host IP" "${CLUSTER_LB_HOST_IP}"
  CLUSTER_LB_HOST_IP=${READ_VALUE}
  read_value "LoadBalancer HTTP Port" "${CLUSTER_LB_HTTP_PORT}"
  CLUSTER_LB_HTTP_PORT=${READ_VALUE}
  read_value "LoadBalancer HTTPS Port" "${CLUSTER_LB_HTTPS_PORT}"
  CLUSTER_LB_HTTPS_PORT=${READ_VALUE}
  read_bool "Keep cluster data in git" "${CLUSTER_DATA_IN_GIT}"
  CLUSTER_DATA_IN_GIT=${READ_VALUE}
  read_value "Cluster Ingress Replicas" "${CLUSTER_INGRESS_REPLICAS}"
  CLUSTER_INGRESS_REPLICAS=${READ_VALUE}
  read_bool "Force SSL redirect on ingress" "${CLUSTER_FORCE_SSL_REDIRECT}"
  CLUSTER_FORCE_SSL_REDIRECT=${READ_VALUE}
  read_bool "Use local storage" "${CLUSTER_USE_LOCAL_STORAGE}"
  CLUSTER_USE_LOCAL_STORAGE=${READ_VALUE}
  read_bool "Use local registry" "${CLUSTER_USE_LOCAL_REGISTRY}"
  CLUSTER_USE_LOCAL_REGISTRY=${READ_VALUE}
  read_bool "Use remote registry" "${CLUSTER_USE_REMOTE_REGISTRY}"
  CLUSTER_USE_REMOTE_REGISTRY=${READ_VALUE}
  if is_selected "$CLUSTER_USE_REMOTE_REGISTRY"; then
    CLUSTER_PULL_SECRETS_IN_NS="false"
  else
    read_bool "Add pull secrets to namespaces" "${CLUSTER_PULL_SECRETS_IN_NS}"
    CLUSTER_PULL_SECRETS_IN_NS=${READ_VALUE}
  fi
  read_bool "Use basic auth" "${CLUSTER_USE_BASIC_AUTH}"
  CLUSTER_USE_BASIC_AUTH=${READ_VALUE}
  read_bool "Use SOPS?" "${CLUSTER_USE_SOPS}"
  CLUSTER_USE_SOPS=${READ_VALUE}
  if is_selected "$CLUSTER_USE_SOPS"; then
    export SOPS_EXT="${APP_DEFAULT_SOPS_EXT}"
  else
    export SOPS_EXT=""
  fi
}

ctool_k3d_print_variables() {
  cat <<EOF
# KITT K3d Cluster Configuration File
# ---
# Cluster name
NAME=$CLUSTER_NAME
# Kubectl context
KUBECTL_CONTEXT=$CLUSTER_KUBECTL_CONTEXT
# Cluster kind (one of eks, ext or k3d for now)
KIND=$CLUSTER_KIND
# Public DNS domain used with the cluster ingress by default
DOMAIN=$CLUSTER_DOMAIN
# Number of server nodes (1, set to 3 if testing etcd, servers are also workers)
NUM_SERVERS=$CLUSTER_NUM_SERVERS
# Number of worker nodes (0 for development, 2 for testing (2+1 = 3 workers))
NUM_WORKERS=$CLUSTER_NUM_WORKERS
# k3s image (see https://hub.docker.com/r/rancher/k3s/tags)
K3S_IMAGE=$CLUSTER_K3S_IMAGE
# IP address used to contact the k8s API, use 127.0.0.1 for local development
# and 0.0.0.0 to be able to connect to the API from outside the docker host.
API_HOST=$CLUSTER_API_HOST
# API Port (use the default unless you have a conflict)
API_PORT=$CLUSTER_API_PORT
# Public address of the ingress server, use 127.0.0.1 for local development and
# 0.0.0.0 to be able to connect to services from from outside the docker host.
LB_HOST_IP=$CLUSTER_LB_HOST_IP
# HTTP Port (use the default unless you have a conflict)
LB_HTTP_PORT=$CLUSTER_LB_HTTP_PORT
# HTTPS Port (use the default unless you have a conflict)
LB_HTTPS_PORT=$CLUSTER_LB_HTTPS_PORT
# Number of ingress replicas
INGRESS_REPLICAS=$CLUSTER_INGRESS_REPLICAS
# Force SSL redirect on ingress
FORCE_SSL_REDIRECT=$CLUSTER_FORCE_SSL_REDIRECT
# Keep cluster data in git or not
DATA_IN_GIT=$CLUSTER_DATA_IN_GIT
# Configure k3d to use a couple of local directories for storage and volumes,
# usually only makes sense on linux hosts & allows us to use velero to backup
# volumes (we use 'local-storage' class and create directories on the host to
# be able to do backups with 'restic')
USE_LOCAL_STORAGE=$CLUSTER_USE_LOCAL_STORAGE
# Enable the k3d local registry, mainly useful for local development
USE_LOCAL_REGISTRY=$CLUSTER_USE_LOCAL_REGISTRY
# If enabled we add the private registry credentials to k3d nodes and we don't
# need to add the credentials to namespaces (in fact the setting is disabled if
# this one is enabled)
USE_REMOTE_REGISTRY=$CLUSTER_USE_REMOTE_REGISTRY
# Enable to add credentials to namespaces to pull images from a private registry
PULL_SECRETS_IN_NS=$CLUSTER_PULL_SECRETS_IN_NS
# Enable basic auth for sensible services (disable only on dev deployments)
USE_BASIC_AUTH=$CLUSTER_USE_BASIC_AUTH
# Use sops to encrypt files (needs a ~/.sops.yaml file to be useful)
USE_SOPS=$CLUSTER_USE_SOPS
EOF
}

ctool_k3d_remove_cluster() {
  _cluster="$1"
  tools_check_apps_installed "k3d"
  ctool_k3d_export_variables "$_cluster"
  if k3d cluster ls --no-headers | grep -q "^${CLUSTER_NAME} "; then
    read_bool "Remove existing cluster?" "No"
    is_selected "${READ_VALUE}" || return 1
    header "Deleting previous cluster"
    k3d cluster delete "${CLUSTER_NAME}" || true
    if [ -d "$CLUST_STORAGE_DIR" ]; then
      read_bool "Remove storage dir '$CLUST_STORAGE_DIR'?" "No"
      if is_selected "${READ_VALUE}"; then
        sudo rm -rf "$CLUST_STORAGE_DIR"
      fi
    fi
    if [ -d "$CLUST_VOLUMES_DIR" ]; then
      read_bool "Remove volumes dir '$CLUST_VOLUMES_DIR'?" "No"
      if is_selected "${READ_VALUE}"; then
        sudo rm -rf "$CLUST_VOLUMES_DIR"
      fi
    fi
    cluster_remove_directories "$_cluster"
    footer
  fi
}

# Installation related functions
ctool_k3d_install() {
  _cluster="$1"
  tools_check_apps_installed "k3d" "kubectx" "kubectl"
  ctool_k3d_export_variables "$_cluster"
  # Remove old cluster?
  ctool_k3d_remove_cluster "$_cluster"
  # Check directories (the remove command can remove them)
  ctool_k3d_check_directories
  # Compute K3D_OPTS
  K3D_OPTS=""
  # Use local registry?
  if is_selected "${CLUSTER_USE_LOCAL_REGISTRY}"; then
    ctool_k3d_reg_install || true
    K3D_OPTS="$K3D_OPTS --registry-use $K3D_REGISTRY:5000"
  fi
  # Use remote registry?
  if is_selected "${CLUSTER_USE_REMOTE_REGISTRY}"; then
    load_registry_conf
    registry_sed="s%__REGISTRY_NAME__%$REMOTE_REGISTRY_NAME%g"
    registry_sed="$registry_sed;s%__REGISTRY_URL__%$REMOTE_REGISTRY_URL%g"
    registry_sed="$registry_sed;s%__REGISTRY_USER__%$REMOTE_REGISTRY_USER%g"
    registry_sed="$registry_sed;s%__REGISTRY_PASS__%$REMOTE_REGISTRY_PASS%g"
  else
    registry_sed="/BEG: REMOTE_REGISTRY/,/END: REMOTE_REGISTRY/d"
  fi
  # Setup local storage
  if is_selected "$CLUSTER_USE_LOCAL_STORAGE"; then
    # Create the empty storage directory if missing
    [ -d "$CLUST_STORAGE_DIR" ] || mkdir "$CLUST_STORAGE_DIR"
    # Create the empty volumes directory if missing
    [ -d "$CLUST_VOLUMES_DIR" ] || mkdir "$CLUST_VOLUMES_DIR"
    # Replace the PATH
    storage_sed="s%__CLUSTER_STORAGE__%$CLUST_STORAGE_DIR%g"
    storage_sed="$storage_sed;s%__CLUSTER_VOLUMES__%$CLUST_VOLUMES_DIR%g"
  else
    # Remove USE_LOCAL_STORAGE block
    storage_sed="/BEG: USE_LOCAL_STORAGE/,/END: USE_LOCAL_STORAGE/d"
  fi
  # Create the cluster
  header "Creating K3D cluster"
  sed \
    -e "s%__CLUSTER_NAME__%$CLUSTER_NAME%g" \
    -e "s%__NUM_SERVERS__%$CLUSTER_NUM_SERVERS%g" \
    -e "s%__NUM_WORKERS__%$CLUSTER_NUM_WORKERS%g" \
    -e "s%__K3S_IMAGE__%$CLUSTER_K3S_IMAGE%g" \
    -e "s%__API_HOST__%$CLUSTER_API_HOST%g" \
    -e "s%__API_PORT__%$CLUSTER_API_PORT%g" \
    -e "$registry_sed" \
    -e "$storage_sed" \
    -e "s%__HOST_IP__%$CLUSTER_LB_HOST_IP%g" \
    -e "s%__HTTP_PORT__%$CLUSTER_LB_HTTP_PORT%g" \
    -e "s%__HTTPS_PORT__%$CLUSTER_LB_HTTPS_PORT%g" \
    -e "/^#/{d;}" \
    "$K3D_CONFIG_TMPL" | stdout_to_file "$K3D_CONFIG_YAML"
  tmp_dir="$(mktemp -d)"
  chmod 0700 "$tmp_dir"
  file_to_stdout "$K3D_CONFIG_YAML" > "$tmp_dir/k3d-config.yaml" 
  # shellcheck disable=SC2086
  k3d cluster create --config "$tmp_dir/k3d-config.yaml" $K3D_OPTS
  rm -rf "$tmp_dir"
  footer
  kubectx "$KUBECTL_CONTEXT"
  kubectl cluster-info
  footer
}

ctool_k3d_remove() {
  _cluster="$1"
  ctool_k3d_export_variables "$_cluster"
  # Remove old cluster?
  ctool_k3d_remove_cluster "$_cluster"
  # Remove configuration
  if [ -f "$K3D_CONFIG_YAML" ]; then
    rm -f "$K3D_CONFIG_YAML"
  fi
  cluster_remove_directories
}

ctool_k3d_cluster_command() {
  _cluster="$1"
  ctool_k3d_export_variables "$_cluster"
  k3d cluster "$1" "$CLUSTER_NAME"
}

# Registry related functions
ctool_k3d_export_registry_variables() {
  # Check if we need to run the function
  [ -z "$__ctool_k3d_export_registry_variables" ] || return 0
  # Variables
  [ "$CLUSTER_LOCAL_DOMAIN" ] ||
    CLUSTER_LOCAL_DOMAIN="${APP_DEFAULT_CLUSTER_LOCAL_DOMAIN}"
  export CLUSTER_LOCAL_DOMAIN
  export LO_REGISTRY="registry.$CLUSTER_LOCAL_DOMAIN"
  export K3D_REGISTRY="k3d-$LO_REGISTRY"
  # set variable to avoid running the function twice
  __ctool_k3d_export_registry_variables="1"
}

ctool_k3d_reg_install() {
  ctool_k3d_export_registry_variables
  if k3d registry ls --no-headers | grep -qsw "^$K3D_REGISTRY"; then
    echo "Registry already installed"
  else
    header "Creating k3d managed registry"
    k3d registry create "$LO_REGISTRY" --port localhost:5000
    footer
  fi
}

ctool_k3d_reg_reinstall() {
  ctool_k3d_export_registry_variables
  if k3d registry ls --no-headers | grep -qsw "^$K3D_REGISTRY"; then
    header "Removing k3d managed registry"
    k3d registry delete "$LO_REGISTRY"
  fi
  ctool_k3d_reg_install
}

ctool_k3d_reg_remove() {
  ctool_k3d_export_registry_variables
  if k3d registry ls --no-headers | grep -qsw "^$K3D_REGISTRY"; then
    header "Removing k3d managed registry"
    k3d registry delete "$LO_REGISTRY"
  else
    echo "Registry not installed"
  fi
}

ctool_k3d_command() {
  _command="$1"
  _cluster="$2"
  case "$_command" in
    install) ctool_k3d_install "$_cluster" ;;
    reg-install) ctool_k3d_reg_install ;;
    reg-reinst) ctool_k3d_reg_reinstall ;;
    reg-remove) ctool_k3d_reg_remove ;;
    remove) ctool_k3d_remove "$_cluster" ;;
    start) ctool_k3d_cluster_command "start" "$_cluster";;
    status) ctool_k3d_cluster_command "list" "$_cluster" 2>/dev/null ||
      echo "Cluster '$CLUSTER_NAME' not found!" ;;
    stop) ctool_k3d_cluster_command "stop" "$_cluster" ;;
    *) echo "Unknown k3d subcommand '$1'"; exit 1 ;;
  esac
}

ctool_k3d_command_list() {
  _command_list="install remove reg-install reg-reinst reg-remove"
  _command_list="$_command_list start status stop"
  echo "$_command_list"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
