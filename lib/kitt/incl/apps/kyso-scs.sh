#!/bin/sh
# ----
# File:        apps/kyso-scs.sh
# Description: Functions to manage kyso-scs deployments for kyso on k8s clusters
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_APPS_KYSO_SCS_SH="1"

# ---------
# Variables
# ---------

# CMND_DSC="kyso-scs: manage kyso-scs deployment for kyso"

# Defaults
_myssh_image="registry.kyso.io/docker/mysecureshell:latest"
export DEPLOYMENT_DEFAULT_KYSO_SCS_MYSSH_IMAGE="$_myssh_image"
_nginx_image="registry.kyso.io/docker/nginx-scs:latest"
export DEPLOYMENT_DEFAULT_KYSO_SCS_NGINX_IMAGE="$_nginx_image"
export DEPLOYMENT_DEFAULT_KYSO_INDEXER_IMAGE=""
export DEPLOYMENT_DEFAULT_KYSO_SCS_REPLICAS="1"
export DEPLOYMENT_DEFAULT_KYSO_SCS_MYSSH_PF_PORT=""
export DEPLOYMENT_DEFAULT_KYSO_SCS_STORAGE_CLASS=""
export DEPLOYMENT_DEFAULT_KYSO_SCS_STORAGE_SIZE="10Gi"
export DEPLOYMENT_DEFAULT_KYSO_SCS_RESTIC_BACKUP="false"

# Fixed values
export KYSO_SCS_USER="scs"
export KYSO_SCS_API_AUTH_EP="auth/check-permissions"
export KYSO_SCS_SECRETS_NAME="kyso-scs-secrets"

# --------
# Includes
# --------

if [ -d "$INCL_DIR" ]; then
  # shellcheck source=../common.sh
  [ "$INCL_COMMON_SH" = "1" ] || . "$INCL_DIR/common.sh"
  # shellcheck source=./common.sh
  [ "$INCL_APPS_COMMON_SH" = "1" ] || . "$INCL_DIR/apps/common.sh"
  # shellcheck source=./kyso-api.sh
  [ "$INCL_APPS_KYSO_API_SH" = "1" ] || . "$INCL_DIR/apps/kyso-api.sh"
  # shellcheck source=./elasticsearch.sh
  [ "$INCL_APPS_ELASTICSEARCH_SH" = "1" ] || . "$INCL_DIR/apps/elasticsearch.sh"
  # shellcheck source=../mongo.sh
  [ "$INCL_MONGO_SH" = "1" ] || . "$INCL_DIR/mongo.sh"
fi

# ---------
# Functions
# ---------

