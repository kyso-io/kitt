#!/bin/sh
# ----
# File:        dam/zot.sh
# Description: Functions to manage zot deployments for kyso on k8s
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2023 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_DAM_ZOT_SH="1"

# ---------
# Variables
# ---------

# Defaults
#_zot_repo="registry.kyso.io/docker/zot"
_zot_repo="ghcr.io/project-zot/zot-linux-amd64"
_zot_tag="v2.0.0-rc3"
export DEPLOYMENT_DEFAULT_ZOT_IMAGE="$_zot_repo:$_zot_tag"
export DEPLOYMENT_DEFAULT_ZOT_HOSTNAME="zot"
export DEPLOYMENT_DEFAULT_ZOT_REPLICAS="1"
export DEPLOYMENT_DEFAULT_ZOT_ADMIN_USER="admin"
export DEPLOYMENT_DEFAULT_ZOT_READER_USER="reader"

# CMND_DSC="zot: manage zot deployment for kyso"

# --------
# Includes
# --------

if [ -d "$INCL_DIR" ]; then
  # shellcheck source=../common.sh
  [ "$INCL_COMMON_SH" = "1" ] || . "$INCL_DIR/common.sh"
  # shellcheck source=./common.sh
  [ "$INCL_DAM_COMMON_SH" = "1" ] || . "$INCL_DIR/dam/common.sh"
fi

# ---------
# Functions
# ---------

dam_zot_export_variables() {
  [ -z "$__dam_zot_export_variables" ] || return 0
  _deployment="$1"
  _cluster="$2"
  dam_common_export_variables "$_deployment" "$_cluster"
  # Values
  export ZOT_NAMESPACE="zot-$DEPLOYMENT_NAME"
  # Directories
  export ZOT_CHART_DIR="$CHARTS_DIR/zot"
  export ZOT_TMPL_DIR="$TMPL_DIR/dam/zot"
  export ZOT_HELM_DIR="$DEPLOY_HELM_DIR/zot"
  export ZOT_KUBECTL_DIR="$DEPLOY_KUBECTL_DIR/zot"
  export ZOT_SECRETS_DIR="$DEPLOY_SECRETS_DIR/zot"
  # Templates
  export ZOT_HELM_VALUES_TMPL="$ZOT_TMPL_DIR/values.yaml"
  # Files
  export ZOT_AUTH_FILE="$ZOT_SECRETS_DIR/basic_auth${SOPS_EXT}.txt"
  export ZOT_AUTH_YAML="$ZOT_KUBECTL_DIR/basic_auth${SOPS_EXT}.yaml"
  export ZOT_ADMIN_DOCKERCONFIG_NAME="zot-admin-${CLUSTER_PULL_SECRETS_NAME}"
  export ZOT_READER_DOCKERCONFIG_NAME="zot-reader-${CLUSTER_PULL_SECRETS_NAME}"
  _helm_values_yaml="$ZOT_HELM_DIR/values${SOPS_EXT}.yaml"
  _helm_values_yaml_plain="$ZOT_HELM_DIR/values.yaml"
  export ZOT_HELM_VALUES_YAML="${_helm_values_yaml}"
  export ZOT_HELM_VALUES_YAML_PLAIN="${_helm_values_yaml_plain}"
  # By default don't auto save the environment
  ZOT_AUTO_SAVE_ENV="false"
  if [ -z "$ZOT_HOSTNAME" ]; then
    if [ "$DEPLOYMENT_ZOT_HOSTNAME" ]; then
      ZOT_HOSTNAME="$DEPLOYMENT_ZOT_HOSTNAME"
    else
      ZOT_HOSTNAME="$DEPLOYMENT_DEFAULT_ZOT_HOSTNAME.$CLUSTER_DOMAIN"
    fi
  else
    ZOT_AUTO_SAVE_ENV="true"
  fi
  export ZOT_HOSTNAME
  if [ -z "$ZOT_IMAGE" ]; then
    if [ "$DEPLOYMENT_ZOT_IMAGE" ]; then
      ZOT_IMAGE="$DEPLOYMENT_ZOT_IMAGE"
    else
      ZOT_IMAGE="$DEPLOYMENT_DEFAULT_ZOT_IMAGE"
    fi
  else
    ZOT_AUTO_SAVE_ENV="true"
  fi
  export ZOT_IMAGE
  if [ "$DEPLOYMENT_ZOT_REPLICAS" ]; then
    ZOT_REPLICAS="$DEPLOYMENT_ZOT_REPLICAS"
  else
    ZOT_REPLICAS="$DEPLOYMENT_DEFAULT_ZOT_REPLICAS"
  fi
  export ZOT_REPLICAS
  # Users
  if [ "$DEPLOYMENT_ZOT_ADMIN_USER" ]; then
    ZOT_ADMIN_USER="$DEPLOYMENT_ZOT_ADMIN_USER"
  else
    ZOT_ADMIN_USER="$DEPLOYMENT_DEFAULT_ZOT_ADMIN_USER"
  fi
  export ZOT_ADMIN_USER
  if [ "$DEPLOYMENT_ZOT_READER_USER" ]; then
    ZOT_READER_USER="$DEPLOYMENT_ZOT_READER_USER"
  else
    ZOT_READER_USER="$DEPLOYMENT_DEFAULT_ZOT_READER_USER"
  fi
  export ZOT_READER_USER
  # Export auto save environment flag
  export ZOT_AUTO_SAVE_ENV
  __dam_zot_export_variables="1"
}

