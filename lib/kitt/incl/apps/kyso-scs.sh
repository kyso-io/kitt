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
export DEPLOYMENT_DEFAULT_KYSO_SCS_REPLICAS="1"
# Endpoints
export DEPLOYMENT_DEFAULT_KYSO_SCS_INDEXER_ENDPOINT=""
# Image settings
_hardlink_image="registry.kyso.io/docker/alpine:latest"
_indexer_image=""
_myssh_image="registry.kyso.io/docker/mysecureshell:latest"
_nginx_image="registry.kyso.io/docker/nginx-scs:latest"
_webhook_image="registry.kyso.io/docker/webhook-scs:latest"
export DEPLOYMENT_DEFAULT_KYSO_SCS_HARDLINK_CRONJOB_IMAGE="$_hardlink_image"
export DEPLOYMENT_DEFAULT_KYSO_SCS_INDEXER_IMAGE="$_indexer_image"
export DEPLOYMENT_DEFAULT_KYSO_SCS_MYSSH_IMAGE="$_myssh_image"
export DEPLOYMENT_DEFAULT_KYSO_SCS_NGINX_IMAGE="$_nginx_image"
export DEPLOYMENT_DEFAULT_KYSO_SCS_WEBHOOK_IMAGE="$_webhook_image"
# Cronjob settings
_schedule="0 0 * * *"
export DEPLOYMENT_DEFAULT_KYSO_SCS_HARDLINK_CRONJOB_SCHEDULE="$_schedule"
# Port forward settings
export DEPLOYMENT_DEFAULT_KYSO_SCS_INDEXER_PF_PORT=""
export DEPLOYMENT_DEFAULT_KYSO_SCS_MYSSH_PF_PORT=""
export DEPLOYMENT_DEFAULT_KYSO_SCS_WEBHOOK_PF_PORT=""
# Storage settings
export DEPLOYMENT_DEFAULT_KYSO_SCS_STORAGE_ACCESS_MODES="ReadWriteOnce"
export DEPLOYMENT_DEFAULT_KYSO_SCS_STORAGE_CLASS=""
export DEPLOYMENT_DEFAULT_KYSO_SCS_STORAGE_SIZE="10Gi"
export DEPLOYMENT_DEFAULT_KYSO_SCS_RESTIC_BACKUP="false"

