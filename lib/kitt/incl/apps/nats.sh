#!/bin/sh
# ----
# File:        apps/nats.sh
# Description: Functions to manage nats deployments for kyso on k8s
#              clusters.
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_APPS_NATS_SH="1"

# ---------
# Variables
# ---------

# CMND_DSC="nats: manage nats deployment for kyso"

# Defaults
export DEPLOYMENT_DEFAULT_NATS_IMAGE="nats:2.8.2-alpine"
export DEPLOYMENT_DEFAULT_NATSBOX_IMAGE="natsio/nats-box:0.11.0"
_image="natsio/nats-server-config-reloader:0.7.0"
export DEPLOYMENT_DEFAULT_NATS_RELOADER_IMAGE="$_image"
_image="natsio/prometheus-nats-exporter:0.9.3"
export DEPLOYMENT_DEFAULT_NATS_EXPORTER_IMAGE="$_image"
_image=""
export DEPLOYMENT_DEFAULT_NATS_REPLICAS="1"
export DEPLOYMENT_DEFAULT_NATS_STORAGE_CLASS=""
export DEPLOYMENT_DEFAULT_NATS_STORAGE_SIZE="10Gi"
export DEPLOYMENT_DEFAULT_NATS_PF_PORT=""

# Fixed values
export NATS_REPO_NAME="nats"
export NATS_REPO_URL="https://nats-io.github.io/k8s/helm/charts/"
export NATS_RELEASE="kyso-nats"
export NATS_CHART="nats/nats"
export NATS_VERSION="0.17.0"
export NATS_PV_PREFIX="$NATS_RELEASE-js-pvc-$NATS_RELEASE"

# --------
# Includes
# --------

if [ -d "$INCL_DIR" ]; then
  # shellcheck source=../common.sh
  [ "$INCL_COMMON_SH" = "1" ] || . "$INCL_DIR/common.sh"
  # shellcheck source=./common.sh
  [ "$INCL_APPS_COMMON_SH" = "1" ] || . "$INCL_DIR/apps/common.sh"
fi

# ---------
# Functions
# ---------

apps_nats_export_variables() {
  [ -z "$__apps_nats_export_variables" ] || return 0
  _deployment="$1"
  _cluster="$2"
  apps_common_export_variables "$_deployment" "$_cluster"
  # Values
  export NATS_NAMESPACE="nats-$DEPLOYMENT_NAME"
  # Directories
  export NATS_TMPL_DIR="$TMPL_DIR/apps/nats"
  export NATS_HELM_DIR="$DEPLOY_HELM_DIR/nats"
  export NATS_KUBECTL_DIR="$DEPLOY_KUBECTL_DIR/nats"
  export NATS_SECRETS_DIR="$DEPLOY_SECRETS_DIR/nats"
  export NATS_PF_DIR="$DEPLOY_PF_DIR/nats"
  # Templates
  export NATS_HELM_VALUES_TMPL="$NATS_TMPL_DIR/values.yaml"
  export NATS_PVC_TMPL="$NATS_TMPL_DIR/pvc.yaml"
  export NATS_PV_TMPL="$NATS_TMPL_DIR/pv.yaml"
  # Files
  _values_yaml="$NATS_HELM_DIR/values${SOPS_EXT}.yaml"
  export NATS_HELM_VALUES_YAML="$_values_yaml"
  export NATS_PF_OUT="$NATS_PF_DIR/kubectl.out"
  export NATS_PF_PID="$NATS_PF_DIR/kubectl.pid"
  # Use defaults for variables missing from config files
  if [ "$DEPLOYMENT_NATS_IMAGE" ]; then
    NATS_IMAGE="$DEPLOYMENT_NATS_IMAGE"
  else
    NATS_IMAGE="$DEPLOYMENT_DEFAULT_NATS_IMAGE"
  fi
  export NATS_IMAGE
  if [ "$DEPLOYMENT_NATSBOX_IMAGE" ]; then
    NATSBOX_IMAGE="$DEPLOYMENT_NATSBOX_IMAGE"
  else
    NATSBOX_IMAGE="$DEPLOYMENT_DEFAULT_NATSBOX_IMAGE"
  fi
  export NATSBOX_IMAGE
  if [ "$DEPLOYMENT_NATS_RELOADER_IMAGE" ]; then
    NATS_RELOADER_IMAGE="$DEPLOYMENT_NATS_RELOADER_IMAGE"
  else
    NATS_RELOADER_IMAGE="$DEPLOYMENT_DEFAULT_NATS_RELOADER_IMAGE"
  fi
  export NATS_RELOADER_IMAGE
  if [ "$DEPLOYMENT_NATS_EXPORTER_IMAGE" ]; then
    NATS_EXPORTER_IMAGE="$DEPLOYMENT_NATS_EXPORTER_IMAGE"
  else
    NATS_EXPORTER_IMAGE="$DEPLOYMENT_DEFAULT_NATS_EXPORTER_IMAGE"
  fi
  export NATS_EXPORTER_IMAGE
  if [ "$DEPLOYMENT_NATS_REPLICAS" ]; then
    NATS_REPLICAS="$DEPLOYMENT_NATS_REPLICAS"
  else
    NATS_REPLICAS="$DEPLOYMENT_DEFAULT_NATS_REPLICAS"
  fi
  export NATS_REPLICAS
  if [ "$DEPLOYMENT_NATS_STORAGE_CLASS" ]; then
    NATS_STORAGE_CLASS="$DEPLOYMENT_NATS_STORAGE_CLASS"
  else
    _storage_class="$DEPLOYMENT_DEFAULT_NATS_STORAGE_CLASS"
    NATS_STORAGE_CLASS="$_storage_class"
  fi
  export NATS_STORAGE_CLASS
  if [ "$DEPLOYMENT_NATS_STORAGE_SIZE" ]; then
    NATS_STORAGE_SIZE="$DEPLOYMENT_NATS_STORAGE_SIZE"
  else
    NATS_STORAGE_SIZE="$DEPLOYMENT_DEFAULT_NATS_STORAGE_SIZE"
  fi
  export NATS_STORAGE_SIZE
  if [ "$DEPLOYMENT_NATS_PF_PORT" ]; then
    NATS_PF_PORT="$DEPLOYMENT_NATS_PF_PORT"
  else
    NATS_PF_PORT="$DEPLOYMENT_DEFAULT_NATS_PF_PORT"
  fi
  export NATS_PF_PORT
  __apps_nats_export_variables="1"
}