dam_zot_check_directories() {
  dam_common_check_directories
  for _d in "$ZOT_HELM_DIR" "$ZOT_KUBECTL_DIR" "$ZOT_SECRETS_DIR"; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

dam_zot_clean_directories() {
  # Try to remove empty dirs, except if they contain secrets
  for _d in "$ZOT_HELM_DIR" "$ZOT_KUBECTL_DIR" "$ZOT_SECRETS_DIR"; do
    if [ -d "$_d" ]; then
      rmdir "$_d" 2>/dev/null || true
    fi
  done
}

dam_zot_read_variables() {
  _app="zot"
  header "Reading $_app settings"
  read_value "ZOT Hostname" "${ZOT_HOSTNAME}"
  ZOT_HOSTNAME=${READ_VALUE}
  read_value "ZOT Image URI (i.e. '$_ex_img' or export ZOT_IMAGE env var)" \
    "${ZOT_IMAGE}"
  ZOT_IMAGE=${READ_VALUE}
  read_value "Zot Replicas" "${ZOT_REPLICAS}"
  ZOT_REPLICAS=${READ_VALUE}
}

dam_zot_print_variables() {
  _app="zot"
  cat <<EOF
# Deployment $_app settings
# ---
# Public zot hostname
ZOT_HOSTNAME=$ZOT_HOSTNAME
# Image to use
ZOT_IMAGE=$ZOT_IMAGE
# Number of pods to run in parallel
ZOT_REPLICAS=$ZOT_REPLICAS
# ---
EOF
}

dam_zot_logs() {
  _deployment="$1"
  _cluster="$2"
  dam_zot_export_variables "$_deployment" "$_cluster"
  _ns="$ZOT_NAMESPACE"
  _app="zot"
  if kubectl get -n "$_ns" "deployments/$_app" >/dev/null 2>&1; then
    kubectl -n "$_ns" logs "deployments/$_app" -f
  else
    echo "Deployment '$_app' not found on namespace '$_ns'"
  fi
}

dam_zot_sh() {
  _deployment="$1"
  _cluster="$2"
  dam_zot_export_variables "$_deployment" "$_cluster"
  _ns="$ZOT_NAMESPACE"
  _app="zot"
  if kubectl get -n "$_ns" "deployments/$_app" >/dev/null 2>&1; then
    kubectl -n "$_ns" exec -ti "deployments/$_app" -- /bin/sh
  else
    echo "Deployment '$_app' not found on namespace '$_ns'"
  fi
}

dam_zot_add_user_to_dockerconfig() {
  _deployment="$1"
  _cluster="$2"
  _user="$3"
  _ns="$4"
  _yaml="$5"
  _name="$CLUSTER_PULL_SECRETS_NAME"
  _auth_file="$ZOT_AUTH_FILE"
  case "$_user" in
    admin)
      _user="$ZOT_ADMIN_USER"
    ;;
    reader)
      _user="$ZOT_READER_USER"
    ;;
    *) echo "Wrong user '$_user', valid values are 'admin' or 'reader'"
      exit 1
    ;;
  esac
  _pass="$(file_to_stdout "$_auth_file" | sed -ne "s/^${_user}://p")"
  dam_zot_export_variables "$_deployment" "$_cluster"
  # Compute registry entries
  load_registry_conf
  _main_registry_auth_entry="$(
    print_registry_auth_entry "$REMOTE_REGISTRY_NAME" \
      "$REMOTE_REGISTRY_USER" "$REMOTE_REGISTRY_PASS"
  )"
  _zot_registry_auth_entry="$(
    print_registry_auth_entry "$ZOT_HOSTNAME" "$_user" "$_pass"
  )"
  # Create pull secret
  create_pull_secrets_yaml "$_name" "$_ns" "$_yaml" \
    "$_main_registry_auth_entry" "$_zot_registry_auth_entry"
  # Add it to the namespace
  kubectl_apply "$_yaml"
  # Patch the default account to use the previous secret to pull images
  _pull_secrets_patch="$(
    printf '{"imagePullSecrets":[{"name":"%s"}]}' "$_name"
  )"
  kubectl patch serviceaccount default -n "$_ns" -p "$_pull_secrets_patch"
}