# Fixed values
export KYSO_SCS_INDEXER_PORT="8080"
export KYSO_SCS_INDEXER_CRON_EXPRESSION="*/30 * * * * ?"
export KYSO_SCS_MYSSH_PORT="22"
export KYSO_SCS_MYSSH_SECRET_NAME="kyso-scs-myssh-secret"
export KYSO_SCS_API_AUTH_EP="auth/check-permissions"
export KYSO_SCS_SFTP_SCS_USER="scs"
export KYSO_SCS_SFTP_PUB_USER="pub"
export KYSO_SCS_NGINX_PORT="80"
export KYSO_SCS_WEBHOOK_PORT="9000"

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
  export KYSO_SCS_CHART_DIR="$CHARTS_DIR/kyso-scs"
  export KYSO_SCS_TMPL_DIR="$TMPL_DIR/apps/kyso-scs"
  export KYSO_SCS_HELM_DIR="$DEPLOY_HELM_DIR/kyso-scs"
  export KYSO_SCS_KUBECTL_DIR="$DEPLOY_KUBECTL_DIR/kyso-scs"
  export KYSO_SCS_SECRETS_DIR="$DEPLOY_SECRETS_DIR/kyso-scs"
  export KYSO_SCS_PF_DIR="$DEPLOY_PF_DIR/kyso-scs"
  # Templates
  export KYSO_SCS_HELM_VALUES_TMPL="$KYSO_SCS_TMPL_DIR/values.yaml"
  export KYSO_SCS_PVC_TMPL="$KYSO_SCS_TMPL_DIR/pvc.yaml"
  export KYSO_SCS_PV_TMPL="$KYSO_SCS_TMPL_DIR/pv.yaml"
  export KYSO_SCS_SVC_MAP_TMPL="$KYSO_SCS_TMPL_DIR/svc_map.yaml"
  # BEG: deprecated files
  export KYSO_SCS_CRONJOBS_YAML="$KYSO_SCS_KUBECTL_DIR/cronjobs.yaml"
  export KYSO_SCS_DEPLOY_YAML="$KYSO_SCS_KUBECTL_DIR/deploy.yaml"
  _config_map="$KYSO_SCS_SECRETS_DIR/configmap$SOPS_EXT.yaml"
  export KYSO_SCS_INDEXER_CONFIGMAP_YAML="$_config_map"
  export KYSO_SCS_INGRESS_YAML="$KYSO_SCS_KUBECTL_DIR/ingress.yaml"
  export KYSO_SCS_SECRET_YAML="$KYSO_SCS_SECRETS_DIR/secrets$SOPS_EXT.yaml"
  export KYSO_SCS_SERVICE_YAML="$KYSO_SCS_KUBECTL_DIR/service.yaml"
  export KYSO_SCS_STATEFULSET_YAML="$KYSO_SCS_KUBECTL_DIR/statefulset.yaml"
  export KYSO_SCS_HOST_KEYS="$KYSO_SCS_SECRETS_DIR/host_keys$SOPS_EXT.txt"
  export KYSO_SCS_USERS_TAR="$KYSO_SCS_SECRETS_DIR/user_data$SOPS_EXT.tar"
  # END: deprecated files
  # Files
  export KYSO_SCS_HELM_VALUES_YAML="$KYSO_SCS_HELM_DIR/values${SOPS_EXT}.yaml"
  export KYSO_SCS_HELM_VALUES_YAML_PLAIN="$KYSO_SCS_HELM_DIR/values.yaml"
  export KYSO_SCS_PVC_YAML="$KYSO_SCS_KUBECTL_DIR/pvc.yaml"
  export KYSO_SCS_PV_YAML="$KYSO_SCS_KUBECTL_DIR/pv.yaml"
  export KYSO_SCS_SVC_MAP_YAML="$KYSO_SCS_KUBECTL_DIR/svc_map.yaml"
  export KYSO_SCS_INDEXER_PF_OUT="$KYSO_SCS_PF_DIR/kubectl-indexer.out"
  export KYSO_SCS_INDEXER_PF_PID="$KYSO_SCS_PF_DIR/kubectl-indexer.pid"
  export KYSO_SCS_MYSSH_PF_OUT="$KYSO_SCS_PF_DIR/kubectl-sftp.out"
  export KYSO_SCS_MYSSH_PF_PID="$KYSO_SCS_PF_DIR/kubectl-sftp.pid"
  export KYSO_SCS_WEBHOOK_PF_OUT="$KYSO_SCS_PF_DIR/kubectl-webhook.out"
  export KYSO_SCS_WEBHOOK_PF_PID="$KYSO_SCS_PF_DIR/kubectl-webhook.pid"
  _myssh_secret_json="$KYSO_SCS_SECRETS_DIR/secrets$SOPS_EXT.json"
  export KYSO_SCS_MYSSH_SECRET_JSON="$_myssh_secret_json"
  # By default don't auto save the environment
  KYSO_SCS_AUTO_SAVE_ENV="false"
  # Use defaults for variables missing from config files / enviroment
  if [ "$DEPLOYMENT_KYSO_SCS_REPLICAS" ]; then
    KYSO_SCS_REPLICAS="$DEPLOYMENT_KYSO_SCS_REPLICAS"
  else
    KYSO_SCS_REPLICAS="$DEPLOYMENT_DEFAULT_KYSO_SCS_REPLICAS"
  fi
  export KYSO_SCS_REPLICAS
  if [ -z "$KYSO_SCS_HARDLINK_CRONJOB_IMAGE" ]; then
    if [ "$DEPLOYMENT_KYSO_SCS_HARDLINK_CRONJOB_IMAGE" ]; then
      _cronjob_image="$DEPLOYMENT_KYSO_SCS_HARDLINK_CRONJOB_IMAGE"
    else
      _cronjob_image="$DEPLOYMENT_DEFAULT_KYSO_SCS_HARDLINK_CRONJOB_IMAGE"
    fi
    KYSO_SCS_HARDLINK_CRONJOB_IMAGE="$_cronjob_image"
  else
    KYSO_SCS_AUTO_SAVE_ENV="true"
  fi
  export KYSO_SCS_HARDLINK_CRONJOB_IMAGE
  if [ -z "$KYSO_SCS_INDEXER_ENDPOINT" ]; then
    if [ "$DEPLOYMENT_KYSO_SCS_INDEXER_ENDPOINT" ]; then
      KYSO_SCS_INDEXER_ENDPOINT="$DEPLOYMENT_KYSO_SCS_INDEXER_ENDPOINT"
    else
      KYSO_SCS_INDEXER_ENDPOINT="$DEPLOYMENT_DEFAULT_KYSO_SCS_INDEXER_ENDPOINT"
    fi
  else
    KYSO_SCS_AUTO_SAVE_ENV="true"
  fi
  export KYSO_SCS_INDEXER_ENDPOINT
  if [ -z "$KYSO_SCS_INDEXER_IMAGE" ]; then
    if [ "$DEPLOYMENT_KYSO_SCS_INDEXER_IMAGE" ]; then
      KYSO_SCS_INDEXER_IMAGE="$DEPLOYMENT_KYSO_SCS_INDEXER_IMAGE"
    else
      KYSO_SCS_INDEXER_IMAGE="$DEPLOYMENT_DEFAULT_KYSO_SCS_INDEXER_IMAGE"
    fi
  else
    KYSO_SCS_AUTO_SAVE_ENV="true"
  fi
  export KYSO_SCS_INDEXER_IMAGE
  if [ -z "$KYSO_SCS_MYSSH_IMAGE" ]; then
    if [ "$DEPLOYMENT_KYSO_SCS_MYSSH_IMAGE" ]; then
      KYSO_SCS_MYSSH_IMAGE="$DEPLOYMENT_KYSO_SCS_MYSSH_IMAGE"
    else
      KYSO_SCS_MYSSH_IMAGE="$DEPLOYMENT_DEFAULT_KYSO_SCS_MYSSH_IMAGE"
    fi
  else
    KYSO_SCS_AUTO_SAVE_ENV="true"
  fi
  export KYSO_SCS_MYSSH_IMAGE
  if [ -z "$KYSO_SCS_NGINX_IMAGE" ]; then
    if [ "$DEPLOYMENT_KYSO_SCS_NGINX_IMAGE" ]; then
      KYSO_SCS_NGINX_IMAGE="$DEPLOYMENT_KYSO_SCS_NGINX_IMAGE"
    else
      KYSO_SCS_NGINX_IMAGE="$DEPLOYMENT_DEFAULT_KYSO_SCS_NGINX_IMAGE"
    fi
  else
    KYSO_SCS_AUTO_SAVE_ENV="true"
  fi
  export KYSO_SCS_NGINX_IMAGE
  if [ -z "$KYSO_SCS_WEBHOOK_IMAGE" ]; then
    if [ "$DEPLOYMENT_KYSO_SCS_WEBHOOK_IMAGE" ]; then
      KYSO_SCS_WEBHOOK_IMAGE="$DEPLOYMENT_KYSO_SCS_WEBHOOK_IMAGE"
    else
      KYSO_SCS_WEBHOOK_IMAGE="$DEPLOYMENT_DEFAULT_KYSO_SCS_WEBHOOK_IMAGE"
    fi
  else
    KYSO_SCS_AUTO_SAVE_ENV="true"
  fi
  export KYSO_SCS_WEBHOOK_IMAGE
  if [ "$DEPLOYMENT_KYSO_SCS_STORAGE_ACCESS_MODES" ]; then
    KYSO_SCS_STORAGE_ACCESS_MODES="$DEPLOYMENT_KYSO_SCS_STORAGE_ACCESS_MODES"
  else
    _storage_access_modes="$DEPLOYMENT_DEFAULT_KYSO_SCS_STORAGE_ACCESS_MODES"
    KYSO_SCS_STORAGE_ACCESS_MODES="$_storage_access_modes"
  fi
  export KYSO_SCS_STORAGE_ACCESS_MODES
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
  if [ -z "$KYSO_SCS_HARDLINK_CRONJOB_SCHEDULE" ]; then
    if [ "$DEPLOYMENT_KYSO_SCS_HARDLINK_CRONJOB_SCHEDULE" ]; then
      _cronjob_schedule="$DEPLOYMENT_KYSO_SCS_HARDLINK_CRONJOB_SCHEDULE"
    else
      _cronjob_schedule="$DEPLOYMENT_DEFAULT_KYSO_SCS_HARDLINK_CRONJOB_SCHEDULE"
    fi
    KYSO_SCS_HARDLINK_CRONJOB_SCHEDULE="$_cronjob_schedule"
  else
    KYSO_SCS_AUTO_SAVE_ENV="true"
  fi
  export KYSO_SCS_HARDLINK_CRONJOB_SCHEDULE
  if [ "$DEPLOYMENT_KYSO_SCS_INDEXER_PF_PORT" ]; then
    KYSO_SCS_INDEXER_PF_PORT="$DEPLOYMENT_KYSO_SCS_INDEXER_PF_PORT"
  else
    KYSO_SCS_INDEXER_PF_PORT="$DEPLOYMENT_DEFAULT_KYSO_SCS_INDEXER_PF_PORT"
  fi
  export KYSO_SCS_INDEXER_PF_PORT
  if [ "$DEPLOYMENT_KYSO_SCS_MYSSH_PF_PORT" ]; then
    KYSO_SCS_MYSSH_PF_PORT="$DEPLOYMENT_KYSO_SCS_MYSSH_PF_PORT"
  else
    KYSO_SCS_MYSSH_PF_PORT="$DEPLOYMENT_DEFAULT_KYSO_SCS_MYSSH_PF_PORT"
  fi
  export KYSO_SCS_MYSSH_PF_PORT
  if [ "$DEPLOYMENT_KYSO_SCS_WEBHOOK_PF_PORT" ]; then
    KYSO_SCS_WEBHOOK_PF_PORT="$DEPLOYMENT_KYSO_SCS_WEBHOOK_PF_PORT"
  else
    KYSO_SCS_WEBHOOK_PF_PORT="$DEPLOYMENT_DEFAULT_KYSO_SCS_WEBHOOK_PF_PORT"
  fi
  export KYSO_SCS_WEBHOOK_PF_PORT
  # Export auto save environment flag
  export KYSO_SCS_AUTO_SAVE_ENV
  __apps_kyso_scs_export_variables="1"
}