apps_nats_check_directories() {
  apps_common_check_directories
  for _d in "$NATS_HELM_DIR" "$NATS_KUBECTL_DIR" "$NATS_SECRETS_DIR" \
    "$NATS_PF_DIR"; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

apps_nats_clean_directories() {
  # Try to remove empty dirs, except if they contain secrets
  for _d in "$NATS_HELM_DIR" "$NATS_KUBECTL_DIR" "$NATS_SECRETS_DIR" \
    "$NATS_PF_DIR"; do
    if [ -d "$_d" ]; then
      rmdir "$_d" 2>/dev/null || true
    fi
  done
}

apps_nats_read_variables() {
  header "Nats Settings"
  read_value "Nats replicas (default is 1, use 3 for cluster)" \
    "${NATS_REPLICAS}"
  NATS_REPLICAS=${READ_VALUE}
  read_value "Nats image" "$NATS_IMAGE"
  NATS_IMAGE=${READ_VALUE}
  read_value "Nats Box image" "$NATSBOX_IMAGE"
  NATSBOX_IMAGE=${READ_VALUE}
  read_value "Nats Reloader image" "$NATS_RELOADER_IMAGE"
  NATS_RELOADER_IMAGE=${READ_VALUE}
  read_value "Nats Exporter image" "$NATS_EXPORTER_IMAGE"
  NATS_EXPORTER_IMAGE=${READ_VALUE}
  read_value "Nats storageClass ('local-storage' @ k3d, 'gp3' @ eks)" \
    "${NATS_STORAGE_CLASS}"
  NATS_STORAGE_CLASS=${READ_VALUE}
  read_value "Nats Storage Size" "${NATS_STORAGE_SIZE}"
  NATS_STORAGE_SIZE=${READ_VALUE}
  read_value "Fixed port for nats pf? (i.e. 4222 or '-' for random)" \
    "$NATS_PF_PORT"
  NATS_PF_PORT=${READ_VALUE}
}

apps_nats_print_variables() {
  cat <<EOF
# Nats Settings
# ---
# Nats replicas
NATS_REPLICAS=$NATS_REPLICAS
# Nats image
NATS_IMAGE=$NATS_IMAGE
# Nats box image
NATSBOX_IMAGE=$NATSBOX_IMAGE
# Nats reloader image
NATS_RELOADER_IMAGE=$NATS_RELOADER_IMAGE
# Nats exporter image
NATS_EXPORTER_IMAGE=$NATS_EXPORTER_IMAGE
# Nats storageClass ('local-storage' @ k3d, 'gp3' @ eks)
NATS_STORAGE_CLASS=$NATS_STORAGE_CLASS
# Nats Volume Size (if storage is local or NFS the value is ignored)
NATS_STORAGE_SIZE=$NATS_STORAGE_SIZE
# Fixed port for nats pf (standard is 9200, empty for random)
NATS_PF_PORT=$NATS_PF_PORT
# ---
EOF
}

apps_nats_logs() {
  _deployment="$1"
  _cluster="$2"
  apps_nats_export_variables "$_deployment" "$_cluster"
  _ns="$NATS_NAMESPACE"
  _label="app=nats-master"
  kubectl -n "$_ns" logs -l "$_label" -f
}

apps_nats_install() {
  _deployment="$1"
  _cluster="$2"
  apps_nats_export_variables "$_deployment" "$_cluster"
  apps_nats_check_directories
  _app="nats"
  _ns="$NATS_NAMESPACE"
  _helm_values_tmpl="$NATS_HELM_VALUES_TMPL"
  _helm_values_yaml="$NATS_HELM_VALUES_YAML"
  _pvc_tmpl="$NATS_PVC_TMPL"
  _pvc_yaml="$NATS_PVC_YAML"
  _pv_tmpl="$NATS_PV_TMPL"
  _pv_yaml="$NATS_PV_YAML"
  _release="$NATS_RELEASE"
  _chart="$NATS_CHART"
  _version="$NATS_VERSION"
  _storage_class="$NATS_STORAGE_CLASS"
  _storage_size="$NATS_STORAGE_SIZE"
  # Replace storage class or remove the line
  if [ "$_storage_class" ]; then
    _storage_class_sed="s%__STORAGE_CLASS__%$_storage_class%"
  else
    _storage_class_sed="/__STORAGE_CLASS__/d;"
  fi
  if [ "$NATS_REPLICAS" -gt "1" ]; then
    _cluster_enabled="true"
  else
    _cluster_enabled="false"
  fi
  # Prepare values for helm
  sed \
    -e "s%__NATS_IMAGE__%$NATS_IMAGE%" \
    -e "s%__NATSBOX_IMAGE__%$NATSBOX_IMAGE%" \
    -e "s%__NATS_RELOADER_IMAGE__%$NATS_RELOADER_IMAGE%" \
    -e "s%__NATS_EXPORTER_IMAGE__%$NATS_EXPORTER_IMAGE%" \
    -e "s%__STORAGE_SIZE__%$_storage_size%" \
    -e "s%__RELEASE_NAME__%$_release%" \
    -e "s%__CLUSTER_ENABLED__%$_cluster_enabled%" \
    -e "s%__REPLICAS__%$NATS_REPLICAS%" \
    -e "$_storage_class_sed" \
    "$_helm_values_tmpl" | stdout_to_file "$_helm_values_yaml"
  # Check helm repo
  check_helm_repo "$NATS_REPO_NAME" "$NATS_REPO_URL"
  # Create namespace if needed
  if ! find_namespace "$_ns"; then
    create_namespace "$_ns"
  fi
  # Pre-create directories if needed and adjust storage_sed
  if [ "$_storage_class" = "local-storage" ] &&
    is_selected "$CLUSTER_USE_LOCAL_STORAGE"; then
    for i in $(seq 0 $((NATS_REPLICAS-1))); do
      _pv_name="$NATS_PV_PREFIX-$i"
      test -d "$CLUST_VOLUMES_DIR/$_pv_name" ||
        mkdir "$CLUST_VOLUMES_DIR/$_pv_name"
    done
    _storage_sed="$_storage_class_sed"
    # Create PVs
    for i in $(seq 0 $((NATS_REPLICAS-1))); do
      _pvc_name="$NATS_PV_PREFIX-$i"
      _pv_name="$NATS_PV_PREFIX-$i"
      _pv_yaml="$NATS_KUBECTL_DIR/pv-$i.yaml"
      sed \
        -e "s%__APP__%$_app%" \
        -e "s%__NAMESPACE__%$_ns%" \
        -e "s%__PV_NAME__%$_pv_name%" \
        -e "s%__PVC_NAME__%$_pvc_name%" \
        -e "s%__STORAGE_SIZE__%$_storage_size%" \
        -e "$_storage_sed" \
        "$_pv_tmpl" >"$_pv_yaml"
      kubectl_apply "$_pv_yaml"
    done
  else
    _storage_sed="/BEG: local-storage/,/END: local-storage/{d}"
    _storage_sed="$_storage_sed;$_storage_class_sed"
    while read -r _yaml; do
      kubectl_delete "$_yaml"
    done <<EOF
find "$NATS_KUBECTL_DIR" -name "pvc-*.yaml"
EOF
  fi
  # Create PVCs
  for i in $(seq 0 $((NATS_REPLICAS-1))); do
    _pvc_name="$NATS_PV_PREFIX-$i"
    _pvc_yaml="$NATS_KUBECTL_DIR/pvc-$i.yaml"
    sed \
      -e "s%__APP__%$_app%" \
      -e "s%__NAMESPACE__%$_ns%" \
      -e "s%__PVC_NAME__%$_pvc_name%" \
      -e "s%__STORAGE_SIZE__%$_storage_size%" \
      -e "$_storage_sed" \
      "$_pvc_tmpl" >"$_pvc_yaml"
      kubectl_apply "$_pvc_yaml"
  done
  # Install or upgrade chart
  helm_upgrade "$_ns" "$_helm_values_yaml" "$_release" "$_chart" "$_version"
  # Wait for service to be available
  kubectl rollout status --timeout="$ROLLOUT_STATUS_TIMEOUT" \
    -n "$_ns" "statefulset/$_release"
  # Remove old PVCs
  i=1
  while read -r _yaml; do
    if [ "$i" -gt "$NATS_REPLICAS" ]; then
      kubectl_delete "$_yaml" || true
    fi
    i="$((i+1))"
  done <<EOF
$(find "$NATS_KUBECTL_DIR" -name "pvc-*.yaml" | sort -n)
EOF
  # Remove old PVs
  i=1
  while read -r _yaml; do
    if [ "$i" -gt "$NATS_REPLICAS" ]; then
      kubectl_delete "$_yaml" || true
    fi
    i="$((i+1))"
  done <<EOF
$(find "$NATS_KUBECTL_DIR" -name "pv-*.yaml" | sort -n)
EOF
}

apps_nats_remove() {
  _deployment="$1"
  _cluster="$2"
  apps_nats_export_variables "$_deployment" "$_cluster"
  _app="nats"
  _ns="$NATS_NAMESPACE"
  _values_yaml="$NATS_HELM_VALUES_YAML"
  _release="$NATS_RELEASE"
  if find_namespace "$_ns"; then
    header "Removing '$_app' objects"
    # Uninstall chart
    helm uninstall -n "$_ns" "$_release" || true
    if [ -f "$_values_yaml" ]; then
      rm -f "$_values_yaml"
    fi
    # Remove PVCs
    while read -r _yaml; do
      kubectl_delete "$_yaml" || true
    done <<EOF
$(find "$NATS_KUBECTL_DIR" -name "pvc-*.yaml")
EOF
    # Remove PVs
    while read -r _yaml; do
      kubectl_delete "$_yaml" || true
    done <<EOF
$(find "$NATS_KUBECTL_DIR" -name "pv-*.yaml")
EOF
    # Delete namespace if there are no charts deployed
    if [ -z "$(helm list -n "$_ns" -q)" ]; then
      delete_namespace "$_ns"
    fi
    footer
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
  apps_nats_clean_directories
}

apps_nats_rmvols() {
  _deployment="$1"
  _cluster="$2"
  apps_nats_export_variables "$_deployment" "$_cluster"
  _ns="$NATS_NAMESPACE"
  if find_namespace "$_ns"; then
    echo "Namespace '$_ns' found, not removing volumes!"
  else
    _dirs="$(
      find "$CLUST_VOLUMES_DIR" -maxdepth 1 -type d \
        -name "$NATS_PV_PREFIX-*" -printf "- %f\n"
    )"
    if [ "$_dirs" ]; then
      echo "Removing directories:"
      echo "$_dirs"
      find "$CLUST_VOLUMES_DIR" -maxdepth 1 -type d \
        -name "$NATS_PV_PREFIX-*" -exec sudo rm -rf {} \;
    fi
  fi
}

