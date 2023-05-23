#!/bin/sh
# ----
# File:        apps/elasticsearch.sh
# Description: Functions to manage elasticsearch deployments for kyso on k8s
#              clusters.
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022-2023 Kyso Inc.
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_APPS_ELASTICSEARCH_SH="1"

# ---------
# Variables
# ---------

# CMND_DSC="elasticsearch: manage elasticsearch deployment for kyso"

# Defaults
export DEPLOYMENT_DEFAULT_ELASTICSEARCH_CHART_VERSION="7.17.3"
_image_name="docker.elastic.co/elasticsearch/elasticsearch"
export DEPLOYMENT_DEFAULT_ELASTICSEARCH_IMAGE_NAME="$_image_name"
export DEPLOYMENT_DEFAULT_ELASTICSEARCH_IMAGE_TAG="7.17.3"
export DEPLOYMENT_DEFAULT_ELASTICSEARCH_REPLICAS="1"
export DEPLOYMENT_DEFAULT_ELASTICSEARCH_STORAGE_CLASS=""
export DEPLOYMENT_DEFAULT_ELASTICSEARCH_STORAGE_SIZE="30Gi"
export DEPLOYMENT_DEFAULT_ELASTICSEARCH_PF_PORT=""
export DEPLOYMENT_DEFAULT_ELASTICSEARCH_JAVAOPTS=""
export DEPLOYMENT_DEFAULT_ELASTICSEARCH_CPU_REQUESTS="1000m"
export DEPLOYMENT_DEFAULT_ELASTICSEARCH_MEM_REQUESTS="2Gi"

# Fixed values
export ELASTICSEARCH_HELM_REPO_NAME="elastic"
export ELASTICSEARCH_HELM_REPO_URL="https://helm.elastic.co"
export ELASTICSEARCH_HELM_RELEASE="kyso-elasticsearch"
export ELASTICSEARCH_HELM_CHART="elastic/elasticsearch"
export ELASTICSEARCH_PV_PREFIX="elasticsearch-master-elasticsearch-master"

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