apps_kyso_scs_check_directories() {
  apps_common_check_directories
  for _d in "$KYSO_SCS_HELM_DIR" "$KYSO_SCS_KUBECTL_DIR" \
    "$KYSO_SCS_SECRETS_DIR" "$KYSO_SCS_PF_DIR"; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

apps_kyso_scs_clean_directories() {
  # Try to remove empty dirs, except if they contain secrets
  for _d in "$KYSO_SCS_HELM_DIR" "$KYSO_SCS_KUBECTL_DIR" \
    "$KYSO_SCS_SECRETS_DIR" "$KYSO_SCS_PF_DIR"; do
    if [ -d "$_d" ]; then
      rmdir "$_d" 2>/dev/null || true
    fi
  done
}

apps_kyso_scs_read_variables() {
  _app="kyso-scs"
  header "Reading $_app settings"
  _ex_ep="$LINUX_HOST_IP:$KYSO_SCS_INDEXER_PORT"
  read_value "Kyso Indexer Endpoint (i.e. '$_ex_ep' or '-' to deploy image)" \
    "${KYSO_SCS_INDEXER_ENDPOINT}"
  KYSO_SCS_INDEXER_ENDPOINT=${READ_VALUE}
  _ex_img="registry.kyso.io/kyso-io/kyso-indexer/develop:latest"
  read_value \
    "Indexer Image URI (i.e. '$_ex_img' or export KYSO_SCS_INDEXER_IMAGE var)" \
    "${KYSO_SCS_INDEXER_IMAGE}"
  KYSO_SCS_INDEXER_IMAGE=${READ_VALUE}
  read_value "MySecureShell Image URI" "${KYSO_SCS_MYSSH_IMAGE}"
  KYSO_SCS_MYSSH_IMAGE=${READ_VALUE}
  read_value "Nginx Image URI" "${KYSO_SCS_NGINX_IMAGE}"
  KYSO_SCS_NGINX_IMAGE=${READ_VALUE}
  read_value "Webhook Image URI" "${KYSO_SCS_WEBHOOK_IMAGE}"
  KYSO_SCS_WEBHOOK_IMAGE=${READ_VALUE}
  read_value "SCS Replicas" "${KYSO_SCS_REPLICAS}"
  KYSO_SCS_REPLICAS=${READ_VALUE}
  read_value "Kyso SCS Access Modes ('ReadWriteOnce', 'ReadWriteMany' if efs)" \
    "${KYSO_SCS_STORAGE_ACCESS_MODES}"
  KYSO_SCS_STORAGE_ACCESS_MODES=${READ_VALUE}
  read_value "Kyso SCS Storage Class ('local-storage' @ k3d, 'efs-sc' @ eks)" \
    "${KYSO_SCS_STORAGE_CLASS}"
  KYSO_SCS_STORAGE_CLASS=${READ_VALUE}
  read_value "Kyso SCS Volume Size" "${KYSO_SCS_STORAGE_SIZE}"
  KYSO_SCS_STORAGE_SIZE=${READ_VALUE}
  read_bool "Kyso SCS backups use restic" "${KYSO_SCS_RESTIC_BACKUP}"
  KYSO_SCS_RESTIC_BACKUP=${READ_VALUE}
  read_value "Kyso SCS Hardlink Cronjob Image URI" \
    "${KYSO_SCS_HARDLINK_CRONJOB_IMAGE}"
  KYSO_SCS_HARDLINK_CRONJOB_IMAGE="${READ_VALUE}"
  read_value "Kyso SCS Hardlink Cronjob Schedule" \
    "${KYSO_SCS_HARDLINK_CRONJOB_SCHEDULE}"
  KYSO_SCS_HARDLINK_CRONJOB_SCHEDULE="${READ_VALUE}"
  read_value "Fixed port for kyso-indexer pf? (i.e. 8080 or '-' for random)" \
    "${KYSO_SCS_INDEXER_PF_PORT}"
  KYSO_SCS_INDEXER_PF_PORT=${READ_VALUE}
  read_value "Fixed port for mysecureshell pf? (i.e. 2020 or '-' for random)" \
    "${KYSO_SCS_MYSSH_PF_PORT}"
  KYSO_SCS_MYSSH_PF_PORT=${READ_VALUE}
  read_value "Fixed port for webhook pf? (i.e. 9000 or '-' for random)" \
    "${KYSO_SCS_WEBHOOK_PF_PORT}"
  KYSO_SCS_WEBHOOK_PF_PORT=${READ_VALUE}
}

apps_kyso_scs_print_variables() {
  _app="kyso-scs"
  cat <<EOF
# Deployment $_app settings
# ---
# Endpoint for Indexer (replaces the real deployment on development systems),
# set to:
# - '$LINUX_HOST_IP:$KYSO_SCS_INDEXER_PORT' on Linux
# - '$MACOS_HOST_IP:$KYSO_SCS_INDEXER_PORT' on systems using Docker Desktop
KYSO_SCS_INDEXER_ENDPOINT=$KYSO_SCS_INDEXER_ENDPOINT
# Indexer Image URI, examples for local testing:
# - 'registry.kyso.io/kyso-io/kyso-indexer/develop:latest'
# - 'k3d-registry.lo.kyso.io:5000/kyso-indexer:latest'
# If left empty the KYSO_SCS_INDEXER_IMAGE environment variable has to be set
# each time the kyso-scs service is installed
KYSO_SCS_INDEXER_IMAGE=$KYSO_SCS_INDEXER_IMAGE
# Kyso SCS MySecureShell Image URI
KYSO_SCS_MYSSH_IMAGE=$KYSO_SCS_MYSSH_IMAGE
# Kyso SCS Nginx Image URI
KYSO_SCS_NGINX_IMAGE=$KYSO_SCS_NGINX_IMAGE
# Kyso SCS Webhook Image URI
KYSO_SCS_WEBHOOK_IMAGE=$KYSO_SCS_WEBHOOK_IMAGE
# Number of pods to run in parallel (for more than 1 the volumes must be EFS)
KYSO_SCS_REPLICAS=$KYSO_SCS_REPLICAS
# Kyso SCS Access Modes ('ReadWriteOnce', 'ReadWriteMany' if efs)
KYSO_SCS_STORAGE_ACCESS_MODES=$KYSO_SCS_STORAGE_ACCESS_MODES
# Kyso SCS Storage Class ('local-storage' @ k3d, 'efs-sc' @ eks)
KYSO_SCS_STORAGE_CLASS=$KYSO_SCS_STORAGE_CLASS
# Kyso SCS Volume Size (if the storage is local or NFS the value is ignored)
KYSO_SCS_STORAGE_SIZE=$KYSO_SCS_STORAGE_SIZE
# Kyso SCS backups use restic (adds annotations to use it or not)
KYSO_SCS_RESTIC_BACKUP=$KYSO_SCS_RESTIC_BACKUP
# Kyso SCS Hardlink Cronjob Image URI
KYSO_SCS_HARDLINK_CRONJOB_IMAGE=$KYSO_SCS_HARDLINK_CRONJOB_IMAGE
# Kyso SCS Hardlink Cronjob Schedule
KYSO_SCS_HARDLINK_CRONJOB_SCHEDULE=$KYSO_SCS_HARDLINK_CRONJOB_SCHEDULE
# Fixed port for kyso-indexer pf (recommended is 8080, random if empty)
KYSO_SCS_INDEXER_PF_PORT=$KYSO_SCS_INDEXER_PF_PORT
# Fixed port for mysecureshell pf (recommended is 2020, random if empty)
KYSO_SCS_MYSSH_PF_PORT=$KYSO_SCS_MYSSH_PF_PORT
# Fixed port for webhook pf (recommended is 9000, random if empty)
KYSO_SCS_WEBHOOK_PF_PORT=$KYSO_SCS_WEBHOOK_PF_PORT
# ---
EOF
}

apps_kyso_scs_cron_runjob() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_scs_export_variables "$_deployment" "$_cluster"
  _ns="$KYSO_SCS_NAMESPACE"
  _label="cronjob=hardlink"
  _cronjob_name="$(kubectl -n "$_ns" get -l "$_label" cronjob -o name)"
  if [ "$_cronjob_name" ]; then
    _job_name="${_cronjob_name#cronjob.batch/}-manual-run"
    echo "--- Creating job '$_job_name' ---"
    kubectl -n "$_ns" create job --from "$_cronjob_name" "$_job_name"
    echo "--- Waiting until job '$_job_name' ends ---"
    kubectl -n "$_ns" wait job "$_job_name" --for=condition=complete \
      --timeout=300s
    echo "--- Logs for job '$_job_name' ---"
    kubectl -n "$_ns" logs "job/$_job_name"
    echo "--- Removing job '$_job_name' ---"
    kubectl -n "$_ns" delete job "$_job_name"
  else
    echo "No cronjob found!"
    return
  fi
}