apps_nats_status() {
  _deployment="$1"
  _cluster="$2"
  apps_nats_export_variables "$_deployment" "$_cluster"
  _app="nats"
  _ns="$NATS_NAMESPACE"
  if find_namespace "$_ns"; then
    kubectl get all,endpoints,ingress,secrets -n "$_ns"
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

apps_nats_summary() {
  _deployment="$1"
  _cluster="$2"
  apps_nats_export_variables "$_deployment" "$_cluster"
  _addon="nats"
  _ns="$NATS_NAMESPACE"
  _release="$NATS_RELEASE"
  print_helm_summary "$_ns" "$_addon" "$_release"
  statefulset_helm_summary "$_ns" "$_release"
}

apps_nats_command() {
  _command="$1"
  _deployment="$2"
  _cluster="$3"
  case "$_command" in
    logs) apps_nats_logs "$_deployment" "$_cluster";;
    install) apps_nats_install "$_deployment" "$_cluster";;
    remove) apps_nats_remove "$_deployment" "$_cluster";;
    rmvols) apps_nats_rmvols "$_deployment" "$_cluster";;
    status) apps_nats_status "$_deployment" "$_cluster";;
    summary) apps_nats_summary "$_deployment" "$_cluster";;
    *) echo "Unknown nats subcommand '$1'"; exit 1 ;;
  esac
}

apps_nats_command_list() {
  echo "logs install remove rmvols status summary"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