apps_kyso_scs_export_variables() {
  [ -z "$__apps_kyso_scs_export_variables" ] || return 0
  _deployment="$1"
  _cluster="$2"
  apps_common_export_variables "$_deployment" "$_cluster"
  apps_elasticsearch_export_variables "$_deployment" "$_cluster"
  # Values
  export KYSO_SCS_NAMESPACE="kyso-scs-$DEPLOYMENT_NAME"
  # Directories
  export KYSO_SCS_TMPL_DIR="$TMPL_DIR/apps/kyso-scs"
  export KYSO_SCS_KUBECTL_DIR="$DEPLOY_KUBECTL_DIR/kyso-scs"
  export KYSO_SCS_SECRETS_DIR="$DEPLOY_SECRETS_DIR/kyso-scs"
  export KYSO_SCS_PF_DIR="$DEPLOY_PF_DIR/kyso-scs"
  # Templates
  export KYSO_SCS_STATEFULSET_TMPL="$KYSO_SCS_TMPL_DIR/statefulset.yaml"
  export KYSO_SCS_PVC_TMPL="$KYSO_SCS_TMPL_DIR/pvc.yaml"
  export KYSO_SCS_PV_TMPL="$KYSO_SCS_TMPL_DIR/pv.yaml"
  export KYSO_SCS_SECRET_TMPL="$KYSO_SCS_TMPL_DIR/secrets.yaml"
  export KYSO_SCS_SERVICE_TMPL="$KYSO_SCS_TMPL_DIR/service.yaml"
  export KYSO_SCS_INGRESS_TMPL="$KYSO_SCS_TMPL_DIR/ingress.yaml"
  export \
    KYSO_SCS_INDEXER_APP_YAML_TMPL="$KYSO_SCS_TMPL_DIR/indexer-application.yaml"
  # Files
  export KYSO_SCS_DEPLOY_YAML="$KYSO_SCS_KUBECTL_DIR/deploy.yaml"
  export KYSO_SCS_STATEFULSET_YAML="$KYSO_SCS_KUBECTL_DIR/statefulset.yaml"
  export KYSO_SCS_INGRESS_YAML="$KYSO_SCS_KUBECTL_DIR/ingress.yaml"
  export KYSO_SCS_SECRET_YAML="$KYSO_SCS_SECRETS_DIR/secrets$SOPS_EXT.yaml"
  export KYSO_SCS_SERVICE_YAML="$KYSO_SCS_KUBECTL_DIR/service.yaml"
  export KYSO_SCS_PVC_YAML="$KYSO_SCS_KUBECTL_DIR/pvc.yaml"
  export KYSO_SCS_PV_YAML="$KYSO_SCS_KUBECTL_DIR/pv.yaml"
  export KYSO_SCS_MYSSH_PF_OUT="$KYSO_SCS_PF_DIR/kubectl-sftp.out"
  export KYSO_SCS_MYSSH_PF_PID="$KYSO_SCS_PF_DIR/kubectl-sftp.pid"
  export KYSO_SCS_HOST_KEYS="$KYSO_SCS_SECRETS_DIR/host_keys$SOPS_EXT.txt"
  export KYSO_SCS_USERS_TAR="$KYSO_SCS_SECRETS_DIR/user_data$SOPS_EXT.tar"
  export KYSO_SCS_INDEXER_CONFIGMAP_YAML="$KYSO_SCS_KUBECTL_DIR/configmap.yaml"
  # Use defaults for variables missing from config files / enviroment
  if [ -z "$KYSO_SCS_MYSSH_IMAGE" ]; then
    if [ "$DEPLOYMENT_KYSO_SCS_MYSSH_IMAGE" ]; then
      KYSO_SCS_MYSSH_IMAGE="$DEPLOYMENT_KYSO_SCS_MYSSH_IMAGE"
    else
      KYSO_SCS_MYSSH_IMAGE="$DEPLOYMENT_DEFAULT_KYSO_SCS_MYSSH_IMAGE"
    fi
  fi
  export KYSO_SCS_MYSSH_IMAGE
  if [ -z "$KYSO_SCS_NGINX_IMAGE" ]; then
    if [ "$DEPLOYMENT_KYSO_SCS_NGINX_IMAGE" ]; then
      KYSO_SCS_NGINX_IMAGE="$DEPLOYMENT_KYSO_SCS_NGINX_IMAGE"
    else
      KYSO_SCS_NGINX_IMAGE="$DEPLOYMENT_DEFAULT_KYSO_SCS_NGINX_IMAGE"
    fi
  fi
  export KYSO_SCS_NGINX_IMAGE
  if [ -z "$KYSO_INDEXER_IMAGE" ]; then
    if [ "$DEPLOYMENT_KYSO_INDEXER_IMAGE" ]; then
      KYSO_INDEXER_IMAGE="$DEPLOYMENT_KYSO_INDEXER_IMAGE"
    else
      KYSO_INDEXER_IMAGE="$DEPLOYMENT_DEFAULT_KYSO_INDEXER_IMAGE"
    fi
  fi
  export KYSO_INDEXER_IMAGE
  if [ "$DEPLOYMENT_KYSO_SCS_REPLICAS" ]; then
    KYSO_SCS_REPLICAS="$DEPLOYMENT_KYSO_SCS_REPLICAS"
  else
    KYSO_SCS_REPLICAS="$DEPLOYMENT_DEFAULT_KYSO_SCS_REPLICAS"
  fi
  export KYSO_SCS_REPLICAS
  if [ "$DEPLOYMENT_KYSO_SCS_STORAGE_CLASS" ]; then
    KYSO_SCS_STORAGE_CLASS="$DEPLOYMENT_KYSO_SCS_STORAGE_CLASS"
  else
    _storage_class="$DEPLOYMENT_DEFAULT_KYSO_SCS_STORAGE_CLASS"
    KYSO_SCS_STORAGE_CLASS="$_storage_class"
  fi
  export KYSO_SCS_STORAGE_CLASS
  if [ "$DEPLOYMENT_KYSO_SCS_STORAGE_SIZE" ]; then
    KYSO_SCS_STORAGE_SIZE="$DEPLOYMENT_KYSO_SCS_STORAGE_SIZE"
  else
    KYSO_SCS_STORAGE_SIZE="$DEPLOYMENT_DEFAULT_KYSO_SCS_STORAGE_SIZE"
  fi
  export KYSO_SCS_STORAGE_SIZE
  if [ "$DEPLOYMENT_KYSO_SCS_RESTIC_BACKUP" ]; then
    KYSO_SCS_RESTIC_BACKUP="$DEPLOYMENT_KYSO_SCS_RESTIC_BACKUP"
  else
    KYSO_SCS_RESTIC_BACKUP="$DEPLOYMENT_DEFAULT_KYSO_SCS_RESTIC_BACKUP"
  fi
  export KYSO_SCS_RESTIC_BACKUP
  if [ "$DEPLOYMENT_KYSO_SCS_MYSSH_PF_PORT" ]; then
    KYSO_SCS_MYSSH_PF_PORT="$DEPLOYMENT_KYSO_SCS_MYSSH_PF_PORT"
  else
    KYSO_SCS_MYSSH_PF_PORT="$DEPLOYMENT_DEFAULT_KYSO_SCS_MYSSH_PF_PORT"
  fi
  export KYSO_SCS_MYSSH_PF_PORT
  __apps_kyso_scs_export_variables="1"
}