# To get the last job logs we have added the cronjob=hardlink label to the pods
# and look for the last created one.
# ---
# Originally seen in this blog post
# https://medium.com/@pranay.shah/how-to-get-logs-from-cron-job-in-kubernetes-last-completed-job-7957327c7e76
# ---
apps_kyso_scs_cron_status() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_scs_export_variables "$_deployment" "$_cluster"
  _ns="$KYSO_SCS_NAMESPACE"
  _label="cronjob=hardlink"
  _cronjob_name="$(kubectl -n "$_ns" get -l "$_label" cronjob -o name)"
  if [ "$_cronjob_name" ]; then
    echo "--- Status for CronJob ('${_cronjob_name#cronjob.batch/}') ---"
    kubectl -n "$_ns" get "$_cronjob_name" -o 'jsonpath={.status}' |
      jq -c "({lastScheduleTime},{lastSuccessfulTime})" |
      sed -e 's/"//g;s/{//;s/}//;s/:/: /;s/^/- /'
  else
    echo "No cronjob found!"
    return
  fi
  _last_job_pod="$(
    kubectl get pods -n "$_ns" -l "$_label" \
      --sort-by='.metadata.creationTimestamp' \
      -o 'jsonpath={.items[-1].metadata.name}' 2>/dev/null
  )" || true
  echo "--- Logs from last pod executed ('$_last_job_pod') ---"
  if [ "$_last_job_pod" ]; then
    kubectl -n "$_ns" logs "pod/$_last_job_pod"
  else
    echo "No last job found!"
  fi
}

apps_kyso_scs_logs() {
  _deployment="$1"
  _cluster="$2"
  _container="$3"
  apps_kyso_scs_export_variables "$_deployment" "$_cluster"
  _app="kyso-scs"
  _ns="$KYSO_SCS_NAMESPACE"
  if kubectl get -n "$_ns" "statefulset/$_app" >/dev/null 2>&1; then
    kubectl -n "$_ns" logs "statefulset/$_app" -c "$_container" -f
  else
    echo "Statefulset '$_app' not found on namespace '$_ns'"
  fi
}

apps_kyso_scs_sh() {
  _deployment="$1"
  _cluster="$2"
  _container="$3"
  apps_kyso_scs_export_variables "$_deployment" "$_cluster"
  _app="kyso-scs"
  _ns="$KYSO_SCS_NAMESPACE"
  if kubectl get -n "$_ns" "statefulset/$_app" >/dev/null 2>&1; then
    kubectl -n "$_ns" exec -ti "statefulset/$_app" -c "$_container" -- /bin/sh
  else
    echo "Statefulset '$_app' not found on namespace '$_ns'"
  fi
}

apps_kyso_scs_secret_apply() {
  _deployment="$1"
  _cluster="$2"
  apps_export_variables "$_deployment" "$_cluster"
  _ns="$KYSO_SCS_NAMESPACE"
  # Apply the KYSO_SCS_MYSSH_SECRET_JSON file if it exists and if it does not
  # but the old secrets are available create it based on them and apply it to
  # keep existing values
  _ret="0"
  if [ -f "$KYSO_SCS_MYSSH_SECRET_JSON" ]; then
    file_to_stdout "$KYSO_SCS_MYSSH_SECRET_JSON" |
      kubectl apply --namespace "$_ns" -f- || _ret="$?"
  elif [ -f "$KYSO_SCS_HOST_KEYS" ] && [ -f "$KYSO_SCS_USERS_TAR" ]; then
    # Create a temporary folder and make it our current work directory
    opwd="$(pwd)"
    tmpdir="$(mktemp -d)"
    cd "$tmpdir"
    # Extract the old files into the temporary folder
    file_to_stdout "$KYSO_SCS_HOST_KEYS" >host_keys.txt || _ret="$?"
    file_to_stdout "$KYSO_SCS_USERS_TAR" | tar xaf - || _ret="$?"
    # Create the new user_sids.tgz file
    tar acf "user_sids.tgz" id_* 2>/dev/null || _ret="$?"
    # Create the secret with the four files
    kubectl --dry-run=client -o json create secret generic \
      "$KYSO_SCS_MYSSH_SECRET_NAME" \
      --from-file="host_keys.txt=host_keys.txt" \
      --from-file="user_keys.txt=user_keys.txt" \
      --from-file="user_pass.txt=user_pass.txt" \
      --from-file="user_sids.tgz=user_sids.tgz" |
      stdout_to_file "$KYSO_SCS_MYSSH_SECRET_JSON" || _ret="$?"
    # Go back to our original directory & remove the temporary one
    cd "$opwd"
    rm -rf "$tmpdir"
    # If all went well, apply the new file and remove the old secrets (we
    # will no longer need them)
    if [ "$_ret" -eq "0" ]; then
      file_to_stdout "$KYSO_SCS_MYSSH_SECRET_JSON" |
        kubectl apply --namespace "$_ns" -f-
      rm -f "$KYSO_SCS_HOST_KEYS" "$KYSO_SCS_USERS_TAR"
    fi
  fi
  return "$_ret"
}

apps_kyso_scs_secret_cat_file() {
  _file="$1"
  _deployment="$2"
  _cluster="$3"
  apps_export_variables "$_deployment" "$_cluster"
  # Get and decode file content from the secret, if available
  if [ -f "$KYSO_SCS_MYSSH_SECRET_JSON" ]; then
    _ret="0"
    _base64="$(
      file_to_stdout "$KYSO_SCS_MYSSH_SECRET_JSON" |
        jq -e -r ".data[\"$_file\"]" 2>/dev/null
    )" || _ret="$?"
    if [ "$_ret" -eq "0" ]; then
      echo "$_base64" | base64 -d
    fi
  fi
}

