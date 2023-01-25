#!/bin/sh
# ----
# File:        apps/kyso-api.sh
# Description: Functions to manage kyso-api deployments for kyso on k8s clusters
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022-2023 Sergio Talens-Oliag <sto@kyso.io>
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
export KYSO_API_SERVER_PORT="4000"
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
  export KYSO_API_CHART_DIR="$CHARTS_DIR/kyso-api"
  export KYSO_API_TMPL_DIR="$TMPL_DIR/apps/kyso-api"
  export KYSO_API_HELM_DIR="$DEPLOY_HELM_DIR/kyso-api"
  export KYSO_API_KUBECTL_DIR="$DEPLOY_KUBECTL_DIR/kyso-api"
  export KYSO_API_SECRETS_DIR="$DEPLOY_SECRETS_DIR/kyso-api"
  # Templates
  export KYSO_API_HELM_VALUES_TMPL="$KYSO_API_TMPL_DIR/values.yaml"
  export KYSO_API_SVC_MAP_TMPL="$KYSO_API_TMPL_DIR/svc_map.yaml"
  # BEG: deprecated files
  export KYSO_API_DEPLOY_YAML="$KYSO_API_KUBECTL_DIR/deploy.yaml"
  export KYSO_API_ENDPOINT_YAML="$KYSO_API_KUBECTL_DIR/endpoint.yaml"
  export KYSO_API_ENV_SECRET="$KYSO_API_SECRETS_DIR/kyso-api${SOPS_EXT}.env"
  export KYSO_API_SECRET_YAML="$KYSO_API_KUBECTL_DIR/secrets${SOPS_EXT}.yaml"
  export KYSO_API_SERVICE_YAML="$KYSO_API_KUBECTL_DIR/service.yaml"
  export KYSO_API_INGRESS_YAML="$KYSO_API_KUBECTL_DIR/ingress.yaml"
  export KYSO_API_INGRESS_DOCS_YAML="$KYSO_API_KUBECTL_DIR/ingress-docs.yaml"
  _auth_yaml="$KYSO_API_KUBECTL_DIR/basic-auth${SOPS_EXT}.yaml"
  export KYSO_API_AUTH_YAML="$_auth_yaml"
  # END: deprecated files
  # Files
  _auth_file="$KYSO_API_SECRETS_DIR/basic_auth${SOPS_EXT}.txt"
  export KYSO_API_AUTH_FILE="$_auth_file"
  _helm_values_yaml="$KYSO_API_HELM_DIR/values${SOPS_EXT}.yaml"
  _helm_values_yaml_plain="$KYSO_API_HELM_DIR/values.yaml"
  export KYSO_API_HELM_VALUES_YAML="$_helm_values_yaml"
  export KYSO_API_HELM_VALUES_YAML_PLAIN="$_helm_values_yaml_plain"
  export KYSO_API_SVC_MAP_YAML="$KYSO_API_KUBECTL_DIR/svc_map.yaml"
  # By default don't auto save the environment
  KYSO_API_AUTO_SAVE_ENV="false"
  # Use defaults for variables missing from config files / enviroment
  if [ -z "$KYSO_API_ENDPOINT" ]; then
    if [ "$DEPLOYMENT_KYSO_API_ENDPOINT" ]; then
      KYSO_API_ENDPOINT="$DEPLOYMENT_KYSO_API_ENDPOINT"
    else
      KYSO_API_ENDPOINT="$DEPLOYMENT_DEFAULT_KYSO_API_ENDPOINT"
    fi
  else
    KYSO_API_AUTO_SAVE_ENV="true"
  fi
  export KYSO_API_ENDPOINT
  if [ -z "$KYSO_API_IMAGE" ]; then
    if [ "$DEPLOYMENT_KYSO_API_IMAGE" ]; then
      KYSO_API_IMAGE="$DEPLOYMENT_KYSO_API_IMAGE"
    else
      KYSO_API_IMAGE="$DEPLOYMENT_DEFAULT_KYSO_API_IMAGE"
    fi
  else
    KYSO_API_AUTO_SAVE_ENV="true"
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
    _v="$DEPLOYMENT_KYSO_API_POPULATE_TEST_DATA"
  else
    _v="$DEPLOYMENT_DEFAULT_KYSO_API_POPULATE_TEST_DATA"
  fi
  export KYSO_API_POPULATE_TEST_DATA="$_v"
  if [ "$DEPLOYMENT_KYSO_API_POPULATE_MAIL_PREFIX" ]; then
    _v="$DEPLOYMENT_KYSO_API_POPULATE_MAIL_PREFIX"
  else
    _v="$DEPLOYMENT_DEFAULT_KYSO_API_POPULATE_MAIL_PREFIX"
  fi
  export KYSO_API_POPULATE_MAIL_PREFIX="$_v"
  _v=""
  # Export auto save environment flag
  export KYSO_API_AUTO_SAVE_ENV
  __apps_kyso_api_export_variables="1"
}

