#!/bin/sh
# ----
# File:        apps/mongodb.sh
# Description: Functions to manage mongodb deployments for kyso on k8s clusters
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022-2023 Kyso Inc.
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_APPS_MONGODB_SH="1"

# ---------
# Variables
# ---------

# CMND_DSC="mongodb: manage mongodb deployment for kyso"

# Defaults
export DEPLOYMENT_DEFAULT_MONGODB_ARCHITECTURE="replicaset"
export DEPLOYMENT_DEFAULT_MONGODB_CHART_VERSION="12.1.31"
#export DEPLOYMENT_DEFAULT_MONGODB_CHART_VERSION="11.2.0"
export DEPLOYMENT_DEFAULT_MONGODB_REPLICAS="1"
export DEPLOYMENT_DEFAULT_MONGODB_IMAGE_REGISTRY="docker.io"
export DEPLOYMENT_DEFAULT_MONGODB_IMAGE_REPO="bitnami/mongodb"
export DEPLOYMENT_DEFAULT_MONGODB_IMAGE_TAG="5.0.10-debian-11-r3"
#export DEPLOYMENT_DEFAULT_MONGODB_IMAGE_TAG="4.4.13-debian-10-r52"
export DEPLOYMENT_DEFAULT_MONGODB_ENABLE_METRICS="false"
export DEPLOYMENT_DEFAULT_MONGODB_EXPORTER_IMAGE_REPO="bitnami/mongodb-exporter"
export DEPLOYMENT_DEFAULT_MONGODB_EXPORTER_IMAGE_TAG="0.33.0-debian-11-r9"
#export DEPLOYMENT_DEFAULT_MONGODB_EXPORTER_IMAGE_TAG="0.31.2-debian-10-r14"
export DEPLOYMENT_DEFAULT_MONGODB_STORAGE_CLASS=""
export DEPLOYMENT_DEFAULT_MONGODB_STORAGE_SIZE="8Gi"
export DEPLOYMENT_DEFAULT_MONGODB_PF_PORT=""

# Fixed values
export MONGODB_HELM_REPO_NAME="bitnami"
export MONGODB_HELM_REPO_URL="https://charts.bitnami.com/bitnami"
export MONGODB_HELM_RELEASE="kyso-mongodb"
export MONGODB_HELM_CHART="bitnami/mongodb"
export MONGODB_DB_NAME="kyso"
export MONGODB_DB_USER="kysodb"
export MONGODB_PV_PREFIX="datadir-$MONGODB_HELM_RELEASE"

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