apps_kyso_scs_secret_delete() {
  _deployment="$1"
  _cluster="$2"
  apps_export_variables "$_deployment" "$_cluster"
  # Deletes the secret without deleting the KYSO_SCS_MYSSH_SECRET_JSON file
  _ns="$KYSO_SCS_NAMESPACE"
  _secret="secret/$KYSO_SCS_MYSSH_SECRET_NAME"
  if [ "$(kubectl get --namespace "$_ns" "$_secret" -o name)" ]; then
    kubectl delete --namespace "$_ns" "$_secret"
  fi
}

apps_kyso_scs_secret_get() {
  _deployment="$1"
  _cluster="$2"
  apps_export_variables "$_deployment" "$_cluster"
  _ns="$KYSO_SCS_NAMESPACE"
  _secret="secret/$KYSO_SCS_MYSSH_SECRET_NAME"
  _metadata_query="{name: .metadata.name, creationTimestamp: null}"
  _jq_query="{kind, apiVersion, metadata: $_metadata_query, data}"
  # Dump the secret in json format to the KYSO_SCS_MYSSH_SECRET_JSON file
  if [ "$(kubectl get --namespace "$_ns" "$_secret" -o name)" ]; then
    kubectl get --namespace "$_ns" "$_secret" -o json | jq "$_jq_query" |
      stdout_to_file "$KYSO_SCS_MYSSH_SECRET_JSON"
  fi
}

