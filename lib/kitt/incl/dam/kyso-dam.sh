#!/bin/sh
# ----
# File:        dam/kyso-dam.sh
# Description: Functions to manage kyso-dam deployments for kyso on k8s
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2023 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_DAM_KYSO_DAM_SH="1"

# ---------
# Variables
# ---------

# CMND_DSC="kyso-dam: manage kyso-dam deployment for kyso"

# Defaults
export DEPLOYMENT_DEFAULT_KYSO_DAM_ENDPOINT=""
_kyso_dam_image="registry.kyso.io/kyso-io/kyso-dam/main:latest"
export DEPLOYMENT_DEFAULT_KYSO_DAM_IMAGE="$_kyso_dam_image"
export DEPLOYMENT_DEFAULT_KYSO_DAM_REPLICAS="1"
# Port forward settings
export DEPLOYMENT_DEFAULT_KYSO_DAM_PF_PORT=""
_default_skopeo_image="registry.kyso.io/docker/skopeo:latest"
export DEPLOYMENT_DEFAULT_KYSO_DAM_SKOPEO_IMAGE="$_default_skopeo_image"
_default_kyso_cli_image="registry.kyso.io/kyso-io/kyso-cli:latest"
export DEPLOYMENT_DEFAULT_KYSO_DAM_KYSO_CLI_IMAGE="$_default_kyso_cli_image"
_default_dam_builder_image="registry.kyso.io/docker/kyso-dam-builder:latest"
DEPLOYMENT_DEFAULT_KYSO_DAM_BUILDER_IMAGE="$_default_dam_builder_image"
export DEPLOYMENT_DEFAULT_KYSO_DAM_BUILDER_IMAGE

# Fixed values
export KYSO_DAM_SERVER_PORT="8880"

# --------
# Includes
# --------

if [ -d "$INCL_DIR" ]; then
  # shellcheck source=../common.sh
  [ "$INCL_COMMON_SH" = "1" ] || . "$INCL_DIR/common.sh"
  # shellcheck source=./common.sh
  [ "$INCL_DAM_COMMON_SH" = "1" ] || . "$INCL_DIR/dam/common.sh"
  # shellcheck source=./zot.sh
  [ "$INCL_DAM_ZOT_SH" = "1" ] || . "$INCL_DIR/dam/zot.sh"
fi

# ---------
# Functions
# ---------

