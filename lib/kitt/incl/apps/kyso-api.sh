#!/bin/sh
# ----
# File:        apps/kyso-api.sh
# Description: Functions to manage kyso-api deployments for kyso on k8s clusters
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_APPS_KYSO_API_SH="1"

# ---------
# Variables
# ---------

# CMND_DSC="kyso-api: manage kyso-api deployment for kyso"

# Defaults
export DEPLOYMENT_DEFAULT_KYSO_API_ENDPOINT=""
export DEPLOYMENT_DEFAULT_KYSO_API_IMAGE=""
export DEPLOYMENT_DEFAULT_KYSO_API_MAX_BODY_SIZE="500m"
export DEPLOYMENT_DEFAULT_KYSO_API_REPLICAS="1"
export DEPLOYMENT_DEFAULT_KYSO_API_DOCS_INGRESS="false"
export DEPLOYMENT_DEFAULT_KYSO_API_POPULATE_TEST_DATA="true"
export DEPLOYMENT_DEFAULT_KYSO_API_POPULATE_MAIL_PREFIX="lo"

# Fixed values
export KYSO_API_PORT="4000"
export KYSO_API_BASIC_AUTH_NAME="basic-auth"
export KYSO_API_BASIC_AUTH_USER="apidoc"

# --------
# Includes
# --------

if [ -d "$INCL_DIR" ]; then
  # shellcheck source=../common.sh
  [ "$INCL_COMMON_SH" = "1" ] || . "$INCL_DIR/common.sh"
  # shellcheck source=./common.sh
  [ "$INCL_APPS_COMMON_SH" = "1" ] || . "$INCL_DIR/apps/common.sh"
  # shellcheck source=./mongodb.sh
  [ "$INCL_APPS_MONGODB_SH" = "1" ] || . "$INCL_DIR/apps/mongodb.sh"
  # shellcheck source=./kyso-scs.sh
  [ "$INCL_APPS_KYSO_API_SCS_SH" = "1" ] || . "$INCL_DIR/apps/kyso-scs.sh"
fi

# ---------
# Functions
# ---------