apps_kyso_scs_install() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_scs_export_variables "$_deployment" "$_cluster"
  if [ -z "$KYSO_SCS_INDEXER_IMAGE" ]; then
    echo "The INDEXER_IMAGE is empty."
    echo "Export KYSO_SCS_INDEXER_IMAGE or reconfigure."
    exit 1
  fi
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
  # Auto save the configuration if requested
  if is_selected "$KYSO_SCS_AUTO_SAVE_ENV"; then
    apps_kyso_scs_env_save "$_deployment" "$_cluster"
  fi
  # Load additional variables & check directories
  apps_common_export_service_hostnames "$_deployment" "$_cluster"
  apps_kyso_scs_check_directories
  # Adjust variables
  _app="kyso-scs"
  _ns="$KYSO_SCS_NAMESPACE"
  # directories
  _chart="$KYSO_SCS_CHART_DIR"
  # deprecated yaml files
  _cronjobs_yaml="$KYSO_SCS_CRONJOBS_YAML"
  _deploy_yaml="$KYSO_SCS_DEPLOY_YAML"
  _ingress_yaml="$KYSO_SCS_INGRESS_YAML"
  _indexer_configmap_yaml="$KYSO_SCS_INDEXER_CONFIGMAP_YAML"
  _secret_yaml="$KYSO_SCS_SECRET_YAML"
  _service_yaml="$KYSO_SCS_SERVICE_YAML"
  _statefulset_yaml="$KYSO_SCS_STATEFULSET_YAML"
  # files
  _helm_values_tmpl="$KYSO_SCS_HELM_VALUES_TMPL"
  _helm_values_yaml="$KYSO_SCS_HELM_VALUES_YAML"
  _helm_values_yaml_plain="$KYSO_SCS_HELM_VALUES_YAML_PLAIN"
  _pv_tmpl="$KYSO_SCS_PV_TMPL"
  _pv_yaml="$KYSO_SCS_PV_YAML"
  _pvc_tmpl="$KYSO_SCS_PVC_TMPL"
  _pvc_yaml="$KYSO_SCS_PVC_YAML"
  _vol_name="$_ns"
  _pvc_name="$_ns"
  _svc_map_tmpl="$KYSO_SCS_SVC_MAP_TMPL"
  _svc_map_yaml="$KYSO_SCS_SVC_MAP_YAML"
  _cert_yamls=""
  for _hostname in $DEPLOYMENT_HOSTNAMES; do
    _cert_yaml="$KYSO_SCS_KUBECTL_DIR/tls-$_hostname${SOPS_EXT}.yaml"
    _cert_yamls="$_cert_yamls $_cert_yaml"
  done
  # other settings
  _access_modes="$KYSO_SCS_STORAGE_ACCESS_MODES"
  if is_selected "$KYSO_SCS_RESTIC_BACKUP"; then
    _backup_action="backup-volumes"
  else
    _backup_action="backup-volumes-exclude"
  fi
  _storage_class="$KYSO_SCS_STORAGE_CLASS"
  _storage_size="$KYSO_SCS_STORAGE_SIZE"
  if ! find_namespace "$_ns"; then
    # Remove old files, just in case ...
    # shellcheck disable=SC2086
    rm -f "$_helm_values_yaml" "$_svc_map_yaml" "$_pvc_yaml" "$_pv_yaml" \
      "$_cronjobs_yaml" "$_secret_yaml" "$_service_yaml" "$_deploy_yaml" \
      "$_ingress_yaml" "$_statefulset_yaml" "$_indexer_configmap_yaml" \
      $_cert_yamls
    # Create namespace
    create_namespace "$_ns"
  fi
  # If we have a legacy deployment, remove the old objects
  _legacy="false"
  for _yaml in "$_deploy_yaml" "$_statefulset_yaml" "$_cronjobs_yaml" \
    "$_secret_yaml" "$_service_yaml" "$_ingress_yaml" \
    "$_indexer_configmap_yaml" $_cert_yamls; do
    [ -f "$_yaml" ] && _legacy="true"
    kubectl_delete "$_yaml" || true
  done
  # Remove the _svc_map_yaml for legacy deployments too
  [ "$_legacy" = "false" ] || kubectl_delete "$_svc_map_yaml"
  # Adjust _storage_class_sed
  if [ "$_storage_class" ]; then
    _storage_class_sed="s%__STORAGE_CLASS__%$_storage_class%"
  else
    _storage_class_sed="/__STORAGE_CLASS__/d;"
  fi
  # Create the PV if using local storage and ignore it in other cases (we assume
  # that the storage class has automatic PV provisioning)
  if [ "$_storage_class" = "local-storage" ] &&
    is_selected "$CLUSTER_USE_LOCAL_STORAGE"; then
    test -d "$CLUST_VOLUMES_DIR/$_vol_name" ||
      mkdir "$CLUST_VOLUMES_DIR/$_vol_name"
    : >"$_pv_yaml"
    sed \
      -e "s%__APP__%$_app%" \
      -e "s%__NAMESPACE__%$_ns%" \
      -e "s%__PV_NAME__%$_vol_name%" \
      -e "s%__PVC_NAME__%$_pvc_name%" \
      -e "s%__ACCESS_MODES__%$_access_modes%" \
      -e "s%__STORAGE_SIZE__%$_storage_size%" \
      -e "$_storage_class_sed" \
      "$_pv_tmpl" >>"$_pv_yaml"
  fi
  # Create _pcv_yaml
  : >"$_pvc_yaml"
  sed \
    -e "s%__APP__%$_app%" \
    -e "s%__NAMESPACE__%$_ns%" \
    -e "s%__PVC_NAME__%$_pvc_name%" \
    -e "s%__ACCESS_MODES__%$_access_modes%" \
    -e "s%__STORAGE_SIZE__%$_storage_size%" \
    -e "$_storage_class_sed" \
    "$_pvc_tmpl" >>"$_pvc_yaml"
  # Images
  _hardlink_image_repo="${KYSO_SCS_HARDLINK_CRONJOB_IMAGE%:*}"
  _hardlink_image_tag="${KYSO_SCS_HARDLINK_CRONJOB_IMAGE#*:}"
  if [ "$_hardlink_image_repo" = "$_hardlink_image_tag" ]; then
    _hardlink_image_tag="latest"
  fi
  _indexer_image_repo="${KYSO_SCS_INDEXER_IMAGE%:*}"
  _indexer_image_tag="${KYSO_SCS_INDEXER_IMAGE#*:}"
  if [ "$_indexer_image_repo" = "$_indexer_image_tag" ]; then
    _indexer_image_tag="latest"
  fi
  _myssh_image_repo="${KYSO_SCS_MYSSH_IMAGE%:*}"
  _myssh_image_tag="${KYSO_SCS_MYSSH_IMAGE#*:}"
  if [ "$_myssh_image_repo" = "$_myssh_image_tag" ]; then
    _myssh_image_tag="latest"
  fi
  _nginx_image_repo="${KYSO_SCS_NGINX_IMAGE%:*}"
  _nginx_image_tag="${KYSO_SCS_NGINX_IMAGE#*:}"
  if [ "$_nginx_image_repo" = "$_nginx_image_tag" ]; then
    _nginx_image_tag="latest"
  fi
  _webhook_image_repo="${KYSO_SCS_WEBHOOK_IMAGE%:*}"
  _webhook_image_tag="${KYSO_SCS_WEBHOOK_IMAGE#*:}"
  if [ "$_webhook_image_repo" = "$_webhook_image_tag" ]; then
    _webhook_image_tag="latest"
  fi
  # cronjob settings
  _hardlink_url="http://kyso-scs-svc.$_ns.svc.cluster.local:9000/hooks/hardlink"
  _hardlink_schedule="$KYSO_SCS_HARDLINK_CRONJOB_SCHEDULE"
  # indexer settings
  if [ "$KYSO_SCS_INDEXER_ENDPOINT" ]; then
    _indexer_ep_enabled="true"
  else
    # Adjust the api port
    _indexer_ep_enabled="false"
  fi
  _indexer_ep_addr="${KYSO_SCS_INDEXER_ENDPOINT%:*}"
  _indexer_ep_port="${KYSO_SCS_INDEXER_ENDPOINT#*:}"
  [ "$_indexer_ep_port" != "$_indexer_ep_addr" ] ||
    _indexer_ep_port="$KYSO_SCS_INDEXER_PORT"
  _elastic_url="http://elasticsearch:9200"
  _mongodb_user_database_uri="$(
    apps_mongodb_print_user_database_uri "$_deployment" "$_cluster"
  )"
  # nginx settings
  _kyso_api_host="kyso-api"
  if [ "$KYSO_SCS_API_AUTH_EP" ]; then
    _auth_request_uri="http://$_kyso_api_host/api/v1/$KYSO_SCS_API_AUTH_EP"
  else
    _auth_request_uri=""
  fi
  # Prepare values.yaml file
  sed \
    -e "s%__SCS_REPLICAS__%$KYSO_SCS_REPLICAS%" \
    -e "s%__IMAGE_PULL_POLICY__%$DEPLOYMENT_IMAGE_PULL_POLICY%" \
    -e "s%__PULL_SECRETS_NAME__%$CLUSTER_PULL_SECRETS_NAME%" \
    -e "s%__SCS_PVC_NAME__%$_pvc_name%" \
    -e "s%__SCS_VOL_NAME__%$_vol_name%" \
    -e "s%__SCS_SFTP_PUB_USER__%$KYSO_SCS_SFTP_PUB_USER%" \
    -e "s%__SCS_SFTP_SCS_USER__%$KYSO_SCS_SFTP_SCS_USER%" \
    -e "s%__SCS_HARDLINK_IMAGE_REPO__%$_hardlink_image_repo%" \
    -e "s%__SCS_HARDLINK_IMAGE_TAG__%$_hardlink_image_tag%" \
    -e "s%__SCS_HARDLINK_SCHEDULE__%$_hardlink_schedule%" \
    -e "s%__SCS_HARDLINK_WEBHOOK_URL__%$_hardlink_url%" \
    -e "s%__SCS_INDEXER_ENABLED__%$_indexer_enabled%" \
    -e "s%__SCS_INDEXER_ENDPOINT_ENABLED__%$_indexer_ep_enabled%" \
    -e "s%__SCS_INDEXER_ENDPOINT_ADDR__%$_indexer_ep_addr%" \
    -e "s%__SCS_INDEXER_ENDPOINT_PORT__%$_indexer_ep_port%" \
    -e "s%__SCS_INDEXER_IMAGE_REPO__%$_indexer_image_repo%" \
    -e "s%__SCS_INDEXER_IMAGE_TAG__%$_indexer_image_tag%" \
    -e "s%__SCS_INDEXER_SERVICE_PORT__%$KYSO_SCS_INDEXER_PORT%" \
    -e "s%__SCS_INDEXER_CONTAINER_PORT__%$KYSO_SCS_INDEXER_PORT%" \
    -e "s%__SCS_INDEXER_CRON_EXPRESSION__%$KYSO_SCS_INDEXER_CRON_EXPRESSION%" \
    -e "s%__ELASTICSEARCH_URL__%$_elastic_url%g" \
    -e "s%__MONGODB_DATABASE_URI__%$_mongodb_user_database_uri%" \
    -e "s%__SCS_MYSSH_IMAGE_REPO__%$_myssh_image_repo%" \
    -e "s%__SCS_MYSSH_IMAGE_TAG__%$_myssh_image_tag%" \
    -e "s%__SCS_MYSSH_SECRET_NAME__%$KYSO_SCS_MYSSH_SECRET_NAME%" \
    -e "s%__SCS_MYSSH_SERVICE_PORT__%$KYSO_SCS_MYSSH_PORT%" \
    -e "s%__SCS_MYSSH_CONTAINER_PORT__%$KYSO_SCS_MYSSH_PORT%" \
    -e "s%__SCS_NGINX_IMAGE_REPO__%$_nginx_image_repo%" \
    -e "s%__SCS_NGINX_IMAGE_TAG__%$_nginx_image_tag%" \
    -e "s%__SCS_NGINX_SERVICE_PORT__%$KYSO_SCS_NGINX_PORT%" \
    -e "s%__SCS_NGINX_CONTAINER_PORT__%$KYSO_SCS_NGINX_PORT%" \
    -e "s%__AUTH_REQUEST_URI__%$_auth_request_uri%" \
    -e "s%__SCS_WEBHOOK_IMAGE_REPO__%$_webhook_image_repo%" \
    -e "s%__SCS_WEBHOOK_IMAGE_TAG__%$_webhook_image_tag%" \
    -e "s%__SCS_WEBHOOK_SERVICE_PORT__%$KYSO_SCS_WEBHOOK_PORT%" \
    -e "s%__SCS_WEBHOOK_CONTAINER_PORT__%$KYSO_SCS_WEBHOOK_PORT%" \
    -e "s%__KYSO_URL__%http://$_kyso_api_host%" \
    -e "s%__BACKUP_ACTION__%$_backup_action%" \
    "$_helm_values_tmpl" > "$_helm_values_yaml_plain"
  # Apply ingress values
  replace_app_ingress_values "$_app" "$_helm_values_yaml_plain"
  # Generate encoded version if needed and remove plain version
  if [ "$_helm_values_yaml" != "$_helm_values_yaml_plain" ]; then
    stdout_to_file "$_helm_values_yaml" <"$_helm_values_yaml_plain"
    rm -f "$_helm_values_yaml_plain"
  fi
  # Prepare svc_map file
  sed \
    -e "s%__NAMESPACE__%$_ns%" \
    -e "s%__ELASTICSEARCH_SVC_HOSTNAME__%$ELASTICSEARCH_SVC_HOSTNAME%" \
    -e "s%__KYSO_API_SVC_HOSTNAME__%$KYSO_API_SVC_HOSTNAME%" \
    -e "s%__MONGODB_SVC_HOSTNAME__%$MONGODB_SVC_HOSTNAME%" \
    -e "s%__NATS_SVC_HOSTNAME__%$NATS_SVC_HOSTNAME%" \
    "$_svc_map_tmpl" >"$_svc_map_yaml"
  # Create certificate secrets if needed or remove them if not
  if is_selected "$DEPLOYMENT_INGRESS_TLS_CERTS"; then
    create_app_cert_yamls "$_ns" "$KYSO_API_KUBECTL_DIR"
  else
    for _cert_yaml in $_cert_yamls; do
      kubectl_delete "$_cert_yaml" || true
    done
  fi
  # Install pv, map, certs and pvc
  for _yaml in "$_pv_yaml" "$_svc_map_yaml" $_cert_yamls "$_pvc_yaml"; do
    kubectl_apply "$_yaml"
  done
  # Install secrets if present
  apps_kyso_scs_secret_apply "$_deployment" "$_cluster"
  # If moving from deployment to endpoint add annotations to the automatic
  # endpoint to avoid issues with the upgrade
  if [ "$KYSO_SCS_INDEXER_ENDPOINT" ]; then
    if [ "$(kubectl get -n "$_ns" "deployments" -o name)" ]; then
      kubectl annotate -n "$_ns" --overwrite "endpoints/$_app" \
        "meta.helm.sh/release-name=$_app" \
        "meta.helm.sh/release-namespace=$_ns"
    fi
  fi
  # Install helm chart
  helm_upgrade "$_ns" "$_helm_values_yaml" "$_app" "$_chart"
  # Wait until deployment succeds or fails (if there is one, of course)
  kubectl rollout status statefulset --timeout="$ROLLOUT_STATUS_TIMEOUT" \
    -n "$_ns" "$_app"
  # Get current version of the scs secrets
  apps_kyso_scs_secret_get "$_deployment" "$_cluster"
  # Update the api settings
  apps_kyso_update_api_settings "$_deployment" "$_cluster"
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
    KYSO_SCS_INDEXER_IMAGE="$(echo "$_cimages" | sed -ne "s/^$_indexer_cname //p")"
    _myssh_cname="mysecureshell"
    KYSO_SCS_MYSSH_IMAGE="$(echo "$_cimages" | sed -ne "s/^$_myssh_cname //p")"
    _nginx_cname="nginx"
    KYSO_SCS_NGINX_IMAGE="$(echo "$_cimages" | sed -ne "s/^$_nginx_cname //p")"
    _webhook_cname="webhook"
    KYSO_SCS_WEBHOOK_IMAGE="$(
      echo "$_cimages" | sed -ne "s/^$_webhook_cname //p"
    )"
    if [ "$KYSO_SCS_INDEXER_IMAGE" ] && [ "$KYSO_SCS_MYSSH_IMAGE" ] &&
      [ "$KYSO_SCS_NGINX_IMAGE" ] && [ "$KYSO_SCS_WEBHOOK_IMAGE" ]; then
      export KYSO_SCS_INDEXER_IMAGE
      export KYSO_SCS_MYSSH_IMAGE
      export KYSO_SCS_NGINX_IMAGE
      export KYSO_SCS_WEBHOOK_IMAGE
      apps_kyso_scs_install "$_deployment" "$_cluster"
    else
      echo "Images for '$_app' on '$_ns' missing!"
    fi
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