apps_kyso_scs_check_directories() {
  apps_common_check_directories
  for _d in "$KYSO_SCS_KUBECTL_DIR" "$KYSO_SCS_SECRETS_DIR" \
    "$KYSO_SCS_PF_DIR"; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

apps_kyso_scs_clean_directories() {
  # Try to remove empty dirs, except if they contain secrets
  for _d in "$KYSO_SCS_KUBECTL_DIR" "$KYSO_SCS_SECRETS_DIR" \
    "$KYSO_SCS_PF_DIR"; do
    if [ -d "$_d" ]; then
      rmdir "$_d" 2>/dev/null || true
    fi
  done
}

apps_kyso_scs_create_myssh_secrets() {
  _ns="$KYSO_SCS_NAMESPACE"
  output_file="$1"
  if [ ! -f "$KYSO_SCS_HOST_KEYS" ]; then
    ret="0"
    kubectl run --namespace "$_ns" "mysecureshell" \
      --restart='Never' --quiet --rm --stdin --image "$KYSO_SCS_MYSSH_IMAGE" \
      -- host-keys | stdout_to_file "$KYSO_SCS_HOST_KEYS" || ret="$?"
    if [ "$ret" -ne "0" ]; then
      rm -f "$KYSO_SCS_HOST_KEYS"
      return "$ret"
    fi
  fi
  if [ ! -f "$KYSO_SCS_USERS_TAR" ]; then
    ret="0"
    kubectl run --namespace "$_ns" "mysecureshell" \
      --restart='Never' --quiet --rm --stdin --image "$KYSO_SCS_MYSSH_IMAGE" \
      -- users-tar "$KYSO_SCS_USER" | stdout_to_file "$KYSO_SCS_USERS_TAR" ||
      ret="$?"
    if [ "$ret" -ne "0" ]; then
      rm -f "$KYSO_SCS_USERS_TAR"
      return "$ret"
    fi
  fi
  # Prepare plain versions of files
  _tmp_dir="$(mktemp -d)"
  chmod 0700 "$_tmp_dir"
  host_keys_plain="$_tmp_dir/host_keys_plain.txt"
  user_keys_plain="$_tmp_dir/user_keys_plain.txt"
  user_pass_plain="$_tmp_dir/user_pass_plain.txt"
  file_to_stdout "$KYSO_SCS_HOST_KEYS" >"$host_keys_plain"
  file_to_stdout "$KYSO_SCS_USERS_TAR" |
    tar -xOf - user_keys.txt >"$user_keys_plain"
  file_to_stdout "$KYSO_SCS_USERS_TAR" |
    tar -xOf - user_pass.txt >"$user_pass_plain"
  kubectl --dry-run=client -o yaml create secret generic --namespace "$_ns" \
    "$KYSO_SCS_SECRETS_NAME" \
    --from-file="host_keys.txt=$host_keys_plain" \
    --from-file="user_keys.txt=$user_keys_plain" \
    --from-file="user_pass.txt=$user_pass_plain" |
    stdout_to_file "$output_file"
  rm -rf "$_tmp_dir"
}

apps_kyso_scs_update_api_settings() {
  ret="0"
  _deployment="$1"
  _cluster="$2"
  apps_kyso_scs_export_variables "$_deployment" "$_cluster"
  _tmp_dir="$(mktemp -d)"
  chmod 0700 "$_tmp_dir"
  _settings_csv="$_tmp_dir/KysoSettings.csv"
  _settings_err="$_tmp_dir/KysoSettings.err"
  _settings_new="$_tmp_dir/KysoSettings.new"
  mongo_command settings-export "$_settings_csv" "$_deployment" "$_cluster" \
    2>"$_settings_err" || ret="$?"
  if [ "$ret" -ne "0" ]; then
    cat "$_settings_err" 1>&2
    rm -rf "$_tmp_dir"
    return "$ret"
  fi
  _base_url="https://${DEPLOYMENT_HOSTNAMES%% *}"
  _frontend_url="https://${DEPLOYMENT_HOSTNAMES%% *}"
  _sftp_host="kyso-scs-svc.$KYSO_SCS_NAMESPACE.svc.cluster.local"
  _sftp_port="22"
  _kyso_indexer_api_host="kyso-scs-svc.$KYSO_SCS_NAMESPACE.svc.cluster.local"
  _kyso_indexer_api_base_url="http://$_kyso_indexer_api_host:8080"
  if [ -f "$KYSO_SCS_USERS_TAR" ]; then
    _user_and_pass="$(
      file_to_stdout "$KYSO_SCS_USERS_TAR" | tar xOf - user_pass.txt
    )"
    _sftp_username="$(echo "$_user_and_pass" | cut -d':' -f1)"
    _sftp_password="$(echo "$_user_and_pass" | cut -d':' -f2)"
  else
    _sftp_username=""
    _sftp_password=""
  fi
  _sftp_destination_folder=""
  _static_content_prefix="/scs"
  sed \
    -e "s%^\(BASE_URL\),.*%\1,$_base_url%" \
    -e "s%^\(FRONTEND_URL\),.*%\1,$_frontend_url%" \
    -e "s%^\(SFTP_HOST\),.*$%\1,$_sftp_host%" \
    -e "s%^\(SFTP_PORT\),.*$%\1,$_sftp_port%" \
    -e "s%^\(SFTP_USERNAME\),.*$%\1,$_sftp_username%" \
    -e "s%^\(SFTP_PASSWORD\),.*$%\1,$_sftp_password%" \
    -e "s%^\(SFTP_DESTINATION_FOLDER\),.*$%\1,$_sftp_destination_folder%" \
    -e "s%^\(STATIC_CONTENT_PREFIX\),.*$%\1,$_static_content_prefix%" \
    -e "s%^\(KYSO_INDEXER_API_BASE_URL\),.*$%\1,$_kyso_indexer_api_base_url%" \
    "$_settings_csv" >"$_settings_new"
  DIFF_OUT="$(diff -U 0 "$_settings_csv" "$_settings_new")" || true
  if [ "$DIFF_OUT" ]; then
    echo "Updating KysoSettings:"
    echo "$DIFF_OUT" | grep '^[-+][^-+]'
    mongo_command settings-merge "$_settings_new" 2>"$_settings_err" || ret="$?"
    if [ "$ret" -ne "0" ]; then
      cat "$_settings_err" 1>&2
    fi
  fi
  rm -rf "$_tmp_dir"
  return "$ret"
}