apps_kyso_api_export_variables() {
  [ -z "$__apps_kyso_api_export_variables" ] || return 0
  _deployment="$1"
  _cluster="$2"
  apps_common_export_variables "$_deployment" "$_cluster"
  apps_mongodb_export_variables "$_deployment" "$_cluster"
  # Values
  export KYSO_API_NAMESPACE="kyso-api-$DEPLOYMENT_NAME"
  # Directories
  export KYSO_API_TMPL_DIR="$TMPL_DIR/apps/kyso-api"
  export KYSO_API_KUBECTL_DIR="$DEPLOY_KUBECTL_DIR/kyso-api"
  export KYSO_API_SECRETS_DIR="$DEPLOY_SECRETS_DIR/kyso-api"
  # Templates
  export KYSO_API_DEPLOY_TMPL="$KYSO_API_TMPL_DIR/deploy.yaml"
  export KYSO_API_ENDPOINT_TMPL="$KYSO_API_TMPL_DIR/endpoint.yaml"
  export KYSO_API_ENDPOINT_SVC_TMPL="$KYSO_API_TMPL_DIR/endpoint-svc.yaml"
  export KYSO_API_ENV_TMPL="$KYSO_API_TMPL_DIR/kyso-api.env"
  export KYSO_API_INGRESS_TMPL="$KYSO_API_TMPL_DIR/ingress.yaml"
  export KYSO_API_INGRESS_DOCS_TMPL="$KYSO_API_TMPL_DIR/ingress-docs.yaml"
  export KYSO_API_SECRET_TMPL="$KYSO_API_TMPL_DIR/secrets.yaml"
  export KYSO_API_SERVICE_TMPL="$KYSO_API_TMPL_DIR/service.yaml"
  # Files
  export KYSO_API_DEPLOY_YAML="$KYSO_API_KUBECTL_DIR/deploy.yaml"
  export KYSO_API_ENDPOINT_YAML="$KYSO_API_KUBECTL_DIR/endpoint.yaml"
  export KYSO_API_ENV_SECRET="$KYSO_API_SECRETS_DIR/kyso-api${SOPS_EXT}.env"
  export KYSO_API_SECRET_YAML="$KYSO_API_KUBECTL_DIR/secrets${SOPS_EXT}.yaml"
  export KYSO_API_SERVICE_YAML="$KYSO_API_KUBECTL_DIR/service.yaml"
  export KYSO_API_INGRESS_YAML="$KYSO_API_KUBECTL_DIR/ingress.yaml"
  export KYSO_API_INGRESS_DOCS_YAML="$KYSO_API_KUBECTL_DIR/ingress-docs.yaml"
  _auth_file="$KYSO_API_SECRETS_DIR/basic_auth${SOPS_EXT}.txt"
  export KYSO_API_AUTH_FILE="$_auth_file"
  _auth_yaml="$KYSO_API_KUBECTL_DIR/basic-auth${SOPS_EXT}.yaml"
  export KYSO_API_AUTH_YAML="$_auth_yaml"
  # Use defaults for variables missing from config files / enviroment
  if [ -z "$KYSO_API_ENDPOINT" ]; then
    if [ "$DEPLOYMENT_KYSO_API_ENDPOINT" ]; then
      KYSO_API_ENDPOINT="$DEPLOYMENT_KYSO_API_ENDPOINT"
    else
      KYSO_API_ENDPOINT="$DEPLOYMENT_DEFAULT_KYSO_API_ENDPOINT"
    fi
  fi
  export KYSO_API_ENDPOINT
  if [ -z "$KYSO_API_IMAGE" ]; then
    if [ "$DEPLOYMENT_KYSO_API_IMAGE" ]; then
      KYSO_API_IMAGE="$DEPLOYMENT_KYSO_API_IMAGE"
    else
      KYSO_API_IMAGE="$DEPLOYMENT_DEFAULT_KYSO_API_IMAGE"
    fi
  fi
  export KYSO_API_IMAGE
  if [ "$DEPLOYMENT_KYSO_API_MAX_BODY_SIZE" ]; then
    KYSO_API_MAX_BODY_SIZE="$DEPLOYMENT_KYSO_API_MAX_BODY_SIZE"
  else
    KYSO_API_MAX_BODY_SIZE="$DEPLOYMENT_DEFAULT_KYSO_API_MAX_BODY_SIZE"
  fi
  export KYSO_API_MAX_BODY_SIZE
  if [ "$DEPLOYMENT_KYSO_API_REPLICAS" ]; then
    KYSO_API_REPLICAS="$DEPLOYMENT_KYSO_API_REPLICAS"
  else
    KYSO_API_REPLICAS="$DEPLOYMENT_DEFAULT_KYSO_API_REPLICAS"
  fi
  export KYSO_API_REPLICAS
  if [ "$DEPLOYMENT_KYSO_API_DOCS_INGRESS" ]; then
    KYSO_API_DOCS_INGRESS="$DEPLOYMENT_KYSO_API_DOCS_INGRESS"
  else
    KYSO_API_DOCS_INGRESS="$DEPLOYMENT_DEFAULT_KYSO_API_DOCS_INGRESS"
  fi
  export KYSO_API_DOCS_INGRESS
  if [ "$DEPLOYMENT_KYSO_API_POPULATE_TEST_DATA" ]; then
    KYSO_API_POPULATE_TEST_DATA="$DEPLOYMENT_KYSO_API_POPULATE_TEST_DATA"
  else
    KYSO_API_POPULATE_TEST_DATA="$DEPLOYMENT_DEFAULT_KYSO_API_POPULATE_TEST_DATA"
  fi
  export KYSO_API_POPULATE_TEST_DATA
  if [ "$DEPLOYMENT_KYSO_API_POPULATE_MAIL_PREFIX" ]; then
    KYSO_API_POPULATE_MAIL_PREFIX="$DEPLOYMENT_KYSO_API_POPULATE_MAIL_PREFIX"
  else
    KYSO_API_POPULATE_MAIL_PREFIX="$DEPLOYMENT_DEFAULT_KYSO_API_POPULATE_MAIL_PREFIX"
  fi
  export KYSO_API_POPULATE_MAIL_PREFIX
  __apps_kyso_api_export_variables="1"
}