dam_zot_install() {
  _deployment="$1"
  _cluster="$2"
  dam_zot_export_variables "$_deployment" "$_cluster"
  if [ -z "$ZOT_IMAGE" ]; then
    echo "The ZOT_IMAGE is empty, export ZOT_IMAGE or reconfigure."
    exit 1
  fi
  # Auto save the configuration if requested
  if is_selected "$ZOT_AUTO_SAVE_ENV"; then
    dam_zot_env_save "$_deployment" "$_cluster"
  fi
  # Load additional variables & check directories
  dam_common_export_service_hostnames "$_deployment" "$_cluster"
  dam_zot_check_directories
  # Adjust variables
  _app="zot"
  _ns="$ZOT_NAMESPACE"
  _auth_name="$_app-secret"
  # directory
  _chart="$ZOT_CHART_DIR"
  # files
  _auth_file="$ZOT_AUTH_FILE"
  _auth_yaml="$ZOT_AUTH_YAML"
  _helm_values_tmpl="$ZOT_HELM_VALUES_TMPL"
  _helm_values_yaml="$ZOT_HELM_VALUES_YAML"
  _helm_values_yaml_plain="$ZOT_HELM_VALUES_YAML_PLAIN"
  _cert_yaml="$ZOT_KUBECTL_DIR/tls-${ZOT_HOSTNAME}${SOPS_EXT}.yaml"
  if ! find_namespace "$_ns"; then
    # Remove old files, just in case ...
    # shellcheck disable=SC2086
    rm -f "$_helm_values_yaml" $_cert_yamls
    # Create namespace
    create_namespace "$_ns"
  fi
  # Create htpasswd file and related secret
  auth_file_update "$ZOT_ADMIN_USER" "$_auth_file"
  auth_file_update "$ZOT_READER_USER" "$_auth_file"
  create_htpasswd_secret_yaml "$_ns" "$_auth_name" "$_auth_file" "$_auth_yaml"
  # Get zot reader user & pass in base64 (used on helm tests)
  _reader_pass="$(
    file_to_stdout "$_auth_file" | sed -ne "s/^${ZOT_READER_USER}://p"
  )"
  _zot_b64_uap="$(
    printf "%s:%s" "$ZOT_READER_USER" "$_reader_pass" | openssl base64
  )"
  # Image settings
  _image_repo="${ZOT_IMAGE%:*}"
  _image_tag="${ZOT_IMAGE#*:}"
  if [ "$_image_repo" = "$_image_tag" ]; then
    _image_tag="latest"
  fi
  # YAML Values
  sed \
    -e "s%__ZOT_HOSTNAME__%$ZOT_HOSTNAME%" \
    -e "s%__ZOT_REPLICAS__%$ZOT_REPLICAS%" \
    -e "s%__ZOT_IMAGE_REPO__%$_image_repo%" \
    -e "s%__ZOT_IMAGE_TAG__%$_image_tag%" \
    -e "s%__ZOT_ADMIN_USER__%$ZOT_ADMIN_USER%" \
    -e "s%__ZOT_READER_USER__%$ZOT_READER_USER%" \
    -e "s%__ZOT_B64_UAP__%$_zot_b64_uap%" \
    -e "s%__IMAGE_PULL_POLICY__%$DEPLOYMENT_IMAGE_PULL_POLICY%" \
    -e "s%__PULL_SECRETS_NAME__%$CLUSTER_PULL_SECRETS_NAME%" \
    "$_helm_values_tmpl" > "$_helm_values_yaml_plain"
  # Apply ingress values
  replace_app_ingress_values "$_app" "$_helm_values_yaml_plain"
  # Generate encoded version if needed and remove plain version
  if [ "$_helm_values_yaml" != "$_helm_values_yaml_plain" ]; then
    stdout_to_file "$_helm_values_yaml" <"$_helm_values_yaml_plain"
    rm -f "$_helm_values_yaml_plain"
  fi
  # Create certificate secrets if needed or remove them if not
  if is_selected "$DEPLOYMENT_INGRESS_TLS_CERTS"; then
    create_app_cert_yamls "$_ns" "$ZOT_KUBECTL_DIR"
    # Install cert
    kubectl_apply "$_cert_yaml"
  else
    kubectl_delete "$_cert_yaml" || true
  fi
  # Install zot secret
  kubectl_apply "$_auth_yaml"
  # Install helm chart
  helm_upgrade "$_ns" "$_helm_values_yaml" "$_app" "$_chart"
  # Wait until deployment succeds or fails (if there is one, of course)
  kubectl rollout status deployment --timeout="$ROLLOUT_STATUS_TIMEOUT" \
    -n "$_ns" "$_app"
}