apps_kyso_api_check_directories() {
  apps_common_check_directories
  for _d in "$KYSO_API_HELM_DIR" "$KYSO_API_KUBECTL_DIR" \
    "$KYSO_API_SECRETS_DIR"; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

apps_kyso_api_clean_directories() {
  # Try to remove empty dirs, except if they contain secrets
  for _d in "$KYSO_API_HELM_DIR" "$KYSO_API_KUBECTL_DIR" \
    "$KYSO_API_SECRETS_DIR"; do
    if [ -d "$_d" ]; then
      rmdir "$_d" 2>/dev/null || true
    fi
  done
}

apps_kyso_api_read_variables() {
  _app="kyso-api"
  header "Reading $_app settings"
  _ex_ep="$LINUX_HOST_IP:$KYSO_API_SERVER_PORT"
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
  _app="kyso-api"
  cat <<EOF
# Deployment $_app settings
# ---
# Endpoint for Kyso API (replaces the real deployment on development systems),
# set to:
# - '$LINUX_HOST_IP:$KYSO_API_SERVER_PORT' on Linux
# - '$MACOS_HOST_IP:$KYSO_API_SERVER_PORT' on systems using Docker Desktop
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
  _app="kyso-api"
  _ns="$KYSO_API_NAMESPACE"
  if kubectl get -n "$_ns" "deployments/$_app" >/dev/null 2>&1; then
    kubectl -n "$_ns" logs "deployments/$_app" -f
  else
    echo "Deployment '$_app' not found on namespace '$_ns'"
  fi
}

apps_kyso_api_sh() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_api_export_variables "$_deployment" "$_cluster"
  _app="kyso-api"
  _ns="$KYSO_API_NAMESPACE"
  if kubectl get -n "$_ns" "deployments/$_app" >/dev/null 2>&1; then
    kubectl -n "$_ns" exec -ti "deployments/$_app" -- /bin/sh
  else
    echo "Deployment '$_app' not found on namespace '$_ns'"
  fi
}