apps_kyso_api_check_directories() {
  apps_common_check_directories
  for _d in "$KYSO_API_KUBECTL_DIR" "$KYSO_API_SECRETS_DIR"; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

apps_kyso_api_clean_directories() {
  # Try to remove empty dirs, except if they contain secrets
  for _d in "$KYSO_API_KUBECTL_DIR" "$KYSO_API_SECRETS_DIR"; do
    if [ -d "$_d" ]; then
      rmdir "$_d" 2>/dev/null || true
    fi
  done
}

apps_kyso_api_read_variables() {
  header "Kyso API Settings"
  _ex_ep="$LINUX_HOST_IP:$KYSO_API_PORT"
  read_value "Kyso API Endpoint (i.e. '$_ex_ep' or '-' to deploy image)" \
    "${KYSO_API_ENDPOINT}"
  KYSO_API_ENDPOINT=${READ_VALUE}
  _ex_img="registry.kyso.io/kyso-io/kyso-api/develop:latest"
  read_value \
    "Kyso API Image URI (i.e. '$_ex_img' or export KYSO_API_IMAGE env var)" \
    "${KYSO_API_IMAGE}"
  KYSO_API_IMAGE=${READ_VALUE}
  read_value "Ingress max body size for Kyso API" "${KYSO_API_MAX_BODY_SIZE}"
  KYSO_API_MAX_BODY_SIZE=${READ_VALUE}
  read_value "Number of kyso-api replicas" "${KYSO_API_REPLICAS}"
  KYSO_API_REPLICAS=${READ_VALUE}
  read_bool "Add '/api/docs' entry on Kyso API Ingress" \
    "${KYSO_API_DOCS_INGRESS}"
  KYSO_API_DOCS_INGRESS=${READ_VALUE}
  read_bool "Populate test data on first run" "${KYSO_API_POPULATE_TEST_DATA}"
  KYSO_API_POPULATE_TEST_DATA=${READ_VALUE}
  read_value "Mail prefix for test data" "${KYSO_API_POPULATE_MAIL_PREFIX}"
  KYSO_API_POPULATE_MAIL_PREFIX=${READ_VALUE}
}

apps_kyso_api_print_variables() {
  cat <<EOF
# Kyso API Settings
# ---
# Endpoint for Kyso API (replaces the real deployment on development systems),
# set to:
# - '$LINUX_HOST_IP:$KYSO_API_PORT' on Linux
# - '$MACOS_HOST_IP:$KYSO_API_PORT' on systems using Docker Desktop (Mac/Win)
KYSO_API_ENDPOINT=$KYSO_API_ENDPOINT
# Kyso API Image URI, examples for local testing:
# - 'registry.kyso.io/kyso-io/kyso-api/develop:latest'
# - 'k3d-registry.lo.kyso.io:5000/kyso-api:latest'
# If left empty the KYSO_API_IMAGE environment variable has to be set each time
# the kyso-api service is installed
KYSO_API_IMAGE=$KYSO_API_IMAGE
# Kyso API Ingress Max Body Size (the default must be OK)
KYSO_API_MAX_BODY_SIZE=$KYSO_API_MAX_BODY_SIZE
# Number of pods to run in parallel
KYSO_API_REPLICAS=$KYSO_API_REPLICAS
# Set to 'true' to add the '/api/docs' entry on the Kyso API Ingress
KYSO_API_DOCS_INGRESS=$KYSO_API_DOCS_INGRESS
# Set to 'true' to populate the database on the first run (useful for dev)
KYSO_API_POPULATE_TEST_DATA=$KYSO_API_POPULATE_TEST_DATA
# Mail user on @dev.kyso.io that gets the test users mail
KYSO_API_POPULATE_MAIL_PREFIX=$KYSO_API_POPULATE_MAIL_PREFIX
# ---
EOF
}

apps_kyso_api_logs() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_api_export_variables "$_deployment" "$_cluster"
  _ns="$KYSO_API_NAMESPACE"
  _label="app=kyso-api"
  kubectl -n "$_ns" logs -l "$_label" -f
}