apps_mongodb_export_variables() {
  [ -z "$__apps_mongodb_export_variables" ] || return 0
  _deployment="$1"
  _cluster="$2"
  apps_common_export_variables "$_deployment" "$_cluster"
  # Values
  export MONGODB_NAMESPACE="mongodb-$DEPLOYMENT_NAME"
  # Directories
  export MONGODB_TMPL_DIR="$TMPL_DIR/apps/mongodb"
  export MONGODB_HELM_DIR="$DEPLOY_HELM_DIR/mongodb"
  export MONGODB_KUBECTL_DIR="$DEPLOY_KUBECTL_DIR/mongodb"
  export MONGODB_SECRETS_DIR="$DEPLOY_SECRETS_DIR/mongodb"
  export MONGODB_PF_DIR="$DEPLOY_SECRETS_DIR/mongodb"
  # Templates
  export MONGODB_HELM_VALUES_TMPL="$MONGODB_TMPL_DIR/values.yaml"
  export MONGODB_PVC_TMPL="$MONGODB_TMPL_DIR/pvc.yaml"
  export MONGODB_PV_TMPL="$MONGODB_TMPL_DIR/pv.yaml"
  # Files
  export MONGODB_HELM_VALUES_YAML="$MONGODB_HELM_DIR/values${SOPS_EXT}.yaml"
  export MONGODB_REPLICA_SET_KEY_FILE="$MONGODB_SECRETS_DIR/rsk${SOPS_EXT}.txt"
  export MONGODB_ROOT_PASS_FILE="$MONGODB_SECRETS_DIR/root-pass${SOPS_EXT}.txt"
  export MONGODB_USER_PASS_FILE="$MONGODB_SECRETS_DIR/user-pass${SOPS_EXT}.txt"
  export MONGODB_PF_OUT="$MONGODB_PF_DIR/kubectl.out"
  export MONGODB_PF_PID="$MONGODB_PF_DIR/kubectl.pid"
  # Use defaults for variables missing from config files
  if [ "$DEPLOYMENT_MONGODB_CHART_VERSION" ]; then
    export MONGODB_CHART_VERSION="$DEPLOYMENT_MONGODB_CHART_VERSION"
  else
    export MONGODB_CHART_VERSION="$DEPLOYMENT_DEFAULT_MONGODB_CHART_VERSION"
  fi
  if [ "$DEPLOYMENT_MONGODB_ARCHITECTURE" ]; then
    export MONGODB_ARCHITECTURE="$DEPLOYMENT_MONGODB_ARCHITECTURE"
  else
    export MONGODB_ARCHITECTURE="$DEPLOYMENT_DEFAULT_MONGODB_ARCHITECTURE"
  fi
  if [ "$DEPLOYMENT_MONGODB_REPLICAS" ]; then
    export MONGODB_REPLICAS="$DEPLOYMENT_MONGODB_REPLICAS"
  else
    export MONGODB_REPLICAS="$DEPLOYMENT_DEFAULT_MONGODB_REPLICAS"
  fi
  if [ "$DEPLOYMENT_MONGODB_IMAGE_REGISTRY" ]; then
    export MONGODB_IMAGE_REGISTRY="$DEPLOYMENT_MONGODB_IMAGE_REGISTRY"
  else
    export MONGODB_IMAGE_REGISTRY="$DEPLOYMENT_DEFAULT_MONGODB_IMAGE_REGISTRY"
  fi
  if [ "$DEPLOYMENT_MONGODB_IMAGE_REPO" ]; then
    export MONGODB_IMAGE_REPO="$DEPLOYMENT_MONGODB_IMAGE_REPO"
  else
    export MONGODB_IMAGE_REPO="$DEPLOYMENT_DEFAULT_MONGODB_IMAGE_REPO"
  fi
  if [ "$DEPLOYMENT_MONGODB_IMAGE_TAG" ]; then
    export MONGODB_IMAGE_TAG="$DEPLOYMENT_MONGODB_IMAGE_TAG"
  else
    export MONGODB_IMAGE_TAG="$DEPLOYMENT_DEFAULT_MONGODB_IMAGE_TAG"
  fi
  if [ "$DEPLOYMENT_MONGODB_ENABLE_METRICS" ]; then
    if is_selected "$DEPLOYMENT_MONGODB_ENABLE_METRICS"; then
      export MONGODB_ENABLE_METRICS="true"
    else
      export MONGODB_ENABLE_METRICS="false"
    fi
  elif [ "$DEPLOYMENT_DEFAULT_MONGODB_ENABLE_METRICS" ]; then
    if is_selected "$DEPLOYMENT_DEFAULT_MONGODB_ENABLE_METRICS"; then
      export MONGODB_ENABLE_METRICS="true"
    else
      export MONGODB_ENABLE_METRICS="false"
    fi
  else
    export MONGODB_ENABLE_METRICS="false"
  fi
  if [ "$DEPLOYMENT_MONGODB_EXPORTER_IMAGE_REPO" ]; then
    _exporter_image_repo="$DEPLOYMENT_MONGODB_EXPORTER_IMAGE_REPO"
  else
    _exporter_image_repo="$DEPLOYMENT_DEFAULT_MONGODB_EXPORTER_IMAGE_REPO"
  fi
  export MONGODB_EXPORTER_IMAGE_REPO="$_exporter_image_repo"
  if [ "$DEPLOYMENT_MONGODB_EXPORTER_IMAGE_TAG" ]; then
    _exporter_image_tag="$DEPLOYMENT_MONGODB_EXPORTER_IMAGE_TAG"
  else
    _exporter_image_tag="$DEPLOYMENT_DEFAULT_MONGODB_EXPORTER_IMAGE_TAG"
  fi
  export MONGODB_EXPORTER_IMAGE_TAG="$_exporter_image_tag"
  if [ "$DEPLOYMENT_MONGODB_STORAGE_CLASS" ]; then
    export MONGODB_STORAGE_CLASS="$DEPLOYMENT_MONGODB_STORAGE_CLASS"
  else
    export MONGODB_STORAGE_CLASS="$DEPLOYMENT_DEFAULT_MONGODB_STORAGE_CLASS"
  fi
  if [ "$DEPLOYMENT_MONGODB_STORAGE_SIZE" ]; then
    export MONGODB_STORAGE_SIZE="$DEPLOYMENT_MONGODB_STORAGE_SIZE"
  else
    export MONGODB_STORAGE_SIZE="$DEPLOYMENT_DEFAULT_MONGODB_STORAGE_SIZE"
  fi
  if [ "$DEPLOYMENT_MONGODB_PF_PORT" ]; then
    export MONGODB_PF_PORT="$DEPLOYMENT_MONGODB_PF_PORT"
  else
    export MONGODB_PF_PORT="$DEPLOYMENT_DEFAULT_MONGODB_PF_PORT"
  fi
  __apps_mongodb_export_variables="1"
}