apps_kyso_scs_read_variables() {
  header "Kyso SCS Settings"
  read_value "MySecureShell Image URI" "${KYSO_SCS_MYSSH_IMAGE}"
  KYSO_SCS_MYSSH_IMAGE=${READ_VALUE}
  read_value "Nginx Image URI" "${KYSO_SCS_NGINX_IMAGE}"
  KYSO_SCS_NGINX_IMAGE=${READ_VALUE}
  _ex_img="registry.kyso.io/kyso-io/kyso-indexer/develop:latest"
  read_value \
    "Indexer Image URI (i.e. '$_ex_img' or export KYSO_INDEXER_IMAGE env var)" \
    "${KYSO_INDEXER_IMAGE}"
  KYSO_INDEXER_IMAGE=${READ_VALUE}
  read_value "SCS Replicas" "${KYSO_SCS_REPLICAS}"
  KYSO_SCS_REPLICAS=${READ_VALUE}
  read_value "Kyso SCS Storage Class ('local-storage' @ k3d, 'efs-sc' @ eks)" \
    "${KYSO_SCS_STORAGE_CLASS}"
  KYSO_SCS_STORAGE_CLASS=${READ_VALUE}
  read_value "Kyso SCS Volume Size" "${KYSO_SCS_STORAGE_SIZE}"
  KYSO_SCS_STORAGE_SIZE=${READ_VALUE}
  read_bool "Kyso SCS backups use restic" "${KYSO_SCS_RESTIC_BACKUP}"
  KYSO_SCS_RESTIC_BACKUP=${READ_VALUE}
  read_value "Fixed port for mysecureshell pf? (i.e. 2020 or '-' for random)" \
    "${KYSO_MYSSH_PF_PORT}"
  KYSO_MYSSH_PF_PORT=${READ_VALUE}
}