apps_kyso_scs_helm_history() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_scs_export_variables "$_deployment" "$_cluster"
  _app="kyso-scs"
  _ns="$KYSO_SCS_NAMESPACE"
  if find_namespace "$_ns"; then
    helm_history "$_ns" "$_app"
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

apps_kyso_scs_helm_rollback() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_scs_export_variables "$_deployment" "$_cluster"
  _app="kyso-scs"
  _ns="$KYSO_SCS_NAMESPACE"
  _release="$ROLLBACK_RELEASE"
  if find_namespace "$_ns"; then
    # Execute the rollback
    helm_rollback "$_ns" "$_app" "$_release"
    # If we succeed update the api settings
    apps_kyso_update_api_settings "$_deployment" "$_cluster"
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

apps_kyso_scs_helm_uninstall() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_scs_export_variables "$_deployment" "$_cluster"
  _app="kyso-scs"
  _ns="$KYSO_SCS_NAMESPACE"
  if find_namespace "$_ns"; then
    helm uninstall -n "$_ns" "$_app" || true
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

apps_kyso_scs_remove() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_scs_export_variables "$_deployment" "$_cluster"
  ####
  _app="kyso-scs"
  _ns="$KYSO_SCS_NAMESPACE"
  # directories
  _chart="$KYSO_SCS_CHART_DIR"
  # deprecated yaml files
  _cronjobs_yaml="$KYSO_SCS_CRONJOBS_YAML"
  _deploy_yaml="$KYSO_SCS_DEPLOY_YAML"
  _ingress_yaml="$KYSO_SCS_INGRESS_YAML"
  _indexer_configmap_yaml="$KYSO_SCS_INDEXER_CONFIGMAP_YAML"
  _secret_yaml="$KYSO_SCS_SECRET_YAML"
  _service_yaml="$KYSO_SCS_SERVICE_YAML"
  _statefulset_yaml="$KYSO_SCS_STATEFULSET_YAML"
  # files
  _helm_values_yaml="$KYSO_SCS_HELM_VALUES_YAML"
  _pvc_yaml="$KYSO_SCS_PVC_YAML"
  _pv_yaml="$KYSO_SCS_PV_YAML"
  _svc_map_yaml="$KYSO_SCS_SVC_MAP_YAML"
  _cert_yamls=""
  for _hostname in $DEPLOYMENT_HOSTNAMES; do
    _cert_yaml="$KYSO_SCS_KUBECTL_DIR/tls-$_hostname${SOPS_EXT}.yaml"
    _cert_yamls="$_cert_yamls $_cert_yaml"
  done
  if find_namespace "$_ns"; then
    header "Removing '$_app' objects"
    # Remove legacy objects
    for _yaml in "$_deploy_yaml" "$_statefulset_yaml" "$_cronjobs_yaml" \
      "$_secret_yaml" "$_service_yaml" "$_ingress_yaml" \
      "$_indexer_configmap_yaml" $_cert_yamls; do
      kubectl_delete "$_yaml" || true
    done
    # Uninstall chart
    if [ -f "$_helm_values_yaml" ]; then
      helm uninstall -n "$_ns" "$_app" || true
      rm -f "$_helm_values_yaml"
    fi
    # Remove objects, including the volumes
    for _yaml in "$_pvc_yaml" "$_svc_map_yaml" $_cert_yamls "$_pv_yaml"; do
      kubectl_delete "$_yaml" || true
    done
    # Remove secrets
    apps_kyso_scs_secret_delete "$_deployment" "$_cluster"
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
  _vol_name="$_ns"
  if find_namespace "$_ns"; then
    echo "Namespace '$_ns' found, not removing volumes!"
  else
    _dirs="$(
      find "$CLUST_VOLUMES_DIR" -maxdepth 1 -type d \
        -name "$_vol_name" -printf "- %f\n"
    )"
    if [ "$_dirs" ]; then
      echo "Removing directories:"
      echo "$_dirs"
      find "$CLUST_VOLUMES_DIR" -maxdepth 1 -type d \
        -name "$_vol_name" -exec sudo rm -rf {} \;
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
    kubectl get -n "$_ns" all,cronjobs,endpoints,ingress,secrets,pvc
    echo ""
    kubectl get "pv/$_ns"

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
  echo "--- StatefulSet ---"
  statefulset_summary "$_ns" "$_app"
  echo "--- CronJobs ---"
  _cronjobs="$(kubectl -n "$_ns" get cronjob.batch -o name)"
  if [ "$_cronjobs" ]; then
    for _cj in $_cronjobs; do
      echo "- ${_cj#cronjob.batch/}"
    done
  else
    echo "No cronjobs found on namespace '$_ns'!"
  fi
}