apps_elasticsearch_export_variables() {
  [ -z "$__apps_elasticsearch_export_variables" ] || return 0
  _deployment="$1"
  _cluster="$2"
  apps_common_export_variables "$_deployment" "$_cluster"
  # Values
  export ELASTICSEARCH_NAMESPACE="elasticsearch-$DEPLOYMENT_NAME"
  # Directories
  export ELASTICSEARCH_TMPL_DIR="$TMPL_DIR/apps/elasticsearch"
  export ELASTICSEARCH_HELM_DIR="$DEPLOY_HELM_DIR/elasticsearch"
  export ELASTICSEARCH_KUBECTL_DIR="$DEPLOY_KUBECTL_DIR/elasticsearch"
  export ELASTICSEARCH_SECRETS_DIR="$DEPLOY_SECRETS_DIR/elasticsearch"
  export ELASTICSEARCH_PF_DIR="$DEPLOY_PF_DIR/elasticsearch"
  # Templates
  export ELASTICSEARCH_HELM_VALUES_TMPL="$ELASTICSEARCH_TMPL_DIR/values.yaml"
  export ELASTICSEARCH_PVC_TMPL="$ELASTICSEARCH_TMPL_DIR/pvc.yaml"
  export ELASTICSEARCH_PV_TMPL="$ELASTICSEARCH_TMPL_DIR/pv.yaml"
  # Files
  _values_yaml="$ELASTICSEARCH_HELM_DIR/values${SOPS_EXT}.yaml"
  export ELASTICSEARCH_HELM_VALUES_YAML="$_values_yaml"
  export ELASTICSEARCH_PF_OUT="$ELASTICSEARCH_PF_DIR/kubectl.out"
  export ELASTICSEARCH_PF_PID="$ELASTICSEARCH_PF_DIR/kubectl.pid"
  # Use defaults for variables missing from config files
  if [ "$DEPLOYMENT_ELASTICSEARCH_CHART_VERSION" ]; then
    ELASTICSEARCH_CHART_VERSION="$DEPLOYMENT_ELASTICSEARCH_CHART_VERSION"
  else
    ELASTICSEARCH_CHART_VERSION="$DEPLOYMENT_DEFAULT_ELASTICSEARCH_CHART_VERSION"
  fi
  export ELASTICSEARCH_CHART_VERSION
  if [ "$DEPLOYMENT_ELASTICSEARCH_IMAGE_NAME" ]; then
    ELASTICSEARCH_IMAGE_NAME="$DEPLOYMENT_ELASTICSEARCH_IMAGE_NAME"
  else
    ELASTICSEARCH_IMAGE_NAME="$DEPLOYMENT_DEFAULT_ELASTICSEARCH_IMAGE_NAME"
  fi
  export ELASTICSEARCH_IMAGE_NAME
  if [ "$DEPLOYMENT_ELASTICSEARCH_IMAGE_TAG" ]; then
    ELASTICSEARCH_IMAGE_TAG="$DEPLOYMENT_ELASTICSEARCH_IMAGE_TAG"
  else
    ELASTICSEARCH_IMAGE_TAG="$DEPLOYMENT_DEFAULT_ELASTICSEARCH_IMAGE_TAG"
  fi
  export ELASTICSEARCH_IMAGE_TAG
  if [ "$DEPLOYMENT_ELASTICSEARCH_REPLICAS" ]; then
    ELASTICSEARCH_REPLICAS="$DEPLOYMENT_ELASTICSEARCH_REPLICAS"
  else
    ELASTICSEARCH_REPLICAS="$DEPLOYMENT_DEFAULT_ELASTICSEARCH_REPLICAS"
  fi
  export ELASTICSEARCH_REPLICAS
  if [ "$DEPLOYMENT_ELASTICSEARCH_JAVAOPTS" ]; then
    ELASTICSEARCH_JAVAOPTS="$DEPLOYMENT_ELASTICSEARCH_JAVAOPTS"
  else
    ELASTICSEARCH_JAVAOPTS="$DEPLOYMENT_DEFAULT_ELASTICSEARCH_JAVAOPTS"
  fi
  export ELASTICSEARCH_JAVAOPTS
  if [ "$DEPLOYMENT_ELASTICSEARCH_CPU_REQUESTS" ]; then
    ELASTICSEARCH_CPU_REQUESTS="$DEPLOYMENT_ELASTICSEARCH_CPU_REQUESTS"
  else
    ELASTICSEARCH_CPU_REQUESTS="$DEPLOYMENT_DEFAULT_ELASTICSEARCH_CPU_REQUESTS"
  fi
  export ELASTICSEARCH_CPU_REQUESTS
  if [ "$DEPLOYMENT_ELASTICSEARCH_MEM_REQUESTS" ]; then
    ELASTICSEARCH_MEM_REQUESTS="$DEPLOYMENT_ELASTICSEARCH_MEM_REQUESTS"
  else
    ELASTICSEARCH_MEM_REQUESTS="$DEPLOYMENT_DEFAULT_ELASTICSEARCH_MEM_REQUESTS"
  fi
  export ELASTICSEARCH_MEM_REQUESTS
  if [ "$DEPLOYMENT_ELASTICSEARCH_STORAGE_CLASS" ]; then
    ELASTICSEARCH_STORAGE_CLASS="$DEPLOYMENT_ELASTICSEARCH_STORAGE_CLASS"
  else
    _storage_class="$DEPLOYMENT_DEFAULT_ELASTICSEARCH_STORAGE_CLASS"
    ELASTICSEARCH_STORAGE_CLASS="$_storage_class"
  fi
  export ELASTICSEARCH_STORAGE_CLASS
  if [ "$DEPLOYMENT_ELASTICSEARCH_STORAGE_SIZE" ]; then
    ELASTICSEARCH_STORAGE_SIZE="$DEPLOYMENT_ELASTICSEARCH_STORAGE_SIZE"
  else
    ELASTICSEARCH_STORAGE_SIZE="$DEPLOYMENT_DEFAULT_ELASTICSEARCH_STORAGE_SIZE"
  fi
  export ELASTICSEARCH_STORAGE_SIZE
  if [ "$DEPLOYMENT_ELASTICSEARCH_PF_PORT" ]; then
    ELASTICSEARCH_PF_PORT="$DEPLOYMENT_ELASTICSEARCH_PF_PORT"
  else
    ELASTICSEARCH_PF_PORT="$DEPLOYMENT_DEFAULT_ELASTICSEARCH_PF_PORT"
  fi
  export ELASTICSEARCH_PF_PORT
  __apps_elasticsearch_export_variables="1"
}