apps_kyso_api_install() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_api_export_variables "$_deployment" "$_cluster"
  if [ -z "$KYSO_API_ENDPOINT" ] && [ -z "$KYSO_API_IMAGE" ]; then
    echo "The API_IMAGE & API_ENDPOINT variables are is empty"
    echo "Export KYSO_API_IMAGE, KYSO_API_ENDPOINT or reconfigure"
    exit 1
  fi
  apps_kyso_api_check_directories
  # Initial test
  if ! find_namespace "$MONGODB_NAMESPACE"; then
    read_bool "mongodb namespace not found, abort install?" "Yes"
    if is_selected "${READ_VALUE}"; then
      return 1
    fi
  fi
  # Adjust variables
  _app="kyso-api"
  _ns="$KYSO_API_NAMESPACE"
  _ep_tmpl="$KYSO_API_ENDPOINT_TMPL"
  _ep_yaml="$KYSO_API_ENDPOINT_YAML"
  _env_tmpl="$KYSO_API_ENV_TMPL"
  _secret_env="$KYSO_API_ENV_SECRET"
  _secret_tmpl="$KYSO_API_SECRET_TMPL"
  _secret_yaml="$KYSO_API_SECRET_YAML"
  _service_tmpl="$KYSO_API_SERVICE_TMPL"
  _service_yaml="$KYSO_API_SERVICE_YAML"
  _deploy_tmpl="$KYSO_API_DEPLOY_TMPL"
  _deploy_yaml="$KYSO_API_DEPLOY_YAML"
  _ingress_tmpl="$KYSO_API_INGRESS_TMPL"
  _ingress_yaml="$KYSO_API_INGRESS_YAML"
  _ingress_docs_tmpl="$KYSO_API_INGRESS_DOCS_TMPL"
  _ingress_docs_yaml="$KYSO_API_INGRESS_DOCS_YAML"
  if is_selected "$CLUSTER_USE_BASIC_AUTH" &&
    is_selected "$KYSO_API_DOCS_INGRESS"; then
    _auth_name="$KYSO_API_BASIC_AUTH_NAME"
    _auth_user="$KYSO_API_BASIC_AUTH_USER"
    _auth_file="$KYSO_API_AUTH_FILE"
  else
    _auth_name=""
    _auth_user=""
    _auth_file=""
  fi
  _auth_yaml="$KYSO_API_AUTH_YAML"
  _cert_yamls=""
  for _hostname in $DEPLOYMENT_HOSTNAMES; do
    _cert_yaml="$KYSO_API_KUBECTL_DIR/tls-$_hostname${SOPS_EXT}.yaml"
    _cert_yamls="$_cert_yamls $_cert_yaml"
  done
  _elastic_url="http://elasticsearch-master.elasticsearch-$DEPLOYMENT_NAME"
  _elastic_url="$_elastic_url.svc.cluster.local:9200"
  if ! find_namespace "$_ns"; then
    # Remove old files, just in case ...
    # shellcheck disable=SC2086
    rm -f "$_ep_yaml" "$_secret_yaml" "$_auth_yaml" "$_service_yaml" \
      "$_deploy_yaml" "$_ingress_yaml" "$_ingress_docs_yaml" $_cert_yamls
    # Create namespace
    create_namespace "$_ns"
  fi
  if [ "$KYSO_API_ENDPOINT" ]; then
    # Remove service if we are switching from a deployment, otherwise we already
    # have an endpoint linked to the service and the creation generates a warn
    if [ -f "$_service_yaml" ]; then
      if [ ! -f "$_ep_yaml" ]; then
        kubectl_delete "$_service_yaml" || true
      fi
      rm -f "$_secret_env"
    fi
    # Remove deployment related files
    for _yaml in "$_secret_yaml" "$_deploy_yaml"; do
      kubectl_delete "$_yaml" || true
    done
    rm -f "$_secret_env"
    # Generate / update endpoint yaml
    _api_addr="${KYSO_API_ENDPOINT%:*}"
    _api_port="${KYSO_API_ENDPOINT#*:}"
    [ "$_api_port" != "$_api_addr" ] || _api_port="$KYSO_API_PORT"
    sed \
      -e "s%__APP__%$_app%" \
      -e "s%__NAMESPACE__%$_ns%" \
      -e "s%__SERVER_ADDR__%$_api_addr%" \
      -e "s%__SERVER_PORT__%$_api_port%" \
      "$_ep_tmpl" >"$_ep_yaml"
    # Use the right service template
    _service_tmpl="$KYSO_API_ENDPOINT_SVC_TMPL"
  else
    # Remove endpoint if switching
    kubectl_delete "$_ep_yaml" || true
    # Adjust the api port
    _api_port="$KYSO_API_PORT"
    # Use the right service template
    _service_tmpl="$KYSO_API_SERVICE_TMPL"
    # Prepare deployment file
    sed \
      -e "s%__APP__%$_app%" \
      -e "s%__NAMESPACE__%$_ns%" \
      -e "s%__API_REPLICAS__%$KYSO_API_REPLICAS%" \
      -e "s%__API_IMAGE__%$KYSO_API_IMAGE%" \
      -e "s%__IMAGE_PULL_POLICY__%$IMAGE_PULL_POLICY%" \
      -e "s%__ELASTIC_URL__%$_elastic_url%" \
      "$_deploy_tmpl" >"$_deploy_yaml"
    # Prepare secrets
    : >"$_secret_env"
    chmod 0600 "$_secret_env"
    _mongodb_user_database_uri="$(
      apps_mongodb_print_user_database_uri "$_deployment" "$_cluster"
    )"
    sed \
      -e "s%__POPULATE_TEST_DATA__%$KYSO_API_POPULATE_TEST_DATA%" \
      -e "s%__MONGODB_DATABASE_URI__%$_mongodb_user_database_uri%" \
      -e "s%__POPULATE_MAIL_PREFIX__%$KYSO_API_POPULATE_MAIL_PREFIX%" \
      "$_env_tmpl" |
      stdout_to_file "$_secret_env"
    : >"$_secret_yaml"
    chmod 0600 "$_secret_yaml"
    tmp_dir="$(mktemp -d)"
    file_to_stdout "$_secret_env" >"$tmp_dir/env"
    kubectl create secret generic "$_app-secrets" --dry-run=client -o yaml \
      --from-file=env="$tmp_dir/env" --namespace="$_ns" |
      stdout_to_file "$_secret_yaml"
    rm -rf "$tmp_dir"
  fi
  # Create htpasswd & docs ingress if needed or remove the yaml files if present
  if [ "$_auth_name" ]; then
    create_htpasswd_secret_yaml "$_ns" "$_auth_name" "$_auth_user" \
      "$_auth_file" "$_auth_yaml"
    # Create ingress for docs
    create_app_ingress_yaml "$_ns" "$_app" "$_ingress_docs_tmpl" \
      "$_ingress_docs_yaml" "$_auth_name" ""
  else
    kubectl_delete "$_auth_yaml" || true
    kubectl_delete "$_ingress_docs_yaml" || true
  fi
  # Create certificate secrets if needed or remove them if not
  if is_selected "$DEPLOYMENT_INGRESS_TLS_CERTS"; then
    create_app_cert_yamls "$_ns" "$KYSO_API_KUBECTL_DIR"
  else
    for _hostname in $DEPLOYMENT_HOSTNAMES; do
      _cert_yaml="$KYSO_API_KUBECTL_DIR/tls-$_hostname${SOPS_EXT}.yaml"
      kubectl_delete "$_cert_yaml" || true
    done
  fi
  # Create ingress definition
  create_app_ingress_yaml "$_ns" "$_app" "$_ingress_tmpl" "$_ingress_yaml" \
    "" ""
  # Prepare service_yaml
  sed \
    -e "s%__APP__%$_app%" \
    -e "s%__NAMESPACE__%$_ns%" \
    -e "s%__SERVER_PORT__%$_api_port%" \
    "$_service_tmpl" >"$_service_yaml"
  for _yaml in "$_ep_yaml" "$_secret_yaml" "$_auth_yaml" "$_service_yaml" \
    "$_deploy_yaml" "$_ingress_yaml" "$_ingress_docs_yaml" $_cert_yamls; do
    kubectl_apply "$_yaml"
  done
  # Wait until deployment succeds or fails (if there is one, of course)
  if [ -f "$_deploy_yaml" ]; then
    kubectl rollout status deployment --timeout="$ROLLOUT_STATUS_TIMEOUT" \
      -n "$_ns" "$_app"
    # If we succeed update the api settings with the kyso-scs settings
    apps_kyso_scs_update_api_settings "$_deployment" "$_cluster"
  fi
}