apps_mongodb_check_directories() {
  apps_common_check_directories
  for _d in "$MONGODB_HELM_DIR" "$MONGODB_KUBECTL_DIR" "$MONGODB_SECRETS_DIR" \
    "$MONGODB_PF_DIR"; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

apps_mongodb_clean_directories() {
  # Try to remove empty dirs, except if they contain secrets
  for _d in "$MONGODB_HELM_DIR" "$MONGODB_KUBECTL_DIR" "$MONGODB_SECRETS_DIR" \
    "$MONGODB_PF_DIR"; do
    if [ -d "$_d" ]; then
      rmdir "$_d" 2>/dev/null || true
    fi
  done
}

apps_mongodb_read_variables() {
  _app="mongodb"
  header "Reading $_app settings"
  read_value "MongoDB Helm Chart Version" "${MONGODB_CHART_VERSION}"
  MONGODB_CHART_VERSION=${READ_VALUE}
  read_value "MongoDB Architecture ('standalone'/'replicaset')" \
    "${MONGODB_ARCHITECTURE}"
  MONGODB_ARCHITECTURE=${READ_VALUE}
  if [ "$MONGODB_ARCHITECTURE" = "replicaset" ]; then
    read_value "MongoDB Replicas" "${MONGODB_REPLICAS}"
  else
    READ_VALUE="1"
  fi
  MONGODB_REPLICAS=${READ_VALUE}
  read_value "MongoDB Registry" "${MONGODB_IMAGE_REGISTRY}"
  MONGODB_IMAGE_REGISTRY=${READ_VALUE}
  read_value "MongoDB Registry Repository" "${MONGODB_IMAGE_REPO}"
  MONGODB_IMAGE_REPO=${READ_VALUE}
  read_value "MongoDB Image Tag" "${MONGODB_IMAGE_TAG}"
  MONGODB_IMAGE_TAG=${READ_VALUE}
  read_value "MongoDB Enable Metrics" "${MONGODB_ENABLE_METRICS}"
  MONGODB_ENABLE_METRICS=${READ_VALUE}
  read_value "MongoDB Exporter Registry Repository" \
    "${MONGODB_EXPORTER_IMAGE_REPO}"
  MONGODB_EXPORTER_IMAGE_REPO=${READ_VALUE}
  read_value "MongoDB Exporter Image Tag" "${MONGODB_EXPORTER_IMAGE_TAG}"
  MONGODB_EXPORTER_IMAGE_TAG=${READ_VALUE}
  read_value "MongoDB storageClass ('local-storage' @ k3d, 'gp3' @ eks)" \
    "${MONGODB_STORAGE_CLASS}"
  MONGODB_STORAGE_CLASS=${READ_VALUE}
  read_value "MongoDB Storage Size" "${MONGODB_STORAGE_SIZE}"
  MONGODB_STORAGE_SIZE=${READ_VALUE}
  read_value "Fixed port for mongo pf? (i.e. 27017 or '-' for random)" \
    "$MONGODB_PF_PORT"
  MONGODB_PF_PORT=${READ_VALUE}
}

apps_mongodb_print_variables() {
  _app="mongodb"
  cat <<EOF
# Deployment $_app settings
# ---
# MongoDB Helm Chart Version
MONGODB_CHART_VERSION=$MONGODB_CHART_VERSION
# MongoDB Deployment Architecture ('standalone' or 'replicaset')
MONGODB_ARCHITECTURE=$MONGODB_ARCHITECTURE
# Number of replicas for the 'replicaset' model
MONGODB_REPLICAS=$MONGODB_REPLICAS
# MongoDB Registry (change if using a private registry only)
MONGODB_IMAGE_REGISTRY=$MONGODB_IMAGE_REGISTRY
# MongoDB Repo on the Registry (again, change if using a private registry only)
MONGODB_IMAGE_REPO=$MONGODB_IMAGE_REPO
# MongoDB Image TAG
MONGODB_IMAGE_TAG=$MONGODB_IMAGE_TAG
# Set to true to add metrics to the deployment, useful with our own
# prometheus deployment
MONGODB_ENABLE_METRICS=$MONGODB_ENABLE_METRICS
# MongoDB Exporter Repo on the Registry
MONGODB_EXPORTER_IMAGE_REPO=$MONGODB_EXPORTER_IMAGE_REPO
# MongoDB Exporter Image TAG
MONGODB_EXPORTER_IMAGE_TAG=$MONGODB_EXPORTER_IMAGE_TAG
# MongoDB Storage Class ('local-storage' @ k3d, 'gp3' @ eks)
MONGODB_STORAGE_CLASS=$MONGODB_STORAGE_CLASS
# MongoDB Volume Size (if storage is local or NFS the value is ignored)
MONGODB_STORAGE_SIZE=$MONGODB_STORAGE_SIZE
# Fixed port for mongodb pf (standard is 27017, empty for random)
MONGODB_PF_PORT=$MONGODB_PF_PORT
# ---
EOF
}

apps_mongodb_print_root_database_uri() {
  _deployment="$1"
  _cluster="$2"
  apps_mongodb_export_variables "$_deployment" "$_cluster"
  _db_user="root"
  _db_pass="$(file_to_stdout "$MONGODB_ROOT_PASS_FILE")"
  _db_name="admin"
  if [ "$3" ]; then
    _db_hosts="$3"
  elif [ "$MONGODB_ARCHITECTURE" = "standalone" ]; then
    _db_hosts="$MONGODB_HELM_RELEASE.$MONGODB_NAMESPACE.svc.cluster.local"
  else
    _suffix="$MONGODB_HELM_RELEASE-headless.$MONGODB_NAMESPACE.svc.cluster.local"
    _db_hosts="$MONGODB_HELM_RELEASE-0.$_suffix"
    for i in $(seq $((MONGODB_REPLICAS - 1))); do
      _db_hosts="$_db_hosts,$MONGODB_HELM_RELEASE-$i.$_suffix"
    done
  fi
  echo "mongodb://$_db_user:$_db_pass@$_db_hosts/$_db_name"
}

apps_mongodb_print_user_database_uri() {
  _deployment="$1"
  _cluster="$2"
  apps_mongodb_export_variables "$_deployment" "$_cluster"
  _db_user="$MONGODB_DB_USER"
  _db_pass="$(file_to_stdout "$MONGODB_USER_PASS_FILE")"
  _db_name="$MONGODB_DB_NAME"
  if [ "$3" ]; then
    _db_hosts="$3"
  elif [ "$MONGODB_ARCHITECTURE" = "standalone" ]; then
    _db_hosts="$MONGODB_HELM_RELEASE.$MONGODB_NAMESPACE.svc.cluster.local"
  else
    _suffix="$MONGODB_HELM_RELEASE-headless.$MONGODB_NAMESPACE.svc.cluster.local"
    _db_hosts="$MONGODB_HELM_RELEASE-0.$_suffix"
    for i in $(seq $((MONGODB_REPLICAS - 1))); do
      _db_hosts="$_db_hosts,$MONGODB_HELM_RELEASE-$i.$_suffix"
    done
  fi
  echo "mongodb://$_db_user:$_db_pass@$_db_hosts/$_db_name"
}

apps_mongodb_logs() {
  _deployment="$1"
  _cluster="$2"
  apps_mongodb_export_variables "$_deployment" "$_cluster"
  _app="mongodb"
  _container="mongodb"
  _release="$MONGODB_HELM_RELEASE"
  _ns="$MONGODB_NAMESPACE"
  if kubectl get -n "$_ns" "statefulset/$_release" >/dev/null 2>&1; then
    kubectl -n "$_ns" logs "statefulset/$_release" -c "$_container" -f
  else
    echo "Statefulset '$_release' not found on namespace '$_ns'"
  fi
}

apps_mongodb_sh() {
  _deployment="$1"
  _cluster="$2"
  apps_mongodb_export_variables "$_deployment" "$_cluster"
  _app="mongodb"
  _container="mongodb"
  _release="$MONGODB_HELM_RELEASE"
  _ns="$MONGODB_NAMESPACE"
  if kubectl get -n "$_ns" "statefulset/$_release" >/dev/null 2>&1; then
    kubectl -n "$_ns" exec -ti "statefulset/$_release" -c "$_container" \
      -- /bin/sh
  else
    echo "Statefulset '$_release' not found on namespace '$_ns'"
  fi
}

apps_mongodb_install() {
  _deployment="$1"
  _cluster="$2"
  apps_mongodb_export_variables "$_deployment" "$_cluster"
  apps_mongodb_check_directories
  _app="mongodb"
  _ns="$MONGODB_NAMESPACE"
  _helm_values_tmpl="$MONGODB_HELM_VALUES_TMPL"
  _helm_values_yaml="$MONGODB_HELM_VALUES_YAML"
  _pvc_tmpl="$MONGODB_PVC_TMPL"
  _pvc_yaml="$MONGODB_PVC_YAML"
  _pv_tmpl="$MONGODB_PV_TMPL"
  _pv_yaml="$MONGODB_PV_YAML"
  _storage_class="$MONGODB_STORAGE_CLASS"
  _storage_size="$MONGODB_STORAGE_SIZE"
  _release="$MONGODB_HELM_RELEASE"
  _chart="$MONGODB_HELM_CHART"
  _version="$MONGODB_CHART_VERSION"
  _replica_set_key_file="$MONGODB_REPLICA_SET_KEY_FILE"
  _root_pass_file="$MONGODB_ROOT_PASS_FILE"
  _user_pass_file="$MONGODB_USER_PASS_FILE"
  # Get database passwords
  if [ -f "$_replica_set_key_file" ]; then
    _mongodb_replica_set_key="$(file_to_stdout "$_replica_set_key_file")"
  else
    _mongodb_replica_set_key=""
  fi
  if [ -f "$_root_pass_file" ]; then
    _mongodb_root_pass="$(file_to_stdout "$_root_pass_file")"
  else
    _mongodb_root_pass=""
  fi
  if [ -f "$_user_pass_file" ]; then
    _mongodb_user_pass="$(file_to_stdout "$_user_pass_file")"
  else
    _mongodb_user_pass=""
  fi
  # Enable arbeiter only for an even number of replicas
  if [ "$((MONGODB_REPLICAS % 2))" -eq "0" ]; then
    _arbiter_enabled="true"
  else
    _arbiter_enabled="false"
  fi
  # Replace storage class or remove the line
  if [ "$_storage_class" ]; then
    _storage_class_sed="s%__STORAGE_CLASS__%$_storage_class%"
  else
    _storage_class_sed="/__STORAGE_CLASS__/d;"
  fi
  # Install mongodb using the selected architecture
  sed \
    -e "s%__MONGODB_ARCHITECTURE__%$MONGODB_ARCHITECTURE%" \
    -e "s%__MONGODB_REPLICAS__%$MONGODB_REPLICAS%" \
    -e "s%__PULL_SECRETS_NAME__%$CLUSTER_PULL_SECRETS_NAME%" \
    -e "s%__ARBITER_ENABLED__%$_arbiter_enabled%" \
    -e "s%__MONGODB_IMAGE_REGISTRY__%$MONGODB_IMAGE_REGISTRY%" \
    -e "s%__MONGODB_IMAGE_REPO__%$MONGODB_IMAGE_REPO%" \
    -e "s%__MONGODB_IMAGE_TAG__%$MONGODB_IMAGE_TAG%" \
    -e "s%__ENABLE_METRICS__%$MONGODB_ENABLE_METRICS%" \
    -e "s%__MONGODB_EXPORTER_IMAGE_REPO__%$MONGODB_EXPORTER_IMAGE_REPO%" \
    -e "s%__MONGODB_EXPORTER_IMAGE_TAG__%$MONGODB_EXPORTER_IMAGE_TAG%" \
    -e "s%__MONGODB_REPLICA_SET_KEY__%$_mongodb_replica_set_key%" \
    -e "s%__MONGODB_ROOT_PASS__%$_mongodb_root_pass%" \
    -e "s%__MONGODB_DB_NAME__%$MONGODB_DB_NAME%" \
    -e "s%__MONGODB_DB_USER__%$MONGODB_DB_USER%" \
    -e "s%__MONGODB_DB_PASS__%$_mongodb_user_pass%" \
    -e "$_storage_class_sed" \
    "$_helm_values_tmpl" | stdout_to_file "$_helm_values_yaml"
  # Check helm repo
  check_helm_repo "$MONGODB_HELM_REPO_NAME" "$MONGODB_HELM_REPO_URL"
  # Create namespace if needed
  if ! find_namespace "$_ns"; then
    create_namespace "$_ns"
  fi
  # Pre-create directories if needed and adjust storage_sed
  if [ "$_storage_class" = "local-storage" ] &&
    is_selected "$CLUSTER_USE_LOCAL_STORAGE"; then
    for i in $(seq 0 $((MONGODB_REPLICAS - 1))); do
      _pv_name="$MONGODB_PV_PREFIX-$DEPLOYMENT_NAME-$i"
      test -d "$CLUST_VOLUMES_DIR/$_pv_name" ||
        mkdir "$CLUST_VOLUMES_DIR/$_pv_name"
    done
    _storage_sed="$_storage_class_sed"
    # Create PVs
    for i in $(seq 0 $((MONGODB_REPLICAS - 1))); do
      _pvc_name="$MONGODB_PV_PREFIX-$i"
      _pv_name="$MONGODB_PV_PREFIX-$DEPLOYMENT_NAME-$i"
      _pv_yaml="$MONGODB_KUBECTL_DIR/pv-$i.yaml"
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
$(find "$MONGODB_KUBECTL_DIR" -name 'pv-*.yaml')
EOF
  fi
  # Create PVCs
  for i in $(seq 0 $((MONGODB_REPLICAS - 1))); do
    _pvc_name="$MONGODB_PV_PREFIX-$i"
    _pvc_yaml="$MONGODB_KUBECTL_DIR/pvc-$i.yaml"
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
  # Truncate and fix permissions of the password files
  : >"$_replica_set_key_file"
  chmod 0600 "$_replica_set_key_file"
  : >"$_root_pass_file"
  chmod 0600 "$_root_pass_file"
  : >"$_user_pass_file"
  chmod 0600 "$_user_pass_file"
  # Get passwords
  kubectl get secret -n "$_ns" "$_release" \
    -o jsonpath="{.data.mongodb-replica-set-key}" |
    base64 --decode | stdout_to_file "$_replica_set_key_file"
  kubectl get secret -n "$_ns" "$_release" \
    -o jsonpath="{.data.mongodb-root-password}" |
    base64 --decode | stdout_to_file "$_root_pass_file"
  kubectl get secret -n "$_ns" "$_release" \
    -o jsonpath="{.data.mongodb-passwords}" |
    base64 --decode | awk -F',' '{print $1}' | stdout_to_file "$_user_pass_file"
  # Wait for service to be available
  kubectl rollout status statefulset --timeout="$ROLLOUT_STATUS_TIMEOUT" \
    -n "$_ns" "$_release"
  # Remove old PVCs
  i=1
  while read -r _yaml; do
    if [ "$i" -gt "$MONGODB_REPLICAS" ]; then
      kubectl_delete "$_yaml" || true
    fi
    i="$((i + 1))"
  done <<EOF
$(find "$MONGODB_KUBECTL_DIR" -name "pvc-*.yaml" | sort -n)
EOF
  # Remove old PVs
  i=1
  while read -r _yaml; do
    if [ "$i" -gt "$MONGODB_REPLICAS" ]; then
      kubectl_delete "$_yaml" || true
    fi
    i="$((i + 1))"
  done <<EOF
$(find "$MONGODB_KUBECTL_DIR" -name "pv-*.yaml" | sort -n)
EOF
}

apps_mongodb_helm_history() {
  _deployment="$1"
  _cluster="$2"
  apps_mongodb_export_variables "$_deployment" "$_cluster"
  _app="mongodb"
  _ns="$MONGODB_NAMESPACE"
  _release="$MONGODB_HELM_RELEASE"
  if find_namespace "$_ns"; then
    helm_history "$_ns" "$_release"
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

apps_mongodb_helm_rollback() {
  _deployment="$1"
  _cluster="$2"
  apps_mongodb_export_variables "$_deployment" "$_cluster"
  _app="mongodb"
  _ns="$MONGODB_NAMESPACE"
  _release="$MONGODB_HELM_RELEASE"
  _rollback_release="$ROLLBACK_RELEASE"
  if find_namespace "$_ns"; then
    helm_rollback "$_ns" "$_release" "$_rollback_release"
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

apps_mongodb_remove() {
  _deployment="$1"
  _cluster="$2"
  apps_mongodb_export_variables "$_deployment" "$_cluster"
  _app="mongodb"
  _ns="$MONGODB_NAMESPACE"
  _values_yaml="$MONGODB_HELM_VALUES_YAML"
  _release="$MONGODB_HELM_RELEASE"
  apps_mongodb_export_variables
  if find_namespace "$_ns"; then
    header "Removing '$_app' objects"
    # Uninstall chart
    helm uninstall -n "$_ns" "$_release" || true
    if [ -f "$_values_yaml" ]; then
      rm -f "$_values_yaml"
    fi
    # Remove PVCs
    while read -r _yaml; do
      kubectl_delete "$_yaml"
    done <<EOF
$(find "$MONGODB_KUBECTL_DIR" -name 'pvc-*.yaml')
EOF
    # Remove PVs
    while read -r _yaml; do
      kubectl_delete "$_yaml"
    done <<EOF
$(find "$MONGODB_KUBECTL_DIR" -name 'pv-*.yaml')
EOF
    # Delete namespace if there are no charts deployed
    if [ -z "$(helm list -n "$_ns" -q)" ]; then
      delete_namespace "$_ns"
    fi
    footer
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
  apps_mongodb_clean_directories
}

apps_mongodb_rmvols() {
  _deployment="$1"
  _cluster="$2"
  apps_mongodb_export_variables "$_deployment" "$_cluster"
  _ns="$MONGODB_NAMESPACE"
  if find_namespace "$_ns"; then
    echo "Namespace '$_ns' found, not removing volumes!"
  else
    _dirs="$(
      find "$CLUST_VOLUMES_DIR" -maxdepth 1 -type d \
        -name "$MONGODB_PV_PREFIX-*" -printf "- %f\n"
    )"
    if [ "$_dirs" ]; then
      echo "Removing directories:"
      echo "$_dirs"
      find "$CLUST_VOLUMES_DIR" -maxdepth 1 -type d \
        -name "$MONGODB_PV_PREFIX-*" -exec sudo rm -rf {} \;
    fi
  fi
}

apps_mongodb_status() {
  _deployment="$1"
  _cluster="$2"
  apps_mongodb_export_variables "$_deployment" "$_cluster"
  _app="mongodb"
  _ns="$MONGODB_NAMESPACE"
  if find_namespace "$_ns"; then
    kubectl get all,endpoints,ingress,secrets -n "$_ns"
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

apps_mongodb_summary() {
  _deployment="$1"
  _cluster="$2"
  apps_mongodb_export_variables "$_deployment" "$_cluster"
  _addon="mongodb"
  _ns="$MONGODB_NAMESPACE"
  _release="$MONGODB_HELM_RELEASE"
  print_helm_summary "$_ns" "$_addon" "$_release"
  statefulset_helm_summary "$_ns" "$_release"
}

apps_mongodb_uris() {
  _deployment="$1"
  _cluster="$2"
  _addr="${DEPLOYMENT_HOSTNAMES%% *}"
  apps_mongodb_print_user_database_uri "$_deployment" "$_cluster" "$_addr"
  apps_mongodb_print_root_database_uri "$_deployment" "$_cluster" "$_addr"
}

apps_mongodb_env_edit() {
  if [ "$EDITOR" ]; then
    _app="mongodb"
    _deployment="$1"
    _cluster="$2"
    apps_export_variables "$_deployment" "$_cluster"
    _env_file="$DEPLOY_ENVS_DIR/$_app.env"
    if [ -f "$_env_file" ]; then
      "$EDITOR" "$_env_file"
    else
      echo "The '$_env_file' does not exist, use 'env-update' to create it"
      exit 1
    fi
  else
    echo "Export the EDITOR environment variable to use this subcommand"
    exit 1
  fi
}

apps_mongodb_env_path() {
  _app="mongodb"
  _deployment="$1"
  _cluster="$2"
  apps_export_variables "$_deployment" "$_cluster"
  _env_file="$DEPLOY_ENVS_DIR/$_app.env"
  echo "$_env_file"
}

apps_mongodb_env_save() {
  _app="mongodb"
  _deployment="$1"
  _cluster="$2"
  _env_file="$3"
  apps_mongodb_check_directories
  apps_mongodb_print_variables "$_deployment" "$_cluster" |
    stdout_to_file "$_env_file"
}

apps_mongodb_env_update() {
  _app="mongodb"
  _deployment="$1"
  _cluster="$2"
  apps_export_variables "$_deployment" "$_cluster"
  _env_file="$DEPLOY_ENVS_DIR/$_app.env"
  header "$_app configuration variables"
  apps_mongodb_print_variables "$_deployment" "$_cluster" |
    grep -v "^#"
  if [ -f "$_env_file" ]; then
    footer
    [ "$KITT_AUTOUPDATE" = "true" ] && _update="Yes" || _update="No"
    read_bool "Update $_app env vars?" "$_update"
  else
    READ_VALUE="Yes"
  fi
  if is_selected "${READ_VALUE}"; then
    footer
    apps_mongodb_read_variables
    if [ -f "$_env_file" ]; then
      footer
      read_bool "Save updated $_app env vars?" "Yes"
    else
      READ_VALUE="Yes"
    fi
    if is_selected "${READ_VALUE}"; then
      apps_mongodb_env_save "$_deployment" "$_cluster" "$_env_file"
      footer
      echo "$_app configuration saved to '$_env_file'"
      footer
    fi
  fi
}

apps_mongodb_command() {
  _command="$1"
  _deployment="$2"
  _cluster="$3"
  case "$_command" in
  env-edit | env_edit)
    apps_mongodb_env_edit "$_deployment" "$_cluster"
    ;;
  env-path | env_path)
    apps_mongodb_env_path "$_deployment" "$_cluster"
    ;;
  env-show | env_show)
    apps_mongodb_print_variables "$_deployment" "$_cluster" | grep -v '^#'
    ;;
  env-update | env_update)
    apps_mongodb_env_update "$_deployment" "$_cluster"
    ;;
  helm-history) apps_mongodb_helm_history "$_deployment" "$_cluster" ;;
  helm-rollback) apps_mongodb_helm_rollback "$_deployment" "$_cluster" ;;
  logs) apps_mongodb_logs "$_deployment" "$_cluster" ;;
  install) apps_mongodb_install "$_deployment" "$_cluster" ;;
  remove) apps_mongodb_remove "$_deployment" "$_cluster" ;;
  rmvols) apps_mongodb_rmvols "$_deployment" "$_cluster" ;;
  sh) apps_mongodb_sh "$_deployment" "$_cluster" ;;
  status) apps_mongodb_status "$_deployment" "$_cluster" ;;
  summary) apps_mongodb_summary "$_deployment" "$_cluster" ;;
  uris) apps_mongodb_uris "$_deployment" "$_cluster" ;;
  *)
    echo "Unknown mongodb subcommand '$1'"
    exit 1
    ;;
  esac
}

apps_mongodb_command_list() {
  _cmnds="env-edit env-path env-show env-update helm-history helm-rollback"
  _cmnds="$_cmnds install logs remove rmvols sh status summary uris"
  echo "$_cmnds"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
