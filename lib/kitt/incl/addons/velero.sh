#!/bin/sh
# ----
# File:        addons/velero.sh
# Description: Functions to install and remove velero from a cluster
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_ADDONS_VELERO_SH="1"

# ---------
# Variables
# ---------

# CMND_DSC="velero: manage the cluster velero deployment (backups)"

# Fixed values
export VELERO_NAMESPACE="velero"
export VELERO_HELM_REPO_NAME="vmware-tanzu"
export VELERO_HELM_REPO_URL="https://vmware-tanzu.github.io/helm-charts"
export VELERO_HELM_CHART="$VELERO_HELM_REPO_NAME/velero"
export VELERO_HELM_RELEASE="velero"

# --------
# Includes
# --------

if [ -d "$INCL_DIR" ]; then
  # shellcheck source=../common.sh
  [ "$INCL_COMMON_SH" = "1" ] || . "$INCL_DIR/common.sh"
  # shellcheck source=./minio.sh
  [ "$INCL_ADDONS_MINIO_SH" = "1" ] || . "$INCL_DIR/addons/minio.sh"
fi

# ---------
# Functions
# ---------

addon_velero_export_variables() {
  [ -z "$__addon_velero_export_variables" ] || return 0
  # Directories
  export VELERO_TMPL_DIR="$TMPL_DIR/addons/velero"
  export VELERO_HELM_DIR="$CLUST_HELM_DIR/velero"
  export VELERO_SECRETS_DIR="$CLUST_SECRETS_DIR/velero"
  # Templates
  export VELERO_HELM_VALUES_TMPL="$VELERO_TMPL_DIR/values.yaml"
  export VELERO_POLICY_JSON_TMPL="$VELERO_TMPL_DIR/velero-policy.json"
  # Files
  export VELERO_HELM_VALUES_YAML="$VELERO_HELM_DIR/values.yaml"
  export VELERO_S3_ENV="$VELERO_SECRETS_DIR/s3${SOPS_EXT}.env"
  export_env_file_vars "$VELERO_S3_ENV" "VELERO"
  if is_selected "$VELERO_USE_MINIO"; then
    addon_minio_export_variables
    export VELERO_USE_LOCAL_STORAGE="$CLUSTER_USE_LOCAL_STORAGE"
    export VELERO_AWS_ACCESS_KEY_ID="$MINIO_ROOT_USER"
    export VELERO_AWS_SECRET_ACCESS_KEY="$MINIO_ROOT_PASS"
    export VELERO_BUCKET="velero"
    export VELERO_REGION="minio"
    export VELERO_S3_URL="http://minio:9000"
    export VELERO_S3_PUBLIC_URL="https://minio.$CLUSTER_DOMAIN"
  fi
  # Set variable to avoid loading variables twice
  __addon_velero_export_variables="1"
}