apps_kyso_api_remove() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_api_export_variables "$_deployment" "$_cluster"
  _app="kyso-api"
  _ns="$KYSO_API_NAMESPACE"
  _ep_yaml="$KYSO_API_ENDPOINT_YAML"
  _secret_yaml="$KYSO_API_SECRET_YAML"
  _service_yaml="$KYSO_API_SERVICE_YAML"
  _deploy_yaml="$KYSO_API_DEPLOY_YAML"
  _ingress_yaml="$KYSO_API_INGRESS_YAML"
  _auth_yaml="$KYSO_API_AUTH_YAML"
  _cert_yamls=""
  for _hostname in $DEPLOYMENT_HOSTNAMES; do
    _cert_yaml="$KYSO_API_KUBECTL_DIR/tls-$_hostname${SOPS_EXT}.yaml"
    _cert_yamls="$_cert_yamls $_cert_yaml"
  done
  if find_namespace "$_ns"; then
    header "Removing '$_app' objects"
    for _yaml in "$_ep_yaml" "$_secret_yaml" "$_auth_yaml" "$_service_yaml" \
      "$_deploy_yaml" "$_ingress_yaml" $_cert_yamls; do
      kubectl_delete "$_yaml" || true
    done
    delete_namespace "$_ns"
    footer
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
  apps_kyso_api_clean_directories
}