dam_kyso_dam_export_variables() {
  [ -z "$__dam_kyso_dam_export_variables" ] || return 0
  _deployment="$1"
  _cluster="$2"
  apps_kyso_api_export_variables "$_deployment" "$_cluster"
  dam_common_export_variables "$_deployment" "$_cluster"
  dam_zot_export_variables "$_deployment" "$_cluster"
  # Derived defaults
  _kyso_dam_api_url="http://kyso-api.$KYSO_API_NAMESPACE.svc.cluster.local/api"
  export DEPLOYMENT_DEFAULT_KYSO_DAM_KYSO_API_URL="$_kyso_dam_api_url"
  # Values
  export KYSO_DAM_NAMESPACE="kyso-dam-$DEPLOYMENT_NAME"
  # Directories
  export KYSO_DAM_CHART_DIR="$CHARTS_DIR/kyso-dam"
  export KYSO_DAM_TMPL_DIR="$TMPL_DIR/dam/kyso-dam"
  export KYSO_DAM_HELM_DIR="$DEPLOY_HELM_DIR/kyso-dam"
  export KYSO_DAM_KUBECTL_DIR="$DEPLOY_KUBECTL_DIR/kyso-dam"
  export KYSO_DAM_SECRETS_DIR="$DEPLOY_SECRETS_DIR/kyso-dam"
  export KYSO_DAM_PF_DIR="$DEPLOY_PF_DIR/kyso-dam"
  # Templates
  export KYSO_DAM_HELM_VALUES_TMPL="$KYSO_DAM_TMPL_DIR/values.yaml"
  export KYSO_DAM_SVC_MAP_TMPL="$KYSO_DAM_TMPL_DIR/svc_map.yaml"
  # Files
  _helm_values_yaml="$KYSO_DAM_HELM_DIR/values${SOPS_EXT}.yaml"
  _helm_values_yaml_plain="$KYSO_DAM_HELM_DIR/values.yaml"
  export KYSO_DAM_HELM_VALUES_YAML="${_helm_values_yaml}"
  export KYSO_DAM_HELM_VALUES_YAML_PLAIN="${_helm_values_yaml_plain}"
  export KYSO_DAM_SVC_MAP_YAML="$KYSO_DAM_KUBECTL_DIR/svc_map.yaml"
  export KYSO_DAM_PF_OUT="$KYSO_DAM_PF_DIR/kubectl-dam.out"
  export KYSO_DAM_PF_PID="$KYSO_DAM_PF_DIR/kubectl-dam.pid"
  # By default don't auto save the environment
  KYSO_DAM_AUTO_SAVE_ENV="false"
  # Use defaults for variables missing from config files / enviroment
  if [ -z "$KYSO_DAM_ENDPOINT" ]; then
    if [ "$DEPLOYMENT_KYSO_DAM_ENDPOINT" ]; then
      KYSO_DAM_ENDPOINT="$DEPLOYMENT_KYSO_DAM_ENDPOINT"
    else
      KYSO_DAM_ENDPOINT="$DEPLOYMENT_DEFAULT_KYSO_DAM_ENDPOINT"
    fi
  else
    KYSO_DAM_AUTO_SAVE_ENV="true"
  fi
  if [ -z "$KYSO_DAM_IMAGE" ]; then
    if [ "$DEPLOYMENT_KYSO_DAM_IMAGE" ]; then
      KYSO_DAM_IMAGE="$DEPLOYMENT_KYSO_DAM_IMAGE"
    else
      KYSO_DAM_IMAGE="$DEPLOYMENT_DEFAULT_KYSO_DAM_IMAGE"
    fi
  else
    KYSO_DAM_AUTO_SAVE_ENV="true"
  fi
  export KYSO_DAM_IMAGE
  if [ -z "$KYSO_DAM_KYSO_API_URL" ]; then
    if [ "$DEPLOYMENT_KYSO_DAM_KYSO_API_URL" ]; then
      KYSO_DAM_KYSO_API_URL="$DEPLOYMENT_KYSO_DAM_KYSO_API_URL"
    else
      KYSO_DAM_KYSO_API_URL="$DEPLOYMENT_DEFAULT_KYSO_DAM_KYSO_API_URL"
    fi
  else
    KYSO_DAM_AUTO_SAVE_ENV="true"
  fi
  export KYSO_DAM_KYSO_API_URL
  if [ "$DEPLOYMENT_KYSO_DAM_PF_PORT" ]; then
    KYSO_DAM_PF_PORT="$DEPLOYMENT_KYSO_DAM_PF_PORT"
  else
    KYSO_DAM_PF_PORT="$DEPLOYMENT_DEFAULT_KYSO_DAM_PF_PORT"
  fi
  export KYSO_DAM_PF_PORT
  if [ "$DEPLOYMENT_KYSO_DAM_REPLICAS" ]; then
    KYSO_DAM_REPLICAS="$DEPLOYMENT_KYSO_DAM_REPLICAS"
  else
    KYSO_DAM_REPLICAS="$DEPLOYMENT_DEFAULT_KYSO_DAM_REPLICAS"
  fi
  export KYSO_DAM_REPLICAS
  if [ "$DEPLOYMENT_KYSO_DAM_SKOPEO_IMAGE" ]; then
    KYSO_DAM_SKOPEO_IMAGE="$DEPLOYMENT_KYSO_DAM_SKOPEO_IMAGE"
  else
    KYSO_DAM_SKOPEO_IMAGE="$DEPLOYMENT_DEFAULT_KYSO_DAM_SKOPEO_IMAGE"
  fi
  export KYSO_DAM_SKOPEO_IMAGE
  if [ "$DEPLOYMENT_KYSO_DAM_KYSO_CLI_IMAGE" ]; then
    KYSO_DAM_KYSO_CLI_IMAGE="$DEPLOYMENT_KYSO_DAM_KYSO_CLI_IMAGE"
  else
    KYSO_DAM_KYSO_CLI_IMAGE="$DEPLOYMENT_DEFAULT_KYSO_DAM_KYSO_CLI_IMAGE"
  fi
  _kyso_cli_tag="${KYSO_DAM_KYSO_CLI_IMAGE##*:}"
  KYSO_DAM_KYSO_CLI_IMAGE_IN_ZOT="$ZOT_HOSTNAME/kyso-cli:$_kyso_cli_tag"
  export KYSO_DAM_KYSO_CLI_IMAGE
  export KYSO_DAM_KYSO_CLI_IMAGE_IN_ZOT
  if [ "$DEPLOYMENT_KYSO_DAM_BUILDER_IMAGE" ]; then
    KYSO_DAM_BUILDER_IMAGE="$DEPLOYMENT_KYSO_DAM_BUILDER_IMAGE"
  else
    KYSO_DAM_BUILDER_IMAGE="$DEPLOYMENT_DEFAULT_KYSO_DAM_BUILDER_IMAGE"
  fi
  _builder_tag="${KYSO_DAM_BUILDER_IMAGE##*:}"
  KYSO_DAM_BUILDER_IMAGE_IN_ZOT="$ZOT_HOSTNAME/kyso-dam-builder:$_builder_tag"
  export KYSO_DAM_BUILDER_IMAGE
  export KYSO_DAM_BUILDER_IMAGE_IN_ZOT
  # Export auto save environment flag
  export KYSO_DAM_AUTO_SAVE_ENV
  __dam_kyso_dam_export_variables="1"
}