apps_kyso_scs_print_variables() {
  cat <<EOF
# Kyso SCS Settings
# ---
# Kyso SCS MySecureShell Image URI
KYSO_SCS_MYSSH_IMAGE=$KYSO_SCS_MYSSH_IMAGE
# Kyso SCS Nginx Image URI
KYSO_SCS_NGINX_IMAGE=$KYSO_SCS_NGINX_IMAGE
# Indexer Image URI, examples for local testing:
# - 'registry.kyso.io/kyso-io/kyso-indexer/develop:latest'
# - 'k3d-registry.lo.kyso.io:5000/kyso-indexer:latest'
# If left empty the KYSO_INDEXER_IMAGE environment variable has to be set each
# time the kyso-scs service is installed
KYSO_INDEXER_IMAGE=$KYSO_INDEXER_IMAGE
# Number of pods to run in parallel (for more than 1 the volumes must be EFS)
KYSO_SCS_REPLICAS=$KYSO_SCS_REPLICAS
# Kyso SCS Storage Class ('local-storage' @ k3d, 'efs-sc' @ eks)
KYSO_SCS_STORAGE_CLASS=$KYSO_SCS_STORAGE_CLASS
# Kyso SCS Volume Size (if the storage is local or NFS the value is ignored)
KYSO_SCS_STORAGE_SIZE=$KYSO_SCS_STORAGE_SIZE
# Kyso SCS backups use restic (adds annotations to use it or not)
KYSO_SCS_RESTIC_BACKUP=$KYSO_SCS_RESTIC_BACKUP
# Fixed port for mysecureshell pf (recommended is 2020, random if empty)
KYSO_SCS_MYSSH_PF_PORT=$KYSO_SCS_MYSSH_PF_PORT
# ---
EOF
}

apps_kyso_scs_logs() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_scs_export_variables "$_deployment" "$_cluster"
  _ns="$KYSO_SCS_NAMESPACE"
  _label="app=kyso-scs"
  _container="kyso-indexer"
  kubectl -n "$_ns" logs -l "$_label" -c "$_container" -f
}