apps_kyso_api_install() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_api_export_variables "$_deployment" "$_cluster"
  if [ -z "$KYSO_API_ENDPOINT" ] && [ -z "$KYSO_API_IMAGE" ]; then
    echo "The API_IMAGE & API_ENDPOINT variables are empty."
    echo "Export KYSO_API_IMAGE or KYSO_API_ENDPOINT or reconfigure."
    exit 1
  fi
  # Initial tests
  if ! find_namespace "$MONGODB_NAMESPACE"; then
    read_bool "mongodb namespace not found, abort install?" "Yes"
    if is_selected "${READ_VALUE}"; then
      return 1
    fi
  fi
  if ! find_namespace "$NATS_NAMESPACE"; then
    read_bool "nats namespace not found, abort install?" "Yes"
    if is_selected "${READ_VALUE}"; then
      return 1
    fi
  fi
  # Auto save the configuration if requested
  if is_selected "$KYSO_API_AUTO_SAVE_ENV"; then
    apps_kyso_api_env_save "$_deployment" "$_cluster"
  fi
  # Load additional variables & check directories
  apps_common_export_service_hostnames "$_deployment" "$_cluster"
  apps_kyso_api_check_directories
  # Adjust variables
  _app="kyso-api"
  _ns="$KYSO_API_NAMESPACE"
  # directories
  _chart="$KYSO_API_CHART_DIR"
  # deprecated yaml files
  _auth_yaml="$KYSO_API_AUTH_YAML"
  _deploy_yaml="$KYSO_API_DEPLOY_YAML"
  _ep_yaml="$KYSO_API_ENDPOINT_YAML"
  _ingress_docs_yaml="$KYSO_API_INGRESS_DOCS_YAML"
  _ingress_yaml="$KYSO_API_INGRESS_YAML"
  _secret_yaml="$KYSO_API_SECRET_YAML"
  _service_yaml="$KYSO_API_SERVICE_YAML"
  # files
  _helm_values_tmpl="$KYSO_API_HELM_VALUES_TMPL"
  _helm_values_yaml="$KYSO_API_HELM_VALUES_YAML"
  _helm_values_yaml_plain="$KYSO_API_HELM_VALUES_YAML_PLAIN"
  _svc_map_tmpl="$KYSO_API_SVC_MAP_TMPL"
  _svc_map_yaml="$KYSO_API_SVC_MAP_YAML"
  _auth_user="$KYSO_API_BASIC_AUTH_USER"
  if is_selected "$CLUSTER_USE_BASIC_AUTH" &&
    is_selected "$KYSO_API_DOCS_INGRESS"; then
    auth_file_update "$KYSO_API_BASIC_AUTH_USER" "$KYSO_API_AUTH_FILE"
    _auth_pass="$(
      file_to_stdout "$KYSO_API_AUTH_FILE" | sed -ne "s/^${_auth_user}://p"
    )"
  else
    _auth_pass=""
  fi
  _cert_yamls=""
  for _hostname in $DEPLOYMENT_HOSTNAMES; do
    _cert_yaml="$KYSO_API_KUBECTL_DIR/tls-$_hostname${SOPS_EXT}.yaml"
    _cert_yamls="$_cert_yamls $_cert_yaml"
  done
  if ! find_namespace "$_ns"; then
    # Remove old files, just in case ...
    # shellcheck disable=SC2086
    rm -f "$_helm_values_yaml" "$_svc_map_yaml" \
      "$_ep_yaml" "$_secret_yaml" "$_auth_yaml" "$_service_yaml" \
      "$_deploy_yaml" "$_ingress_yaml" "$_ingress_docs_yaml" $_cert_yamls
    # Create namespace
    create_namespace "$_ns"
  fi
  # If we have a legacy deployment, remove the old objects
  for _yaml in "$_ep_yaml" "$_secret_yaml" "$_auth_yaml" "$_service_yaml" \
    "$_deploy_yaml" "$_ingress_yaml" "$_ingress_docs_yaml"; do
    kubectl_delete "$_yaml" || true
  done
  # Image settings
  _image_repo="${KYSO_API_IMAGE%:*}"
  _image_tag="${KYSO_API_IMAGE#*:}"
  if [ "$_image_repo" = "$_image_tag" ]; then
    _image_tag="latest"
  fi
  # Endpoint settings
  if [ "$KYSO_API_ENDPOINT" ]; then
    # Generate / update endpoint values
    _ep_enabled="true"
  else
    # Adjust the api port
    _ep_enabled="false"
  fi
  _ep_addr="${KYSO_API_ENDPOINT%:*}"
  _ep_port="${KYSO_API_ENDPOINT#*:}"
  [ "$_ep_port" != "$_ep_addr" ] || _ep_port="$KYSO_API_SERVER_PORT"
  # Service settings
  _server_port="$KYSO_API_SERVER_PORT"
  # Get the database uri
  _mongodb_user_database_uri="$(
    apps_mongodb_print_user_database_uri "$_deployment" "$_cluster"
  )"
  # Prepare values.yaml file
  sed \
    -e "s%__API_REPLICAS__%$KYSO_API_REPLICAS%" \
    -e "s%__API_IMAGE_REPO__%$_image_repo%" \
    -e "s%__API_IMAGE_TAG__%$_image_tag%" \
    -e "s%__IMAGE_PULL_POLICY__%$DEPLOYMENT_IMAGE_PULL_POLICY%" \
    -e "s%__PULL_SECRETS_NAME__%$CLUSTER_PULL_SECRETS_NAME%" \
    -e "s%__API_ENDPOINT_ENABLED__%$_ep_enabled%" \
    -e "s%__API_ENDPOINT_ADDR__%$_ep_addr%" \
    -e "s%__API_ENDPOINT_PORT__%$_ep_port%" \
    -e "s%__API_SERVER_PORT__%$_server_port%" \
    -e "s%__API_DOCS_INGRESS__%$KYSO_API_DOCS_INGRESS%" \
    -e "s%__BASIC_AUTH_USER__%$_auth_user%" \
    -e "s%__BASIC_AUTH_PASS__%$_auth_pass%" \
    -e "s%__MAX_BODY_SIZE__%$KYSO_API_MAX_BODY_SIZE%g" \
    -e "s%__POPULATE_TEST_DATA__%$KYSO_API_POPULATE_TEST_DATA%" \
    -e "s%__MONGODB_DATABASE_URI__%$_mongodb_user_database_uri%" \
    -e "s%__POPULATE_MAIL_PREFIX__%$KYSO_API_POPULATE_MAIL_PREFIX%" \
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
    -e "s%__KYSO_NBDIME_SVC_HOSTNAME__%$KYSO_NBDIME_SVC_HOSTNAME%" \
    -e "s%__KYSO_SCS_SVC_HOSTNAME__%$KYSO_SCS_SVC_HOSTNAME%" \
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
  # Install map and certs
  for _yaml in "$_svc_map_yaml" $_cert_yamls; do
    kubectl_apply "$_yaml"
  done
  # If moving from deployment to endpoint add annotations to the automatic
  # endpoint to avoid issues with the upgrade
  if [ "$KYSO_API_ENDPOINT" ]; then
    if [ "$(kubectl get -n "$_ns" "deployments" -o name)" ]; then
      kubectl annotate -n "$_ns" --overwrite "endpoints/$_app" \
        "meta.helm.sh/release-name=$_app" \
        "meta.helm.sh/release-namespace=$_ns"
    fi
  fi
  # Install helm chart
  helm_upgrade "$_ns" "$_helm_values_yaml" "$_app" "$_chart"
  # Wait until deployment succeds or fails (if there is one, of course)
  if [ -z "$KYSO_API_ENDPOINT" ]; then
    kubectl rollout status deployment --timeout="$ROLLOUT_STATUS_TIMEOUT" \
      -n "$_ns" "$_app"
  fi
  # If we succeed update the api settings
  apps_kyso_update_api_settings "$_deployment" "$_cluster"
}