apps_kyso_scs_env_edit() {
  if [ "$EDITOR" ]; then
    _app="kyso-scs"
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

apps_kyso_scs_env_path() {
  _app="kyso-scs"
  _deployment="$1"
  _cluster="$2"
  apps_export_variables "$_deployment" "$_cluster"
  _env_file="$DEPLOY_ENVS_DIR/$_app.env"
  echo "$_env_file"
}

apps_kyso_scs_env_save() {
  _app="kyso-scs"
  _deployment="$1"
  _cluster="$2"
  apps_export_variables "$_deployment" "$_cluster"
  _env_file="$DEPLOY_ENVS_DIR/$_app.env"
  apps_kyso_scs_check_directories
  apps_kyso_scs_print_variables "$_deployment" "$_cluster" |
    stdout_to_file "$_env_file"
}

apps_kyso_scs_env_update() {
  _app="kyso-scs"
  _deployment="$1"
  _cluster="$2"
  apps_export_variables "$_deployment" "$_cluster"
  _env_file="$DEPLOY_ENVS_DIR/$_app.env"
  header "$_app configuration variables"
  apps_kyso_scs_print_variables "$_deployment" "$_cluster" |
    grep -v "^#"
  if [ -f "$_env_file" ]; then
    footer
    read_bool "Update $_app env vars?" "No"
  else
    READ_VALUE="Yes"
  fi
  if is_selected "${READ_VALUE}"; then
    footer
    apps_kyso_scs_read_variables
    if [ -f "$_env_file" ]; then
      footer
      read_bool "Save updated $_app env vars?" "Yes"
    else
      READ_VALUE="Yes"
    fi
    if is_selected "${READ_VALUE}"; then
      apps_kyso_scs_env_save "$_deployment" "$_cluster"
      footer
      echo "$_app configuration saved to '$_env_file'"
      footer
    fi
  fi
}

apps_kyso_scs_command() {
  _command="$1"
  _deployment="$2"
  _cluster="$3"
  case "$_command" in
  get-secret)
    apps_kyso_scs_secret_get  "$_deployment" "$_cluster"
    ;;
  cat-host-keys)
    apps_kyso_scs_secret_cat_file "host_keys.txt" "$_deployment" "$_cluster"
    ;;
  cat-user-keys)
    apps_kyso_scs_secret_cat_file "user_keys.txt" "$_deployment" "$_cluster"
    ;;
  cat-user-pass)
    apps_kyso_scs_secret_cat_file "user_pass.txt" "$_deployment" "$_cluster"
    ;;
  cat-user-sids)
    apps_kyso_scs_secret_cat_file "user_sids.tgz" "$_deployment" "$_cluster"
    ;;
  cron-runjob)
    apps_kyso_scs_cron_runjob "$_deployment" "$_cluster"
    ;;
  cron-status)
    apps_kyso_scs_cron_status "$_deployment" "$_cluster"
    ;;
  env-edit | env_edit)
    apps_kyso_scs_env_edit "$_deployment" "$_cluster"
    ;;
  env-path | env_path)
    apps_kyso_scs_env_path "$_deployment" "$_cluster"
    ;;
  env-show | env_show)
    apps_kyso_scs_print_variables "$_deployment" "$_cluster" | grep -v '^#'
    ;;
  env-update | env_update)
    apps_kyso_scs_env_update "$_deployment" "$_cluster"
    ;;
  helm-history) apps_kyso_scs_helm_history "$_deployment" "$_cluster" ;;
  helm-rollback) apps_kyso_scs_helm_rollback "$_deployment" "$_cluster" ;;
  helm-uninstall) apps_kyso_scs_helm_uninstall "$_deployment" "$_cluster" ;;
  install) apps_kyso_scs_install "$_deployment" "$_cluster" ;;
  logs)
    case "$SCS_CONTAINER" in
    indexer | myssh | nginx | webhook)
      apps_kyso_scs_logs "$_deployment" "$_cluster" "$SCS_CONTAINER"
      ;;
    *)
      echo "Export SCS_CONTAINER with value {indexer|myssh|nginx|webhook}"
      ;;
    esac
    ;;
  reinstall) apps_kyso_scs_reinstall "$_deployment" "$_cluster" ;;
  remove) apps_kyso_scs_remove "$_deployment" "$_cluster" ;;
  rmvols) apps_kyso_scs_rmvols "$_deployment" "$_cluster" ;;
  restart) apps_kyso_scs_restart "$_deployment" "$_cluster" ;;
  sh)
    case "$SCS_CONTAINER" in
    indexer | myssh | nginx | webhook)
      apps_kyso_scs_sh "$_deployment" "$_cluster" "$SCS_CONTAINER"
      ;;
    *)
      echo "Export SCS_CONTAINER with value {indexer|myssh|nginx|webhook}"
      ;;
    esac
    ;;
  status) apps_kyso_scs_status "$_deployment" "$_cluster" ;;
  summary) apps_kyso_scs_summary "$_deployment" "$_cluster" ;;
  *)
    echo "Unknown kyso-scs subcommand '$1'"
    exit 1
    ;;
  esac
}

apps_kyso_scs_command_list() {
  _cmnds="cat-host-keys cat-user-keys cat-user-pass cat-user-sids get-secret"
  _cmnds="$_cmnds cron-runjob cron-status env-edit env-path env-show env-update"
  _cmnds="$_cmnds helm-history helm-rollback helm-uninstall install logs"
  _cmnds="$_cmnds reinstall remove restart rmvols sh status summary"
  echo "$_cmnds"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