apps_kyso_scs_install() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_scs_export_variables "$_deployment" "$_cluster"
  if [ -z "$KYSO_INDEXER_IMAGE" ]; then
    echo "The INDEXER_IMAGE is empty."
    echo "Export KYSO_INDEXER_IMAGE or reconfigure."
    exit 1
  fi
  apps_kyso_scs_check_directories
  # Initial tests
  if ! find_namespace "$KYSO_API_NAMESPACE"; then
    read_bool "kyso-api namespace not found, abort install?" "Yes"
    if is_selected "${READ_VALUE}"; then
      return 1
    fi
  fi
  if ! find_namespace "$ELASTICSEARCH_NAMESPACE"; then
    read_bool "elasticsearch namespace not found, abort install?" "Yes"
    if is_selected "${READ_VALUE}"; then
      return 1
    fi
  fi
  _app="kyso-scs"
  _ns="$KYSO_SCS_NAMESPACE"
  _secret_yaml="$KYSO_SCS_SECRET_YAML"
  _pv_tmpl="$KYSO_SCS_PV_TMPL"
  _pv_yaml="$KYSO_SCS_PV_YAML"
  _pvc_tmpl="$KYSO_SCS_PVC_TMPL"
  _pvc_yaml="$KYSO_SCS_PVC_YAML"
  _pv_name="$_app-$DEPLOYMENT_NAME"
  _pvc_name="$_ns"
  _svc_tmpl="$KYSO_SCS_SERVICE_TMPL"
  _svc_yaml="$KYSO_SCS_SERVICE_YAML"
  # XXX: Legacy, remove once all scs deployments are statefulsets
  _deploy_yaml="$KYSO_SCS_DEPLOY_YAML"
  _statefulset_tmpl="$KYSO_SCS_STATEFULSET_TMPL"
  _statefulset_yaml="$KYSO_SCS_STATEFULSET_YAML"
  _ingress_tmpl="$KYSO_SCS_INGRESS_TMPL"
  _ingress_yaml="$KYSO_SCS_INGRESS_YAML"
  _storage_class="$KYSO_SCS_STORAGE_CLASS"
  _storage_size="$KYSO_SCS_STORAGE_SIZE"
  _indexer_app_yaml_tmpl="$KYSO_SCS_INDEXER_APP_YAML_TMPL"
  _indexer_configmap_name="kyso-indexer-config"
  _indexer_configmap_yaml="$KYSO_SCS_INDEXER_CONFIGMAP_YAML"
  _cert_yamls=""
  for _hostname in $DEPLOYMENT_HOSTNAMES; do
    _cert_yaml="$KYSO_SCS_KUBECTL_DIR/tls-$_hostname${SOPS_EXT}.yaml"
    _cert_yamls="$_cert_yamls $_cert_yaml"
  done
  if is_selected "$KYSO_SCS_RESTIC_BACKUP"; then
    _backup_action="backup-volumes"
  else
    _backup_action="backup-volumes-exclude"
  fi
  if ! find_namespace "$_ns"; then
    # Remove old files, just in case ...
    # shellcheck disable=SC2086
    rm -f "$_secret_yaml" "$_svc_yaml" "$_deploy_yaml" "$_ingress_yaml" \
      "$_statefulset_yaml" "$_indexer_configmap_yaml" $_cert_yamls
    # Create namespace
    create_namespace "$_ns"
  fi
  # Create certificate secrets if needed or remove them if not
  if is_selected "$DEPLOYMENT_INGRESS_TLS_CERTS"; then
    create_app_cert_yamls "$_ns" "$KYSO_SCS_KUBECTL_DIR"
  else
    for _hostname in $DEPLOYMENT_HOSTNAMES; do
      _cert_yaml="$KYSO_SCS_KUBECTL_DIR/tls-$_hostname${SOPS_EXT}.yaml"
      kubectl_delete "$_cert_yaml" || true
    done
  fi
  # Create secrets
  apps_kyso_scs_create_myssh_secrets "$_secret_yaml"
  # Replace storage class or remove the line
  if [ "$_storage_class" ]; then
    _storage_class_sed="s%__STORAGE_CLASS__%$_storage_class%"
  else
    _storage_class_sed="/__STORAGE_CLASS__/d;"
  fi
  # Pre-create directories if needed and adjust storage_sed
  if [ "$_storage_class" = "local-storage" ] &&
    is_selected "$CLUSTER_USE_LOCAL_STORAGE"; then
    test -d "$CLUST_VOLUMES_DIR/$_pv_name" ||
      mkdir "$CLUST_VOLUMES_DIR/$_pv_name"
    _storage_sed="$_storage_class_sed"
    :>"$_pv_yaml"
    sed \
      -e "s%__APP__%$_app%" \
      -e "s%__NAMESPACE__%$_ns%" \
      -e "s%__PV_NAME__%$_pv_name%" \
      -e "s%__PVC_NAME__%$_pvc_name%" \
      -e "s%__STORAGE_SIZE__%$_storage_size%" \
      -e "$_storage_sed" \
      "$_pv_tmpl" >>"$_pv_yaml"
    echo "---" >>"$_pv_yaml"
  else
    _storage_sed="/BEG: local-storage/,/END: local-storage/{d}"
    _storage_sed="$_storage_sed;$_storage_class_sed"
    kubectl_delete "$_pv_yaml" || true
  fi
  # Create PV & PVC
  :>"$_pvc_yaml"
  sed \
    -e "s%__APP__%$_app%" \
    -e "s%__NAMESPACE__%$_ns%" \
    -e "s%__PVC_NAME__%$_pvc_name%" \
    -e "s%__STORAGE_SIZE__%$_storage_size%" \
    -e "$_storage_sed" \
    "$_pvc_tmpl" >>"$_pvc_yaml"
  # Prepare service_yaml
  sed \
    -e "s%__APP__%$_app%" \
    -e "s%__NAMESPACE__%$_ns%" \
    "$_svc_tmpl" >"$_svc_yaml"
  # Create ingress definition
  create_app_ingress_yaml "$_ns" "$_app" "$_ingress_tmpl" "$_ingress_yaml" \
    "" ""
  # Create kyso-scs indexer configmap
  _elastic_url="http://elasticsearch-master.elasticsearch-$DEPLOYMENT_NAME"
  _elastic_url="$_elastic_url.svc.cluster.local:9200"
  _tmp_dir="$(mktemp -d)"
  chmod 0700 "$_tmp_dir"
  sed \
    -e "s%__ELASTIC_URL__%$_elastic_url%g" \
    "$_indexer_app_yaml_tmpl" > "$_tmp_dir/application.yaml"
  kubectl create configmap "$_indexer_configmap_name" --dry-run=client -o yaml \
    -n "$_ns" --from-file=application.yaml="$_tmp_dir/application.yaml" \
    >"$_indexer_configmap_yaml"
  rm -rf "$_tmp_dir"
  # Prepare statefulset file
  _kyso_api_host="kyso-api-svc.$KYSO_API_NAMESPACE.svc.cluster.local"
  if [ "$KYSO_SCS_API_AUTH_EP" ]; then
    _auth_request_uri="http://$_kyso_api_host/api/v1/$KYSO_SCS_API_AUTH_EP"
  else
    _auth_request_uri=""
  fi
  sed \
    -e "s%__APP__%$_app%" \
    -e "s%__NAMESPACE__%$_ns%" \
    -e "s%__BACKUP_ACTION__%$_backup_action%" \
    -e "s%__REPLICAS__%$KYSO_SCS_REPLICAS%" \
    -e "s%__SCS_MYSSH_IMAGE__%$KYSO_SCS_MYSSH_IMAGE%" \
    -e "s%__SCS_NGINX_IMAGE__%$KYSO_SCS_NGINX_IMAGE%" \
    -e "s%__INDEXER_IMAGE__%$KYSO_INDEXER_IMAGE%" \
    -e "s%__IMAGE_PULL_POLICY__%$DEPLOYMENT_IMAGE_PULL_POLICY%" \
    -e "s%__MYSSH_SECRET__%$KYSO_SCS_SECRETS_NAME%" \
    -e "s%__AUTH_REQUEST_URI__%$_auth_request_uri%" \
    -e "s%__PVC_NAME__%$_pvc_name%" \
    "$_statefulset_tmpl" >"$_statefulset_yaml"
  # Apply YAML files
  for _yaml in "$_secret_yaml" "$_pv_yaml" "$_pvc_yaml" \
    "$_indexer_configmap_yaml" "$_svc_yaml" "$_ingress_yaml" \
    $_cert_yamls; do
    kubectl_apply "$_yaml"
  done
  # Replace deployment with stateful set ... when we delete the deployment the
  # PVC is released and if we don't remove it the statefulset will use the same
  # one.
  kubectl_delete "$_deploy_yaml"
  kubectl_apply "$_statefulset_yaml"
  # Wait until statefulset succeds of fails
  kubectl rollout status statefulset --timeout="$ROLLOUT_STATUS_TIMEOUT" \
    -n "$_ns" "$_app"
  # Update settings
  apps_kyso_scs_update_api_settings
}