apps_kyso_api_helm_history() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_api_export_variables "$_deployment" "$_cluster"
  _app="kyso-api"
  _ns="$KYSO_API_NAMESPACE"
  if find_namespace "$_ns"; then
    helm_history "$_ns" "$_app"
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

apps_kyso_api_helm_rollback() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_api_export_variables "$_deployment" "$_cluster"
  _app="kyso-api"
  _ns="$KYSO_API_NAMESPACE"
  _release="$ROLLBACK_RELEASE"
  if find_namespace "$_ns"; then
    # Add annotations to the endpoint if we have a deployment, just in case
    if [ "$(kubectl get -n "$_ns" "deployments" -o name)" ]; then
      kubectl annotate -n "$_ns" --overwrite "endpoints/$_app" \
        "meta.helm.sh/release-name=$_app" \
        "meta.helm.sh/release-namespace=$_ns"
    fi
    # Execute the rollback
    helm_rollback "$_ns" "$_app" "$_release"
    # If we succeed update the api settings
    apps_kyso_update_api_settings "$_deployment" "$_cluster"
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

apps_kyso_api_reinstall() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_api_export_variables "$_deployment" "$_cluster"
  _app="kyso-api"
  _ns="$KYSO_API_NAMESPACE"
  if find_namespace "$_ns"; then
    _cimages="$(deployment_container_images "$_ns" "$_app")"
    _cname="kyso-api"
    KYSO_API_IMAGE="$(echo "$_cimages" | sed -ne "s/^$_cname //p")"
    if [ "$KYSO_API_IMAGE" ]; then
      export KYSO_API_IMAGE
      apps_kyso_api_install "$_deployment" "$_cluster"
    else
      echo "Image for '$_app' on '$_ns' not found!"
    fi
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