dam_kyso_dam_check_directories() {
  dam_common_check_directories
  for _d in "$KYSO_DAM_HELM_DIR" "$KYSO_DAM_KUBECTL_DIR" \
    "$KYSO_DAM_SECRETS_DIR" "$KYSO_DAM_PF_DIR"; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

dam_kyso_dam_clean_directories() {
  # Try to remove empty dirs, except if they contain secrets
  for _d in "$KYSO_DAM_HELM_DIR" "$KYSO_DAM_KUBECTL_DIR" \
    "$KYSO_DAM_SECRETS_DIR" "$KYSO_DAM_PF_DIR"; do
    if [ -d "$_d" ]; then
      rmdir "$_d" 2>/dev/null || true
    fi
  done
}

dam_kyso_dam_read_variables() {
  _app="kyso-dam"
  header "Reading $_app settings"
  _ex_ep="$LINUX_HOST_IP:$KYSO_DAM_SERVER_PORT"
  read_value "kyso-dam endpoint (i.e. '$_ex_ep' or '-' to deploy image)" \
    "${KYSO_DAM_ENDPOINT}"
  KYSO_DAM_ENDPOINT=${READ_VALUE}
  _ex_img="registry.kyso.io/kyso-io/kyso-dam/develop:latest"
  read_value \
    "Kyso DAM Image URI (i.e. '$_ex_img' or export KYSO_DAM_IMAGE env var)" \
    "${KYSO_DAM_IMAGE}"
  KYSO_DAM_IMAGE=${READ_VALUE}
  read_value "Kyso DAM Replicas" "${KYSO_DAM_REPLICAS}"
  KYSO_DAM_REPLICAS=${READ_VALUE}
  _kyso_api_url="$DEPLOYMENT_DEFAULT_KYSO_DAM_KYSO_API_URL"
  read_value "kyso-api url ('$_kyso_api_url' when using same deployment)" \
    "${KYSO_DAM_KYSO_API_URL}"
  KYSO_DAM_KYSO_API_URL=${READ_VALUE}
  read_value "Fixed port for kyso-dam pf? (i.e. 8880 or '-' for random)" \
    "${KYSO_DAM_PF_PORT}"
  KYSO_DAM_PF_PORT=${READ_VALUE}
  read_value "skopeo image" "${KYSO_DAM_SKOPEO_IMAGE}"
  KYSO_DAM_SKOPEO_IMAGE=${READ_VALUE}
  read_value "kyso-cli image" "${KYSO_DAM_KYSO_CLI_IMAGE}"
  KYSO_DAM_KYSO_CLI_IMAGE=${READ_VALUE}
  read_value "kyso-dam-builder image" "${KYSO_DAM_BUILDER_IMAGE}"
  KYSO_DAM_BUILDER_IMAGE=${READ_VALUE}
}

dam_kyso_dam_print_variables() {
  _app="kyso-dam"
  cat <<EOF
# Deployment $_app settings
# ---
# Endpoint for Kyso DAM (replaces the real deployment on development systems),
# set to:
# - '$LINUX_HOST_IP:$KYSO_DAM_SERVER_PORT' on Linux
# - '$MACOS_HOST_IP:$KYSO_DAM_SERVER_PORT' on systems using Docker Desktop
KYSO_DAM_ENDPOINT=$KYSO_DAM_ENDPOINT
# Kyso Front Image URI, examples for local testing:
# - 'registry.kyso.io/kyso-io/kyso-dam/develop:latest'
# - 'k3d-registry.lo.kyso.io:5000/kyso-dam:latest'
# If empty the KYSO_DAM_IMAGE environment variable has to be set each time
# the kyso-dam service is installed
KYSO_DAM_IMAGE=$KYSO_DAM_IMAGE
# Number of pods to run in parallel
KYSO_DAM_REPLICAS=$KYSO_DAM_REPLICAS
# kyso-api server URL (used for auth)
KYSO_DAM_KYSO_API_URL=$KYSO_DAM_KYSO_API_URL
# Fixed port for kyso-dam pf (recommended is 8880, random if empty)
KYSO_DAM_PF_PORT=$KYSO_DAM_PF_PORT
# skopeo image
KYSO_DAM_SKOPEO_IMAGE=$KYSO_DAM_SKOPEO_IMAGE
# kyso-cli image
KYSO_DAM_KYSO_CLI_IMAGE=$KYSO_DAM_KYSO_CLI_IMAGE
# kyso-dam-builder image
KYSO_DAM_BUILDER_IMAGE=$KYSO_DAM_BUILDER_IMAGE
# ---
EOF
}

dam_kyso_dam_logs() {
  _deployment="$1"
  _cluster="$2"
  dam_kyso_dam_export_variables "$_deployment" "$_cluster"
  _ns="$KYSO_DAM_NAMESPACE"
  _app="kyso-dam"
  if kubectl get -n "$_ns" "deployments/$_app" >/dev/null 2>&1; then
    kubectl -n "$_ns" logs "deployments/$_app" -f
  else
    echo "Deployment '$_app' not found on namespace '$_ns'"
  fi
}

dam_kyso_dam_sh() {
  _deployment="$1"
  _cluster="$2"
  dam_kyso_dam_export_variables "$_deployment" "$_cluster"
  _ns="$KYSO_DAM_NAMESPACE"
  _app="kyso-dam"
  if kubectl get -n "$_ns" "deployments/$_app" >/dev/null 2>&1; then
    kubectl -n "$_ns" exec -ti "deployments/$_app" -- /bin/sh
  else
    echo "Deployment '$_app' not found on namespace '$_ns'"
  fi
}

dam_kyso_dam_copy_images() {
  _deployment="$1"
  _cluster="$2"
  dam_kyso_dam_export_variables "$_deployment" "$_cluster"
  _ns="$KYSO_DAM_NAMESPACE"
  _pull_secret_name="$CLUSTER_PULL_SECRETS_NAME"
  _skopeo_tmpl="$KYSO_DAM_TMPL_DIR/skopeo.yaml"
  _skopeo_yaml="$KYSO_DAM_KUBECTL_DIR/skopeo.yaml"
  if ! find_namespace "$_ns"; then
    echo "Can't copy images, install 'kyso.dam' first"
    exit 1
  fi
  echo "Starting skopeo Pod"
  sed \
    -e "s%__NAMESPACE__%$_ns%" \
    -e "s%__SKOPEO_IMAGE__%$KYSO_DAM_SKOPEO_IMAGE%" \
    -e "s%__PULL_SECRET__%$_pull_secret_name%" \
    "$_skopeo_tmpl" >"$_skopeo_yaml"
  kubectl_apply "$_skopeo_yaml"
  echo "Waiting for Pod to be ready"
  ret="0"
  kubectl wait -n "$_ns" --for="condition=Ready" pod/skopeo --timeout=150s ||
    ret="$?"
  if [ "$ret" -eq "0" ]; then
    echo "Copying builder image"
    kubectl exec -n "$_ns" skopeo -ti -- skopeo copy \
      "docker://$KYSO_DAM_BUILDER_IMAGE" \
      "docker://$KYSO_DAM_BUILDER_IMAGE_IN_ZOT" || ret="$?"
    echo "Copying kyso-cli image"
    kubectl exec -n "$_ns" skopeo -ti -- skopeo copy \
      "docker://$KYSO_DAM_KYSO_CLI_IMAGE" \
      "docker://$KYSO_DAM_KYSO_CLI_IMAGE_IN_ZOT" || ret="$?"
  fi
  echo "Deleting skopeo Pod"
  kubectl_delete "$_skopeo_yaml"
  return "$ret"
}

dam_kyso_dam_install() {
  _deployment="$1"
  _cluster="$2"
  dam_kyso_dam_export_variables "$_deployment" "$_cluster"
  if [ -z "$KYSO_DAM_ENDPOINT" ] && [ -z "$KYSO_DAM_IMAGE" ]; then
    echo "The DAM_IMAGE & DAM_ENDPOINT variables are empty."
    echo "Export KYSO_DAM_IMAGE or KYSO_DAM_ENDPOINT or reconfigure."
    exit 1
  fi
  # Initial test
  if ! find_namespace "$ZOT_NAMESPACE"; then
    read_bool "zot namespace not found, abort install?" "Yes"
    if is_selected "${READ_VALUE}"; then
      return 1
    fi
  fi
  # Auto save the configuration if requested
  if is_selected "$KYSO_DAM_AUTO_SAVE_ENV"; then
    dam_kyso_dam_env_save "$_deployment" "$_cluster"
  fi
  # Load additional variables & check directories
  dam_common_export_service_hostnames "$_deployment" "$_cluster"
  dam_kyso_dam_check_directories
  # Adjust variables
  _app="kyso-dam"
  _ns="$KYSO_DAM_NAMESPACE"
  # directory
  _chart="$KYSO_DAM_CHART_DIR"
  # files
  _helm_values_tmpl="$KYSO_DAM_HELM_VALUES_TMPL"
  _helm_values_yaml="$KYSO_DAM_HELM_VALUES_YAML"
  _helm_values_yaml_plain="$KYSO_DAM_HELM_VALUES_YAML_PLAIN"
  _svc_map_tmpl="$KYSO_DAM_SVC_MAP_TMPL"
  _svc_map_yaml="$KYSO_DAM_SVC_MAP_YAML"
  _cert_yamls=""
  for _hostname in $DEPLOYMENT_HOSTNAMES; do
    _cert_yaml="$KYSO_DAM_KUBECTL_DIR/tls-$_hostname${SOPS_EXT}.yaml"
    _cert_yamls="$_cert_yamls $_cert_yaml"
  done
  # build and exec namespaces
  _ns_build="$_ns-build"
  _ns_exec="$_ns-exec"
  # Pull secrets for app, build and exec namespaces
  _pull_name="$CLUSTER_PULL_SECRETS_NAME"
  _pull_yaml="$CLUST_NS_KUBECTL_DIR/$_ns-$_pull_name$SOPS_EXT.yaml"
  _pull_build_yaml="$CLUST_NS_KUBECTL_DIR/$_ns_build-$_pull_name$SOPS_EXT.yaml"
  _pull_exec_yaml="$CLUST_NS_KUBECTL_DIR/$_ns_exec-$_pull_name$SOPS_EXT.yaml"
  if ! find_namespace "$_ns"; then
    # Remove old files, just in case ...
    # shellcheck disable=SC2086
    rm -f "$_helm_values_yaml" "$_pull_yaml" "$_pull_build_yaml" \
      "$_pull_exec_yaml" "$_svc_map_yaml" $_cert_yamls
    # Create namespace
    create_namespace "$_ns"
  fi
  # Image settings
  _image_repo="${KYSO_DAM_IMAGE%:*}"
  _image_tag="${KYSO_DAM_IMAGE#*:}"
  if [ "$_image_repo" = "$_image_tag" ]; then
    _image_tag="latest"
  fi
  # Endpoint settings
  if [ "$KYSO_DAM_ENDPOINT" ]; then
    # Generate / update endpoint values
    _ep_enabled="true"
  else
    # Adjust the dam port
    _ep_enabled="false"
  fi
  _ep_addr="${KYSO_DAM_ENDPOINT%:*}"
  _ep_port="${KYSO_DAM_ENDPOINT#*:}"
  [ "$_ep_port" != "$_ep_addr" ] || _ep_port="$KYSO_DAM_SERVER_PORT"
  # Service settings
  _server_port="$KYSO_DAM_SERVER_PORT"
  sed \
    -e "s%__DAM_REPLICAS__%$KYSO_DAM_REPLICAS%" \
    -e "s%__DAM_IMAGE_REPO__%$_image_repo%" \
    -e "s%__DAM_IMAGE_TAG__%$_image_tag%" \
    -e "s%__IMAGE_PULL_POLICY__%$DEPLOYMENT_IMAGE_PULL_POLICY%" \
    -e "s%__PULL_SECRETS_NAME__%$CLUSTER_PULL_SECRETS_NAME%" \
    -e "s%__DAM_ENDPOINT_ENABLED__%$_ep_enabled%" \
    -e "s%__DAM_ENDPOINT_ADDR__%$_ep_addr%" \
    -e "s%__DAM_ENDPOINT_PORT__%$_ep_port%" \
    -e "s%__DAM_SERVER_PORT__%$_server_port%" \
    -e "s%__CLUSTER_DOMAIN__%$CLUSTER_DOMAIN%" \
    -e "s%__KYSO_API_URL__%$KYSO_DAM_KYSO_API_URL%" \
    -e "s%__APP_DOMAIN__%$DEPLOYMENT_APP_DOMAIN%" \
    -e "s%__ZOT_HOSTNAME__%$ZOT_HOSTNAME%" \
    -e "s%__ZOT_ADMIN_SECRET__%$_pull_name%" \
    -e "s%__ZOT_READER_SECRET__%$_pull_name%" \
    -e "s%__BUILDER_IMAGE__%$KYSO_DAM_BUILDER_IMAGE_IN_ZOT%" \
    -e "s%__KYSO_CLI_IMAGE__%$KYSO_DAM_KYSO_CLI_IMAGE_IN_ZOT%" \
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
    -e "s%__KYSO_API_SVC_HOSTNAME__%$KYSO_API_SVC_HOSTNAME%" \
    "$_svc_map_tmpl" >"$_svc_map_yaml"
  # Create certificate secrets if needed or remove them if not
  if is_selected "$DEPLOYMENT_INGRESS_TLS_CERTS"; then
    create_app_cert_yamls "$_ns" "$KYSO_DAM_KUBECTL_DIR"
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
  if [ "$KYSO_DAM_ENDPOINT" ]; then
    if [ "$(kubectl get -n "$_ns" "deployments" -o name)" ]; then
      kubectl annotate -n "$_ns" --overwrite "endpoints/$_app" \
        "meta.helm.sh/release-name=$_app" \
        "meta.helm.sh/release-namespace=$_ns"
    fi
  fi
  # Install helm chart
  helm_upgrade "$_ns" "$_helm_values_yaml" "$_app" "$_chart"
  # Wait until deployment succeds or fails (if there is one, of course)
  if [ -z "$KYSO_DAM_ENDPOINT" ]; then
    kubectl rollout status deployment --timeout="$ROLLOUT_STATUS_TIMEOUT" \
      -n "$_ns" "$_app"
  fi
  # Add dockerconfigjson to app namespace (will be used to copy images)
  if find_namespace "$_ns"; then
    dam_zot_add_user_to_dockerconfig "$_deployment" "$_cluster" \
      "admin" "$_ns" "$_pull_yaml"
  fi
  # Add dockerconfigjson to app namespace
  if find_namespace "$_ns_build"; then
    dam_zot_add_user_to_dockerconfig "$_deployment" "$_cluster" \
      "admin" "$_ns_build" "$_pull_build_yaml"
  fi
  # Add dockerconfigjson to app namespace
  if find_namespace "$_ns_exec"; then
    dam_zot_add_user_to_dockerconfig "$_deployment" "$_cluster" \
      "reader" "$_ns_exec" "$_pull_exec_yaml"
  fi
  # Copy images
  dam_kyso_dam_copy_images "$_deployment" "$_cluster"
}

dam_kyso_dam_helm_history() {
  _deployment="$1"
  _cluster="$2"
  dam_kyso_dam_export_variables "$_deployment" "$_cluster"
  _app="kyso-dam"
  _ns="$KYSO_DAM_NAMESPACE"
  if find_namespace "$_ns"; then
    helm_history "$_ns" "$_app"
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

dam_kyso_dam_helm_rollback() {
  _deployment="$1"
  _cluster="$2"
  dam_kyso_dam_export_variables "$_deployment" "$_cluster"
  _app="kyso-dam"
  _ns="$KYSO_DAM_NAMESPACE"
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
    # If we succeed update the dam settings
    dam_kyso_update_dam_settings "$_deployment" "$_cluster"
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

dam_kyso_dam_reinstall() {
  _deployment="$1"
  _cluster="$2"
  dam_kyso_dam_export_variables "$_deployment" "$_cluster"
  _app="kyso-dam"
  _ns="$KYSO_DAM_NAMESPACE"
  if find_namespace "$_ns"; then
    _cimages="$(deployment_container_images "$_ns" "$_app")"
    _cname="kyso-dam"
    KYSO_DAM_IMAGE="$(echo "$_cimages" | sed -ne "s/^$_cname //p")"
    if [ "$KYSO_DAM_IMAGE" ]; then
      export KYSO_DAM_IMAGE
      dam_kyso_dam_install "$_deployment" "$_cluster"
    else
      echo "Image for '$_app' on '$_ns' not found!"
    fi
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

dam_kyso_dam_remove() {
  _deployment="$1"
  _cluster="$2"
  dam_kyso_dam_export_variables "$_deployment" "$_cluster"
  _app="kyso-dam"
  _ns="$KYSO_DAM_NAMESPACE"
  # files
  _helm_values_yaml="$KYSO_DAM_HELM_VALUES_YAML"
  # build and exec namespaces
  _ns_build="$_ns-build"
  _ns_exec="$ns-exec"
  # Pull secrets for app, build and exec namespaces
  _pull_name="$CLUSTER_PULL_SECRETS_NAME"
  _pull_yaml="$CLUST_NS_KUBECTL_DIR/$_ns-$_name$SOPS_EXT.yaml"
  _pull_build_yaml="$CLUST_NS_KUBECTL_DIR/$_ns_build-$_pull_name$SOPS_EXT.yaml"
  _pull_exec_yaml="$CLUST_NS_KUBECTL_DIR/$_ns_exec-$_pull_name$SOPS_EXT.yaml"
  _svc_map_yaml="$KYSO_DAM_SVC_MAP_YAML"
  _cert_yamls=""
  for _hostname in $DEPLOYMENT_HOSTNAMES; do
    _cert_yaml="$KYSO_DAM_KUBECTL_DIR/tls-$_hostname${SOPS_EXT}.yaml"
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
    for _yaml in "$_pull_yaml" "$_pull_build_yaml" "$_pull_exec_yaml" \
      "$_svc_map_yaml" $_cert_yamls; do
      kubectl_delete "$_yaml" || true
    done
    # Delete namespace
    delete_namespace "$_ns"
    footer
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
  dam_kyso_dam_clean_directories
}

dam_kyso_dam_restart() {
  _deployment="$1"
  _cluster="$2"
  dam_kyso_dam_export_variables "$_deployment" "$_cluster"
  _app="kyso-dam"
  _ns="$KYSO_DAM_NAMESPACE"
  if find_namespace "$_ns"; then
    deployment_restart "$_ns" "$_app"
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

dam_kyso_dam_status() {
  _deployment="$1"
  _cluster="$2"
  dam_kyso_dam_export_variables "$_deployment" "$_cluster"
  _app="kyso-dam"
  _ns="$KYSO_DAM_NAMESPACE"
  if find_namespace "$_ns"; then
    kubectl get all,endpoints,ingress,secrets -n "$_ns"
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

dam_kyso_dam_summary() {
  _deployment="$1"
  _cluster="$2"
  dam_kyso_dam_export_variables "$_deployment" "$_cluster"
  _ns="$KYSO_DAM_NAMESPACE"
  _app="kyso-dam"
  _ep="$KYSO_DAM_ENDPOINT"
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

dam_kyso_dam_uris() {
  _deployment="$1"
  _cluster="$2"
  dam_kyso_dam_export_variables "$_deployment" "$_cluster"
  echo "https://APP_NAME.$APP_DOMAIN/"
}

dam_kyso_dam_env_edit() {
  if [ "$EDITOR" ]; then
    _app="kyso-dam"
    _deployment="$1"
    _cluster="$2"
    dam_export_variables "$_deployment" "$_cluster"
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

dam_kyso_dam_env_path() {
  _app="kyso-dam"
  _deployment="$1"
  _cluster="$2"
  dam_export_variables "$_deployment" "$_cluster"
  _env_file="$DEPLOY_ENVS_DIR/$_app.env"
  echo "$_env_file"
}

dam_kyso_dam_env_save() {
  _app="kyso-dam"
  _deployment="$1"
  _cluster="$2"
  dam_export_variables "$_deployment" "$_cluster"
  _env_file="$DEPLOY_ENVS_DIR/$_app.env"
  dam_kyso_dam_check_directories
  dam_kyso_dam_print_variables "$_deployment" "$_cluster" |
    stdout_to_file "$_env_file"
}

dam_kyso_dam_env_update() {
  _app="kyso-dam"
  _deployment="$1"
  _cluster="$2"
  dam_export_variables "$_deployment" "$_cluster"
  _env_file="$DEPLOY_ENVS_DIR/$_app.env"
  header "$_app configuration variables"
  dam_kyso_dam_print_variables "$_deployment" "$_cluster" |
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
    dam_kyso_dam_read_variables
    if [ -f "$_env_file" ]; then
      footer
      read_bool "Save updated $_app env vars?" "Yes"
    else
      READ_VALUE="Yes"
    fi
    if is_selected "${READ_VALUE}"; then
      dam_kyso_dam_env_save "$_deployment" "$_cluster"
      footer
      echo "$_app configuration saved to '$_env_file'"
      footer
    fi
  fi
}

dam_kyso_dam_command() {
  _command="$1"
  _deployment="$2"
  _cluster="$3"
  case "$_command" in
  copy-images | copy_images)
    dam_kyso_dam_copy_images "$_deployment" "$_cluster"
    ;;
  env-edit | env_edit)
    dam_kyso_dam_env_edit "$_deployment" "$_cluster"
    ;;
  env-path | env_path)
    dam_kyso_dam_env_path "$_deployment" "$_cluster"
    ;;
  env-show | env_show)
    dam_kyso_dam_print_variables "$_deployment" "$_cluster" | grep -v '^#'
    ;;
  env-update | env_update)
    dam_kyso_dam_env_update "$_deployment" "$_cluster"
    ;;
  helm-history) dam_kyso_dam_helm_history "$_deployment" "$_cluster" ;;
  helm-rollback) dam_kyso_dam_helm_rollback "$_deployment" "$_cluster" ;;
  install) dam_kyso_dam_install "$_deployment" "$_cluster" ;;
  logs) dam_kyso_dam_logs "$_deployment" "$_cluster" ;;
  reinstall) dam_kyso_dam_reinstall "$_deployment" "$_cluster" ;;
  remove) dam_kyso_dam_remove "$_deployment" "$_cluster" ;;
  restart) dam_kyso_dam_restart "$_deployment" "$_cluster" ;;
  sh) dam_kyso_dam_sh "$_deployment" "$_cluster" ;;
  status) dam_kyso_dam_status "$_deployment" "$_cluster" ;;
  summary) dam_kyso_dam_summary "$_deployment" "$_cluster" ;;
  uris) dam_kyso_dam_uris "$_deployment" "$_cluster" ;;
  *)
    echo "Unknown kyso-dam subcommand '$1'"
    exit 1
    ;;
  esac
}

dam_kyso_dam_command_list() {
  _cmnds="copy-images env-edit env-path env-show env-update"
  _cmnds="$_cmnds helm-history helm-rollback install logs reinstall remove"
  _cmnds="$_cmnds restart sh status summary uris"
  echo "$_cmnds"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