apps_kyso_scs_reinstall() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_scs_export_variables "$_deployment" "$_cluster"
  _app="kyso-scs"
  _ns="$KYSO_SCS_NAMESPACE"
  if find_namespace "$_ns"; then
    _cimages="$(statefulset_container_images "$_ns" "$_app")"
    _indexer_cname="kyso-indexer"
    KYSO_INDEXER_IMAGE="$(echo "$_cimages" | sed -ne "s/^$_indexer_cname //p")"
    _myssh_cname="myecureshell"
    KYSO_SCS_MYSSH_IMAGE="$(echo "$_cimages" | sed -ne "s/^$_myssh_cname //p")"
    _nginx_cname="nginx"
    KYSO_SCS_NGINX_IMAGE="$(echo "$_cimages" | sed -ne "s/^$_nginx_cname //p")"
    if [ "$KYSO_INDEXER_IMAGE" ] && [ "$KYSO_SCS_MYSSH_IMAGE" ] &&
      [ "$KYSO_SCS_NGINX_IMAGE" ]; then
      export KYSO_INDEXER_IMAGE
      export KYSO_SCS_MYSSH_IMAGE
      export KYSO_SCS_NGINX_IMAGE
      apps_kyso_scs_install "$_deployment" "$_cluster"
    else
      echo "Images for '$_app' on '$_ns' missing!"
    fi
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