apps_kyso_api_restart() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_api_export_variables "$_deployment" "$_cluster"
  _app="kyso-api"
  _ns="$KYSO_API_NAMESPACE"
  if find_namespace "$_ns"; then
    deployment_restart "$_ns" "$_app"
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

apps_kyso_api_status() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_api_export_variables "$_deployment" "$_cluster"
  _app="kyso-api"
  _ns="$KYSO_API_NAMESPACE"
  if find_namespace "$_ns"; then
    kubectl get all,endpoints,ingress,secrets -n "$_ns"
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

apps_kyso_api_summary() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_api_export_variables "$_deployment" "$_cluster"
  _ns="$KYSO_API_NAMESPACE"
  _app="kyso-api"
  deployment_summary "$_ns" "$_app"
}

apps_kyso_api_uris() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_api_export_variables "$_deployment" "$_cluster"
  _hostname="${DEPLOYMENT_HOSTNAMES%% *}"
  echo "https://$_hostname/api/"
  if is_selected "$KYSO_API_DOCS_INGRESS"; then
    if is_selected "$CLUSTER_USE_BASIC_AUTH" &&
      is_selected "$KYSO_API_DOCS_INGRESS" &&
      [ -f "$KYSO_API_AUTH_FILE" ]; then
      _uap="$(file_to_stdout "$KYSO_API_AUTH_FILE")"
      echo "https://$_uap@$_hostname/api/docs/"
    else
      echo "https://$_hostname/api/docs/"
    fi
  fi
}

apps_kyso_api_command() {
  _command="$1"
  _deployment="$2"
  _cluster="$3"
  case "$_command" in
  logs) apps_kyso_api_logs "$_deployment" "$_cluster" ;;
  install) apps_kyso_api_install "$_deployment" "$_cluster" ;;
  restart) apps_kyso_api_restart "$_deployment" "$_cluster" ;;
  remove) apps_kyso_api_remove "$_deployment" "$_cluster" ;;
  status) apps_kyso_api_status "$_deployment" "$_cluster" ;;
  summary) apps_kyso_api_summary "$_deployment" "$_cluster" ;;
  uris) apps_kyso_api_uris "$_deployment" "$_cluster" ;;
  *)
    echo "Unknown kyso-api subcommand '$1'"
    exit 1
    ;;
  esac
}

apps_kyso_api_command_list() {
  echo "logs install remove restart status summary uris"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