addon_velero_check_directories() {
  for _d in "$VELERO_HELM_DIR" "$VELERO_SECRETS_DIR"; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

addon_velero_clean_directories() {
  # Try to remove empty dirs, except if they contain secrets
  for _d in "$VELERO_HELM_DIR" "$VELERO_SECRETS_DIR"; do
    if [ -d "$_d" ]; then
      rmdir "$_d" 2>/dev/null || true
    fi
  done
}

addon_velero_print_vars() {
  cat <<EOF
USE_MINIO=$VELERO_USE_MINIO
AWS_ACCESS_KEY_ID=$VELERO_AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY=$VELERO_AWS_SECRET_ACCESS_KEY
BUCKET=$VELERO_BUCKET
REGION=$VELERO_REGION
S3_URL=$VELERO_S3_URL
S3_PUBLIC_URL=$VELERO_S3_PUBLIC_URL
EOF
}

addon_velero_read_vars() {
  header "Configuring Velero Parameters"
  read_bool "Use minio for velero" "$VELERO_USE_MINIO"
  VELERO_USE_MINIO=${READ_VALUE}
  if is_selected "$VELERO_USE_MINIO"; then
    addon_velero_export_minio_variables
    return 0
  fi
  read_bool "Configure velero on AWS" "false"
  if is_selected "${READ_VALUE}"; then
    read_bool "Create velero bucket" "false"
    if is_selected "${READ_VALUE}"; then
      aws_create_velero_bucket || true
    fi
    read_bool "Create velero user" "false"
    if is_selected "${READ_VALUE}"; then
      aws_create_velero_user || true
    fi
    read_bool "Add velero user policy" "false"
    if is_selected "${READ_VALUE}"; then
      aws_add_velero_user_policy "$VELERO_POLICY_JSON_TMPL" || true
    fi
    read_bool "Create velero s3 env" "false"
    if is_selected "${READ_VALUE}"; then
      addon_velero_check_directories
      aws_create_velero_s3_env "$VELERO_S3_ENV" || true
      export_env_file_vars "$VELERO_S3_ENV" "VELERO"
    fi
  else
    read_value "Velero Bucket" "$VELERO_BUCKET"
    VELERO_BUCKET=$READ_VALUE
    read_value "Velero Region" "$VELERO_REGION"
    VELERO_REGION=$READ_VALUE
    read_value "Velero AWS Access Key Id" "$VELERO_AWS_ACCESS_KEY_ID"
    VELERO_AWS_ACCESS_KEY_ID=${READ_VALUE}
    read_value "Velero AWS Secret Access Key" "$VELERO_AWS_SECRET_ACCESS_KEY"
    VELERO_AWS_SECRET_ACCESS_KEY=${READ_VALUE}
    read_value "Velero S3 URL" "$VELERO_S3_URL"
    VELERO_S3_URL=${READ_VALUE}
    read_value "Velero S3 Public URL" "$VELERO_S3_PUBLIC_URL"
    VELERO_S3_PUBLIC_URL=${READ_VALUE}
  fi
}

addon_velero_config() {
  addon_velero_export_variables
  header "Velero configuration variables"
  addon_velero_print_vars
  if [ -f "$VELERO_S3_ENV" ]; then
    footer
    read_bool "Update configuration?" "false"
  else
    READ_VALUE="true"
  fi
  if is_selected "${READ_VALUE}"; then
    footer
    addon_velero_read_vars
    if [ -f "$VELERO_S3_ENV" ]; then
      read_bool "Save updated configuration?" "true"
    else
      READ_VALUE="true"
    fi
    if is_selected "${READ_VALUE}"; then
      addon_velero_check_directories
      addon_velero_print_vars | stdout_to_file "$VELERO_S3_ENV"
      footer
      echo "Configuration saved to '$VELERO_S3_ENV'"
      footer
    fi
  fi
}

addon_velero_install() {
  addon_velero_export_variables
  if [ ! -f "$VELERO_S3_ENV" ]; then
    echo "Configure Velero calling the 'config' subcommand"
    exit 1
  fi
  addon_velero_check_directories
  _addon="velero"
  _ns="$VELERO_NAMESPACE"
  _repo_name="$VELERO_HELM_REPO_NAME"
  _repo_url="$VELERO_HELM_REPO_URL"
  _values_tmpl="$VELERO_HELM_VALUES_TMPL"
  _values_yaml="$VELERO_HELM_VALUES_YAML"
  if is_selected "$VELERO_USE_LOCAL_STORAGE"; then
    _pvc_name="$MINIO_HELM_RELEASE-$MINIO_NAMESPACE-pvc"
  else
    _pvc_name=""
  fi
  _release="$VELERO_HELM_RELEASE"
  _chart="$VELERO_HELM_CHART"
  header "Installing '$_addon'"
  # Check helm repo
  check_helm_repo "$_repo_name" "$_repo_url"
  # Create namespace if needed
  if ! find_namespace "$_ns"; then
    create_namespace "$_ns"
  fi
  if is_selected "$VELERO_USE_MINIO"; then
    _snapshots_enabled="false"
  else
    _snapshots_enabled="true"
  fi
  if [ "$VELERO_S3_URL" ]; then
    _s3_url_sed="s%__S3_URL__%$VELERO_S3_URL%"
  else
    _s3_url_sed="/__S3_URL__/d"
  fi
  if [ "$VELERO_S3_PUBLIC_URL" ]; then
    _s3_public_url_sed="s%__S3_PUBLIC_URL__%$VELERO_S3_PUBLIC_URL%"
  else
    _s3_public_url_sed="/__S3_PUBLIC_URL__/d"
  fi
  # Values for the chart
  sed \
    -e "s%__CLUSTER_DOMAIN__%$CLUSTER_DOMAIN%" \
    -e "s%__AWS_ACCESS_KEY_ID__%$VELERO_AWS_ACCESS_KEY_ID%" \
    -e "s%__AWS_SECRET_ACCESS_KEY__%$VELERO_AWS_SECRET_ACCESS_KEY%" \
    -e "s%__BUCKET__%$VELERO_BUCKET%" \
    -e "s%__REGION__%$VELERO_REGION%" \
    -e "$_s3_url_sed" \
    -e "$_s3_public_url_sed" \
    -e "s%__SNAPSHOTS_ENABLED__%$_snapshots_enabled%" \
    "$_values_tmpl" >"$_values_yaml"
  # Update or install chart
  helm_upgrade "$_ns" "$_values_yaml" "$_release" "$_chart"
  footer
}

addon_velero_remove() {
  addon_velero_export_variables
  _addon="velero"
  _ns="$VELERO_NAMESPACE"
  _values_yaml="$VELERO_HELM_VALUES_YAML"
  _release="$VELERO_HELM_RELEASE"
  if find_namespace "$_ns"; then
    header "Removing '$_addon' objects"
    # Uninstall chart
    if [ -f "$_values_yaml" ]; then
      helm uninstall -n "$_ns" "$_release" || true
      rm -f "$_values_yaml"
    fi
    # Delete namespace if there are no charts deployed
    if [ -z "$(helm list -n "$_ns" -q)" ]; then
      delete_namespace "$_ns"
    fi
    footer
  else
    echo "Namespace '$_ns' for '$_addon' not found!"
  fi
  addon_velero_clean_directories
}

addon_velero_status() {
  addon_velero_export_variables
  _addon="velero"
  _ns="$VELERO_NAMESPACE"
  _release="$VELERO_HELM_RELEASE"
  if find_namespace "$_ns"; then
    kubectl get all,endpoints,ingress,secrets -n "$_ns" \
      -l "app.kubernetes.io/name=$_addon"
  else
    echo "Namespace '$_ns' for '$_addon' not found!"
  fi
}

addon_velero_summary() {
  addon_velero_export_variables
  _addon="velero"
  _ns="$VELERO_NAMESPACE"
  _release="$VELERO_HELM_RELEASE"
  print_helm_summary "$_ns" "$_addon" "$_release"
}


addon_velero_command() {
  case "$1" in
  config) addon_velero_config ;;
  install) addon_velero_install ;;
  remove) addon_velero_remove ;;
  status) addon_velero_status ;;
  summary) addon_velero_summary ;;
  *)
    echo "Unknown velero subcommand '$1'"
    exit 1
    ;;
  esac
}

addon_velero_command_list() {
  echo "config install remove status summary"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