apps_kyso_scs_remove() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_scs_export_variables "$_deployment" "$_cluster"
  _app="kyso-scs"
  _ns="$KYSO_SCS_NAMESPACE"
  _secret_yaml="$KYSO_SCS_SECRET_YAML"
  _svc_yaml="$KYSO_SCS_SVC_YAML"
  # XXX: Legacy, remove once all scs deployments are statefulsets
  _deploy_yaml="$KYSO_SCS_DEPLOY_YAML"
  _statefulset_yaml="$KYSO_SCS_STATEFULSET_YAML"
  _ingress_yaml="$KYSO_SCS_INGRESS_YAML"
  _indexer_configmap_yaml="$KYSO_SCS_INDEXER_CONFIGMAP_YAML"
  _cert_yamls=""
  for _hostname in $DEPLOYMENT_HOSTNAMES; do
    _cert_yaml="$KYSO_SCS_KUBECTL_DIR/tls-$_hostname${SOPS_EXT}.yaml"
    _cert_yamls="$_cert_yamls $_cert_yaml"
  done
  apps_kyso_scs_export_variables
  if find_namespace "$_ns"; then
    header "Removing '$_app' objects"
    for _yaml in "$_secret_yaml"  "$_statefulset_yaml" "$_deploy_yaml" \
      "$_indexer_configmap_yaml" "$_svc_yaml" "$_pvc_yaml" "$_pv_yaml" \
      "$_ingress_yaml" $_cert_yamls; do
      kubectl_delete "$_yaml" || true
    done
    delete_namespace "$_ns"
    footer
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
  apps_kyso_scs_clean_directories
}

apps_kyso_scs_restart() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_scs_export_variables "$_deployment" "$_cluster"
  _app="kyso-scs"
  _ns="$KYSO_SCS_NAMESPACE"
  if find_namespace "$_ns"; then
    statefulset_restart "$_ns" "$_app"
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

apps_kyso_scs_rmvols() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_scs_export_variables "$_deployment" "$_cluster"
  _app="kyso-scs"
  _ns="$KYSO_SCS_NAMESPACE"
  _pv_name="$_app-$DEPLOYMENT_NAME"
  if find_namespace "$_ns"; then
    echo "Namespace '$_ns' found, not removing volumes!"
  else
    _dirs="$(
      find "$CLUST_VOLUMES_DIR" -maxdepth 1 -type d \
        -name "$_pv_name" -printf "- %f\n"
    )"
    if [ "$_dirs" ]; then
      echo "Removing directories:"
      echo "$_dirs"
      find "$CLUST_VOLUMES_DIR" -maxdepth 1 -type d \
        -name "$_pv_name" -exec sudo rm -rf {} \;
    fi
  fi
}

apps_kyso_scs_status() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_scs_export_variables "$_deployment" "$_cluster"
  _app="kyso-scs"
  _ns="$KYSO_SCS_NAMESPACE"
  if find_namespace "$_ns"; then
    kubectl get all,endpoints,ingress,secrets -n "$_ns"
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

apps_kyso_scs_summary() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_scs_export_variables "$_deployment" "$_cluster"
  _ns="$KYSO_SCS_NAMESPACE"
  _app="kyso-scs"
  statefulset_summary "$_ns" "$_app"
}

apps_kyso_scs_command() {
  _command="$1"
  _deployment="$2"
  _cluster="$3"
  case "$_command" in
  logs) apps_kyso_scs_logs "$_deployment" "$_cluster" ;;
  install) apps_kyso_scs_install "$_deployment" "$_cluster" ;;
  reinstall) apps_kyso_scs_reinstall "$_deployment" "$_cluster" ;;
  remove) apps_kyso_scs_remove "$_deployment" "$_cluster" ;;
  rmvols) apps_kyso_scs_rmvols "$_deployment" "$_cluster" ;;
  restart) apps_kyso_scs_restart "$_deployment" "$_cluster" ;;
  settings) apps_kyso_scs_update_api_settings "$_deployment" "$_cluster" ;;
  status) apps_kyso_scs_status "$_deployment" "$_cluster" ;;
  summary) apps_kyso_scs_summary "$_deployment" "$_cluster" ;;
  *)
    echo "Unknown kyso-scs subcommand '$1'"
    exit 1
    ;;
  esac
}

apps_kyso_scs_command_list() {
  echo "logs install reinstall remove restart rmvols settings status summary"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