apps_kyso_api_remove() {
  _deployment="$1"
  _cluster="$2"
  apps_kyso_api_export_variables "$_deployment" "$_cluster"
  _app="kyso-api"
  _ns="$KYSO_API_NAMESPACE"
  # deprecated yaml files
  _auth_yaml="$KYSO_API_AUTH_YAML"
  _deploy_yaml="$KYSO_API_DEPLOY_YAML"
  _ep_yaml="$KYSO_API_ENDPOINT_YAML"
  _ingress_docs_yaml="$KYSO_API_INGRESS_DOCS_YAML"
  _ingress_yaml="$KYSO_API_INGRESS_YAML"
  _secret_yaml="$KYSO_API_SECRET_YAML"
  _service_yaml="$KYSO_API_SERVICE_YAML"
  # files
  _helm_values_yaml="$KYSO_API_HELM_VALUES_YAML"
  _svc_map_yaml="$KYSO_API_SVC_MAP_YAML"
  _cert_yamls=""
  for _hostname in $DEPLOYMENT_HOSTNAMES; do
    _cert_yaml="$KYSO_API_KUBECTL_DIR/tls-$_hostname${SOPS_EXT}.yaml"
    _cert_yamls="$_cert_yamls $_cert_yaml"
  done
  if find_namespace "$_ns"; then
    header "Removing '$_app' objects"
    # Uninstall chart
    if [ -f "$_helm_values_yaml" ]; then
      helm uninstall -n "$_ns" "$_app" || true
      rm -f "$_helm_values_yaml"
    fi
    # Remove objects
    for _yaml in "$_svc_map_yaml" $_cert_yamls; do
      kubectl_delete "$_yaml" || true
    done
    # Remove legacy objects
    for _yaml in "$_ep_yaml" "$_secret_yaml" "$_auth_yaml" "$_service_yaml" \
      "$_deploy_yaml" "$_ingress_yaml"; do
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
  _ep="$KYSO_API_ENDPOINT"
  if [ "$_ep" ]; then
    _endpoint="$(
      kubectl get endpoints -n "$_ns" -l "app.kubernetes.io/name=$_app" -o name
    )"
    if [ "$_endpoint" ]; then
      echo "FOUND endpoint for '$_app' in namespace '$_ns'"
      echo "- $_endpoint: $_ep"
    else
      echo "MISSING endpoint for '$_app' in namespace '$_ns'"
    fi
  else
    deployment_summary "$_ns" "$_app"
  fi
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

apps_kyso_api_env_edit() {
  if [ "$EDITOR" ]; then
    _app="kyso-api"
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

apps_kyso_api_env_path() {
  _app="kyso-api"
  _deployment="$1"
  _cluster="$2"
  apps_export_variables "$_deployment" "$_cluster"
  _env_file="$DEPLOY_ENVS_DIR/$_app.env"
  echo "$_env_file"
}

apps_kyso_api_env_save() {
  _app="kyso-api"
  _deployment="$1"
  _cluster="$2"
  apps_export_variables "$_deployment" "$_cluster"
  _env_file="$DEPLOY_ENVS_DIR/$_app.env"
  apps_kyso_api_check_directories
  apps_kyso_api_print_variables "$_deployment" "$_cluster" |
    stdout_to_file "$_env_file"
}

apps_kyso_api_env_update() {
  _app="kyso-api"
  _deployment="$1"
  _cluster="$2"
  apps_export_variables "$_deployment" "$_cluster"
  _env_file="$DEPLOY_ENVS_DIR/$_app.env"
  header "$_app configuration variables"
  apps_kyso_api_print_variables "$_deployment" "$_cluster" |
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
    apps_kyso_api_read_variables
    if [ -f "$_env_file" ]; then
      footer
      read_bool "Save updated $_app env vars?" "Yes"
    else
      READ_VALUE="Yes"
    fi
    if is_selected "${READ_VALUE}"; then
      apps_kyso_api_env_save "$_deployment" "$_cluster"
      footer
      echo "$_app configuration saved to '$_env_file'"
      footer
    fi
  fi
}

apps_kyso_api_command() {
  _command="$1"
  _deployment="$2"
  _cluster="$3"
  case "$_command" in
  env-edit | env_edit)
    apps_kyso_api_env_edit "$_deployment" "$_cluster"
    ;;
  env-path | env_path)
    apps_kyso_api_env_path "$_deployment" "$_cluster"
    ;;
  env-show | env_show)
    apps_kyso_api_print_variables "$_deployment" "$_cluster" | grep -v '^#'
    ;;
  env-update | env_update)
    apps_kyso_api_env_update "$_deployment" "$_cluster"
    ;;
  helm-history) apps_kyso_api_helm_history "$_deployment" "$_cluster" ;;
  helm-rollback) apps_kyso_api_helm_rollback "$_deployment" "$_cluster" ;;
  install) apps_kyso_api_install "$_deployment" "$_cluster" ;;
  logs) apps_kyso_api_logs "$_deployment" "$_cluster" ;;
  reinstall) apps_kyso_api_reinstall "$_deployment" "$_cluster" ;;
  remove) apps_kyso_api_remove "$_deployment" "$_cluster" ;;
  restart) apps_kyso_api_restart "$_deployment" "$_cluster" ;;
  sh) apps_kyso_api_sh "$_deployment" "$_cluster" ;;
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
  _cmnds="env-edit env-path env-show env-update helm-history helm-rollback"
  _cmnds="$_cmnds install logs reinstall remove restart sh status summary uris"
  echo "$_cmnds"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