dam_zot_helm_history() {
  _deployment="$1"
  _cluster="$2"
  dam_zot_export_variables "$_deployment" "$_cluster"
  _app="zot"
  _ns="$ZOT_NAMESPACE"
  if find_namespace "$_ns"; then
    helm_history "$_ns" "$_app"
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

dam_zot_helm_rollback() {
  _deployment="$1"
  _cluster="$2"
  dam_zot_export_variables "$_deployment" "$_cluster"
  _app="zot"
  _ns="$ZOT_NAMESPACE"
  _release="$ROLLBACK_RELEASE"
  if find_namespace "$_ns"; then
    helm_rollback "$_ns" "$_app" "$_release"
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

dam_zot_reinstall() {
  _deployment="$1"
  _cluster="$2"
  dam_zot_export_variables "$_deployment" "$_cluster"
  _app="zot"
  _ns="$ZOT_NAMESPACE"
  if find_namespace "$_ns"; then
    _cimages="$(deployment_container_images "$_ns" "$_app")"
    _cname="zot"
    ZOT_IMAGE="$(echo "$_cimages" | sed -ne "s/^$_cname //p")"
    if [ "$ZOT_IMAGE" ]; then
      export ZOT_IMAGE
      dam_zot_install "$_deployment" "$_cluster"
    else
      echo "Image for '$_app' on '$_ns' not found!"
    fi
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

dam_zot_remove() {
  _deployment="$1"
  _cluster="$2"
  dam_zot_export_variables "$_deployment" "$_cluster"
  _app="zot"
  _ns="$ZOT_NAMESPACE"
  # files
  _auth_yaml="$ZOT_AUTH_YAML"
  _helm_values_yaml="$ZOT_HELM_VALUES_YAML"
  _cert_yamls=""
  for _hostname in $DEPLOYMENT_HOSTNAMES; do
    _cert_yaml="$ZOT_KUBECTL_DIR/tls-$_hostname${SOPS_EXT}.yaml"
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
    for _yaml in "$_auth_yaml" $_cert_yamls; do
      kubectl_delete "$_yaml" || true
    done
    delete_namespace "$_ns"
    footer
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
  dam_zot_clean_directories
}

dam_zot_restart() {
  _deployment="$1"
  _cluster="$2"
  dam_zot_export_variables "$_deployment" "$_cluster"
  _app="zot"
  _ns="$ZOT_NAMESPACE"
  if find_namespace "$_ns"; then
    deployment_restart "$_ns" "$_app"
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

dam_zot_status() {
  _deployment="$1"
  _cluster="$2"
  dam_zot_export_variables "$_deployment" "$_cluster"
  _app="zot"
  _ns="$ZOT_NAMESPACE"
  if find_namespace "$_ns"; then
    kubectl get all,endpoints,ingress,secrets -n "$_ns"
  else
    echo "Namespace '$_ns' for '$_app' not found!"
  fi
}

dam_zot_summary() {
  _deployment="$1"
  _cluster="$2"
  dam_zot_export_variables "$_deployment" "$_cluster"
  _ns="$ZOT_NAMESPACE"
  _app="zot"
  _ep="$ZOT_ENDPOINT"
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

dam_zot_uris() {
  _deployment="$1"
  _cluster="$2"
  dam_zot_export_variables "$_deployment" "$_cluster"
  _auth_file="$ZOT_AUTH_FILE"
  echo "docker login $ZOT_HOSTNAME"
  echo "users:"
  echo "- $(file_to_stdout "$_auth_file"|sed -ne "/^${ZOT_ADMIN_USER}:/{p}")"
  echo "- $(file_to_stdout "$_auth_file"|sed -ne "/^${ZOT_READER_USER}:/{p}")"
}

dam_zot_env_edit() {
  if [ "$EDITOR" ]; then
    _app="zot"
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

dam_zot_env_path() {
  _app="zot"
  _deployment="$1"
  _cluster="$2"
  dam_export_variables "$_deployment" "$_cluster"
  _env_file="$DEPLOY_ENVS_DIR/$_app.env"
  echo "$_env_file"
}

dam_zot_env_save() {
  _app="zot"
  _deployment="$1"
  _cluster="$2"
  dam_export_variables "$_deployment" "$_cluster"
  _env_file="$DEPLOY_ENVS_DIR/$_app.env"
  dam_zot_check_directories
  dam_zot_print_variables "$_deployment" "$_cluster" |
    stdout_to_file "$_env_file"
}

dam_zot_env_update() {
  _app="zot"
  _deployment="$1"
  _cluster="$2"
  dam_export_variables "$_deployment" "$_cluster"
  _env_file="$DEPLOY_ENVS_DIR/$_app.env"
  header "$_app configuration variables"
  dam_zot_print_variables "$_deployment" "$_cluster" |
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
    dam_zot_read_variables
    if [ -f "$_env_file" ]; then
      footer
      read_bool "Save updated $_app env vars?" "Yes"
    else
      READ_VALUE="Yes"
    fi
    if is_selected "${READ_VALUE}"; then
      dam_zot_env_save "$_deployment" "$_cluster"
      footer
      echo "$_app configuration saved to '$_env_file'"
      footer
    fi
  fi
}

dam_zot_command() {
  _command="$1"
  _deployment="$2"
  _cluster="$3"
  case "$_command" in
  env-edit | env_edit)
    dam_zot_env_edit "$_deployment" "$_cluster"
    ;;
  env-path | env_path)
    dam_zot_env_path "$_deployment" "$_cluster"
    ;;
  env-show | env_show)
    dam_zot_print_variables "$_deployment" "$_cluster" | grep -v '^#'
    ;;
  env-update | env_update)
    dam_zot_env_update "$_deployment" "$_cluster"
    ;;
  helm-history) dam_zot_helm_history "$_deployment" "$_cluster" ;;
  helm-rollback) dam_zot_helm_rollback "$_deployment" "$_cluster" ;;
  install) dam_zot_install "$_deployment" "$_cluster" ;;
  logs) dam_zot_logs "$_deployment" "$_cluster" ;;
  reinstall) dam_zot_reinstall "$_deployment" "$_cluster" ;;
  remove) dam_zot_remove "$_deployment" "$_cluster" ;;
  restart) dam_zot_restart "$_deployment" "$_cluster" ;;
  sh) dam_zot_sh "$_deployment" "$_cluster" ;;
  status) dam_zot_status "$_deployment" "$_cluster" ;;
  summary) dam_zot_summary "$_deployment" "$_cluster" ;;
  uris) dam_zot_uris "$_deployment" "$_cluster" ;;
  *)
    echo "Unknown zot subcommand '$1'"
    exit 1
    ;;
  esac
}

dam_zot_command_list() {
  _cmnds="env-edit env-path env-show env-update helm-history helm-rollback"
  _cmnds="$_cmnds install logs reinstall remove restart sh status summary uris"
  echo "$_cmnds"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