apps_elasticsearch_check_directories() {
  apps_common_check_directories
  for _d in "$ELASTICSEARCH_HELM_DIR" "$ELASTICSEARCH_KUBECTL_DIR" \
    "$ELASTICSEARCH_SECRETS_DIR" "$ELASTICSEARCH_PF_DIR"; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

apps_elasticsearch_clean_directories() {
  # Try to remove empty dirs, except if they contain secrets
  for _d in "$ELASTICSEARCH_HELM_DIR" "$ELASTICSEARCH_KUBECTL_DIR" \
    "$ELASTICSEARCH_SECRETS_DIR" "$ELASTICSEARCH_PF_DIR"; do
    if [ -d "$_d" ]; then
      rmdir "$_d" 2>/dev/null || true
    fi
  done
}

apps_elasticsearch_read_variables() {
  _app="elasticsearch"
  header "Reading $_app settings"
  read_value "Elasticsearch chart version" "$ELASTICSEARCH_CHART_VERSION"
  ELASTICSEARCH_CHART_VERSION=${READ_VALUE}
  read_value "Elasticsearch replicas (chart defaults to 3)" \
    "${ELASTICSEARCH_REPLICAS}"
  ELASTICSEARCH_REPLICAS=${READ_VALUE}
  read_value "Elasticsearch image name" "$ELASTICSEARCH_IMAGE_NAME"
  ELASTICSEARCH_IMAGE_NAME=${READ_VALUE}
  read_value "Elasticsearch image tag" "$ELASTICSEARCH_IMAGE_TAG"
  ELASTICSEARCH_IMAGE_TAG=${READ_VALUE}
  read_value "Elasticsearch java opts (i.e. -Xmx128m -Xms128m)" \
    "${ELASTICSEARCH_JAVAOPTS}"
  ELASTICSEARCH_JAVAOPTS=${READ_VALUE}
  read_value "Elasticsearch cpu request (i.e. 100m)" \
    "${ELASTICSEARCH_CPU_REQUESTS}"
  ELASTICSEARCH_CPU_REQUESTS=${READ_VALUE}
  read_value "Elasticsearch mem request (i.e. 500m)" \
    "${ELASTICSEARCH_MEM_REQUESTS}"
  ELASTICSEARCH_MEM_REQUESTS=${READ_VALUE}
  read_value "Elasticsearch storageClass ('local-storage' @ k3d, 'gp3' @ eks)" \
    "${ELASTICSEARCH_STORAGE_CLASS}"
  ELASTICSEARCH_STORAGE_CLASS=${READ_VALUE}
  read_value "Elasticsearch Storage Size" "${ELASTICSEARCH_STORAGE_SIZE}"
  ELASTICSEARCH_STORAGE_SIZE=${READ_VALUE}
  read_value "Fixed port for elasticsearch pf? (i.e. 9200 or '-' for random)" \
    "$ELASTICSEARCH_PF_PORT"
  ELASTICSEARCH_PF_PORT=${READ_VALUE}
}

apps_elasticsearch_print_variables() {
  _app="elasticsearch"
  cat <<EOF
# Deployment $_app settings
# ---
# Elasticsearch helm chart version
ELASTICSEARCH_CHART_VERSION=$ELASTICSEARCH_CHART_VERSION
# Elasticsearch replicas (chart defaults to 3)
ELASTICSEARCH_REPLICAS=$ELASTICSEARCH_REPLICAS
# Elasticsearch image name
ELASTICSEARCH_IMAGE_NAME=$ELASTICSEARCH_IMAGE_NAME
# Elasticsarch image tag
ELASTICSEARCH_IMAGE_TAG=$ELASTICSEARCH_IMAGE_TAG
# Elasticsearch java opts (chart defaults to empty)
ELASTICSEARCH_JAVAOPTS=$ELASTICSEARCH_JAVAOPTS
# Elasticsearch cpu request (chart defaults to 1000m)
ELASTICSEARCH_CPU_REQUESTS=$ELASTICSEARCH_CPU_REQUESTS
# Elasticsearch mem request (chart defaults to 2Gi)
ELASTICSEARCH_MEM_REQUESTS=$ELASTICSEARCH_MEM_REQUESTS
# Elasticsearch storageClass ('local-storage' @ k3d, 'gp3' @ eks)
ELASTICSEARCH_STORAGE_CLASS=$ELASTICSEARCH_STORAGE_CLASS
# Elasticsearch Volume Size (if storage is local or NFS the value is ignored)
ELASTICSEARCH_STORAGE_SIZE=$ELASTICSEARCH_STORAGE_SIZE
# Fixed port for elasticsearch pf (standard is 9200, empty for random)
ELASTICSEARCH_PF_PORT=$ELASTICSEARCH_PF_PORT
# ---
EOF
}

apps_elasticsearch_logs() {
  _deployment="$1"
  _cluster="$2"
  apps_elasticsearch_export_variables "$_deployment" "$_cluster"
  _app="elasticsearch"
  _ns="$ELASTICSEARCH_NAMESPACE"
  if kubectl get -n "$_ns" "statefulset/$_app-master" >/dev/null 2>&1; then
    kubectl -n "$_ns" logs "statefulset/$_app-master" -f
  else
    echo "Statefulset '$_app-master' not found on namespace '$_ns'"
  fi
}

apps_elasticsearch_sh() {
  _deployment="$1"
  _cluster="$2"
  apps_elasticsearch_export_variables "$_deployment" "$_cluster"
  _app="elasticsearch"
  _ns="$ELASTICSEARCH_NAMESPACE"
  if kubectl get -n "$_ns" "statefulset/$_app-master" >/dev/null 2>&1; then
    kubectl -n "$_ns" exec -ti "statefulset/$_app-master" -- /bin/sh
  else
    echo "Statefulset '$_app-master' not found on namespace '$_ns'"
  fi
}

apps_elasticsearch_install() {
  _deployment="$1"
  _cluster="$2"
  apps_elasticsearch_export_variables "$_deployment" "$_cluster"
  apps_elasticsearch_check_directories
  _app="elasticsearch"
  _ns="$ELASTICSEARCH_NAMESPACE"
  _helm_values_tmpl="$ELASTICSEARCH_HELM_VALUES_TMPL"
  _helm_values_yaml="$ELASTICSEARCH_HELM_VALUES_YAML"
  _pvc_tmpl="$ELASTICSEARCH_PVC_TMPL"
  _pvc_yaml="$ELASTICSEARCH_PVC_YAML"
  _pv_tmpl="$ELASTICSEARCH_PV_TMPL"
  _pv_yaml="$ELASTICSEARCH_PV_YAML"
  _release="$ELASTICSEARCH_HELM_RELEASE"
  _chart="$ELASTICSEARCH_HELM_CHART"
  _version="$ELASTICSEARCH_CHART_VERSION"
  _storage_class="$ELASTICSEARCH_STORAGE_CLASS"
  _storage_size="$ELASTICSEARCH_STORAGE_SIZE"
  # Replace storage class or remove the line
  if [ "$_storage_class" ]; then
    _storage_class_sed="s%__STORAGE_CLASS__%$_storage_class%"
  else
    _storage_class_sed="/__STORAGE_CLASS__/d;"
  fi
  # Prepare values for helm
  sed \
    -e "s%__REPLICAS__%$ELASTICSEARCH_REPLICAS%" \
    -e "s%__IMAGE__%$ELASTICSEARCH_IMAGE_NAME%" \
    -e "s%__JAVAOPTS__%$ELASTICSEARCH_JAVAOPTS%" \
    -e "s%__CPU_REQUESTS__%$ELASTICSEARCH_CPU_REQUESTS%" \
    -e "s%__MEM_REQUESTS__%$ELASTICSEARCH_MEM_REQUESTS%" \
    -e "s%__STORAGE_SIZE__%$_storage_size%" \
    -e "$_storage_class_sed" \
    "$_helm_values_tmpl" | stdout_to_file "$_helm_values_yaml"
  # Check helm repo
  check_helm_repo "$ELASTICSEARCH_HELM_REPO_NAME" "$ELASTICSEARCH_HELM_REPO_URL"
  # Create namespace if needed
  if ! find_namespace "$_ns"; then
    create_namespace "$_ns"
  fi
  # Pre-create directories if needed and adjust storage_sed
  if [ "$_storage_class" = "local-storage" ] &&
    is_selected "$CLUSTER_USE_LOCAL_STORAGE"; then
    for i in $(seq 0 $((ELASTICSEARCH_REPLICAS - 1))); do
      _pv_name="$ELASTICSEARCH_PV_PREFIX-$DEPLOYMENT_NAME-$i"
      test -d "$CLUST_VOLUMES_DIR/$_pv_name" ||
        mkdir "$CLUST_VOLUMES_DIR/$_pv_name"
    done
    _storage_sed="$_storage_class_sed"
    # Create PVs
    for i in $(seq 0 $((ELASTICSEARCH_REPLICAS - 1))); do
      _pvc_name="$ELASTICSEARCH_PV_PREFIX-$i"
      _pv_name="$ELASTICSEARCH_PV_PREFIX-$DEPLOYMENT_NAME-$i"
      _pv_yaml="$ELASTICSEARCH_KUBECTL_DIR/pv-$i.yaml"
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
find "$ELASTICSEARCH_KUBECTL_DIR" -name "pvc-*.yaml"
EOF
  fi
  # Create PVCs
  for i in $(seq 0 $((ELASTICSEARCH_REPLICAS - 1))); do
    _pvc_name="$ELASTICSEARCH_PV_PREFIX-$i"
    _pvc_yaml="$ELASTICSEARCH_KUBECTL_DIR/pvc-$i.yaml"
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
    -n "$_ns" "statefulset/elasticsearch-master"
  # Remove old PVCs
  i=1
  while read -r _yaml; do
    if [ "$i" -gt "$ELASTICSEARCH_REPLICAS" ]; then
      kubectl_delete "$_yaml" || true
    fi
    i="$((i + 1))"
  done <<EOF
$(find "$ELASTICSEARCH_KUBECTL_DIR" -name "pvc-*.yaml" | sort -n)
EOF
  # Remove old PVs
  i=1
  while read -r _yaml; do
    if [ "$i" -gt "$ELASTICSEARCH_REPLICAS" ]; then
      kubectl_delete "$_yaml" || true
    fi
    i="$((i + 1))"
  done <<EOF
$(find "$ELASTICSEARCH_KUBECTL_DIR" -name "pv-*.yaml" | sort -n)
EOF
}

apps_elasticsearch_helm_history() {
  _deployment="$1"
  _cluster="$2"
  apps_elasticsearch_export_variables "$_deployment" "$_cluster"
  _app="elasticsearch"
  _ns="$ELASTICSEARCH_NAMESPACE"
  _release="$ELASTICSEARCH_HELM_RELEASE"
  if find_namespace "$_ns"; then
    helm_history "$_ns" "$_release"
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

apps_elasticsearch_helm_rollback() {
  _deployment="$1"
  _cluster="$2"
  apps_elasticsearch_export_variables "$_deployment" "$_cluster"
  _app="elasticsearch"
  _ns="$ELASTICSEARCH_NAMESPACE"
  _release="$ELASTICSEARCH_HELM_RELEASE"
  _rollback_release="$ROLLBACK_RELEASE"
  if find_namespace "$_ns"; then
    helm_rollback "$_ns" "$_release" "$_rollback_release"
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

apps_elasticsearch_remove() {
  _deployment="$1"
  _cluster="$2"
  apps_elasticsearch_export_variables "$_deployment" "$_cluster"
  _app="elasticsearch"
  _ns="$ELASTICSEARCH_NAMESPACE"
  _values_yaml="$ELASTICSEARCH_HELM_VALUES_YAML"
  _release="$ELASTICSEARCH_HELM_RELEASE"
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
$(find "$ELASTICSEARCH_KUBECTL_DIR" -name "pvc-*.yaml")
EOF
    # Remove PVs
    while read -r _yaml; do
      kubectl_delete "$_yaml" || true
    done <<EOF
$(find "$ELASTICSEARCH_KUBECTL_DIR" -name "pv-*.yaml")
EOF
    # Delete namespace if there are no charts deployed
    if [ -z "$(helm list -n "$_ns" -q)" ]; then
      delete_namespace "$_ns"
    fi
    footer
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
  apps_elasticsearch_clean_directories
}

apps_elasticsearch_rmvols() {
  _deployment="$1"
  _cluster="$2"
  apps_elasticsearch_export_variables "$_deployment" "$_cluster"
  _ns="$ELASTICSEARCH_NAMESPACE"
  if find_namespace "$_ns"; then
    echo "Namespace '$_ns' found, not removing volumes!"
  else
    _dirs="$(
      find "$CLUST_VOLUMES_DIR" -maxdepth 1 -type d \
        -name "$ELASTICSEARCH_PV_PREFIX-*" -printf "- %f\n"
    )"
    if [ "$_dirs" ]; then
      echo "Removing directories:"
      echo "$_dirs"
      find "$CLUST_VOLUMES_DIR" -maxdepth 1 -type d \
        -name "$ELASTICSEARCH_PV_PREFIX-*" -exec sudo rm -rf {} \;
    fi
  fi
}

apps_elasticsearch_status() {
  _deployment="$1"
  _cluster="$2"
  apps_elasticsearch_export_variables "$_deployment" "$_cluster"
  _app="elasticsearch"
  _ns="$ELASTICSEARCH_NAMESPACE"
  if find_namespace "$_ns"; then
    kubectl get all,endpoints,ingress,secrets -n "$_ns"
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

apps_elasticsearch_summary() {
  _deployment="$1"
  _cluster="$2"
  apps_elasticsearch_export_variables "$_deployment" "$_cluster"
  _addon="elasticsearch"
  _ns="$ELASTICSEARCH_NAMESPACE"
  _release="$ELASTICSEARCH_HELM_RELEASE"
  print_helm_summary "$_ns" "$_addon" "$_release"
  statefulset_helm_summary "$_ns" "elasticsearch-master"
}

apps_elasticsearch_env_edit() {
  if [ "$EDITOR" ]; then
    _app="elasticsearch"
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

apps_elasticsearch_env_path() {
  _app="elasticsearch"
  _deployment="$1"
  _cluster="$2"
  apps_export_variables "$_deployment" "$_cluster"
  _env_file="$DEPLOY_ENVS_DIR/$_app.env"
  echo "$_env_file"
}

apps_elasticsearch_env_save() {
  _app="elasticsearch"
  _deployment="$1"
  _cluster="$2"
  _env_file="$3"
  apps_elasticsearch_check_directories
  apps_elasticsearch_print_variables "$_deployment" "$_cluster" |
    stdout_to_file "$_env_file"
}

apps_elasticsearch_env_update() {
  _app="elasticsearch"
  _deployment="$1"
  _cluster="$2"
  apps_export_variables "$_deployment" "$_cluster"
  _env_file="$DEPLOY_ENVS_DIR/$_app.env"
  header "$_app configuration variables"
  apps_elasticsearch_print_variables "$_deployment" "$_cluster" |
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
    apps_elasticsearch_read_variables
    if [ -f "$_env_file" ]; then
      footer
      read_bool "Save updated $_app env vars?" "Yes"
    else
      READ_VALUE="Yes"
    fi
    if is_selected "${READ_VALUE}"; then
      apps_elasticsearch_env_save "$_deployment" "$_cluster" "$_env_file"
      footer
      echo "$_app configuration saved to '$_env_file'"
      footer
    fi
  fi
}

apps_elasticsearch_command() {
  _command="$1"
  _deployment="$2"
  _cluster="$3"
  case "$_command" in
  env-edit | env_edit)
    apps_elasticsearch_env_edit "$_deployment" "$_cluster"
    ;;
  env-path | env_path)
    apps_elasticsearch_env_path "$_deployment" "$_cluster"
    ;;
  env-show | env_show)
    apps_elasticsearch_print_variables "$_deployment" "$_cluster" | grep -v '^#'
    ;;
  env-update | env_update)
    apps_elasticsearch_env_update "$_deployment" "$_cluster"
    ;;
  helm-history) apps_elasticsearch_helm_history "$_deployment" "$_cluster" ;;
  helm-rollback) apps_elasticsearch_helm_rollback "$_deployment" "$_cluster" ;;
  install) apps_elasticsearch_install "$_deployment" "$_cluster" ;;
  logs) apps_elasticsearch_logs "$_deployment" "$_cluster" ;;
  remove) apps_elasticsearch_remove "$_deployment" "$_cluster" ;;
  rmvols) apps_elasticsearch_rmvols "$_deployment" "$_cluster" ;;
  sh) apps_elasticsearch_sh "$_deployment" "$_cluster" ;;
  status) apps_elasticsearch_status "$_deployment" "$_cluster" ;;
  summary) apps_elasticsearch_summary "$_deployment" "$_cluster" ;;
  *)
    echo "Unknown elasticsearch subcommand '$1'"
    exit 1
    ;;
  esac
}

apps_elasticsearch_command_list() {
  _cmnds="env-edit env-path env-show env-update helm-history helm-rollback"
  _cmnds="$_cmnds install logs remove rmvols sh status summary"
  echo "$_cmnds"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
