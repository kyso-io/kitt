#!/bin/sh
# ----
# File:        addons/ingress.sh
# Description: Functions to install and remove the nginx ingress from a cluster
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022-2023 Kyso Inc.
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_ADDONS_INGRESS_SH="1"

# ---------
# Variables
# ---------

# CMND_DSC="ingress: manage the cluster nginx ingress deployment"

# Defaults
export CLUSTER_DEFAULT_INGRESS_CHART_VERSION="9.3.22"
export CLUSTER_DEFAULT_INGRESS_BACKEND_REGISTRY="docker.io"
export CLUSTER_DEFAULT_INGRESS_BACKEND_REPO="bitnami/nginx"
export CLUSTER_DEFAULT_INGRESS_BACKEND_TAG="1.22.1-debian-11-r7"
export CLUSTER_DEFAULT_INGRESS_CONTROLLER_REGISTRY="docker.io"
_controller_repo="bitnami/nginx-ingress-controller"
export CLUSTER_DEFAULT_INGRESS_CONTROLLER_REPO="$_controller_repo"
export CLUSTER_DEFAULT_INGRESS_CONTROLLER_TAG="1.5.1-debian-11-r5"
export CLUSTER_DEFAULT_INGRESS_ADD_COREDNS_CUSTOM="false"
export CLUSTER_DEFAULT_INGRESS_USE_ALB_CONTROLLER="false"
export CLUSTER_DEFAULT_INGRESS_AWS_LOAD_BALANCER_SCHEME="internet-facing"
export CLUSTER_DEFAULT_INGRESS_AWS_LOAD_BALANCER_SSL_CERT=""

# Fixed values
export INGRESS_NAMESPACE="ingress"
export INGRESS_HELM_REPO_NAME="bitnami"
export INGRESS_HELM_REPO_URL="https://charts.bitnami.com/bitnami"
export INGRESS_HELM_CHART="$INGRESS_HELM_REPO_NAME/nginx-ingress-controller"
export INGRESS_HELM_RELEASE="ingress"
export INGRESS_CERT_NAME="ingress-cert"
export INGRESS_PORTMAPS_NAMESPACE="ingress-portmaps"

# --------
# Includes
# --------

if [ -d "$INCL_DIR" ]; then
  # shellcheck source=../common.sh
  [ "$INCL_COMMON_SH" = "1" ] || . "$INCL_DIR/common.sh"
fi

# ---------
# Functions
# ---------

addons_ingress_export_variables() {
  [ -z "$_addons_ingress_export_variables" ] || return 0
  # Directories
  export INGRESS_TMPL_DIR="$TMPL_DIR/addons/ingress"
  export INGRESS_ENV_DIR="$CLUST_ENVS_DIR/ingress"
  export INGRESS_HELM_DIR="$CLUST_HELM_DIR/ingress"
  export INGRESS_KUBECTL_DIR="$CLUST_KUBECTL_DIR/ingress"
  # Templates
  export INGRESS_COREDNS_CUSTOM_TMPL="$INGRESS_TMPL_DIR/coredns-custom.yaml"
  export INGRESS_HELM_VALUES_TMPL="$INGRESS_TMPL_DIR/values.yaml"
  # Files
  export INGRESS_COREDNS_CUSTOM_YAML="$INGRESS_KUBECTL_DIR/coredns-custom.yaml"
  export INGRESS_HELM_VALUES_YAML="$INGRESS_HELM_DIR/values.yaml"
  export INGRESS_CERT_CRT="$CERTIFICATES_DIR/$CLUSTER_DOMAIN.crt"
  export INGRESS_CERT_KEY="$CERTIFICATES_DIR/$CLUSTER_DOMAIN${SOPS_EXT}.key"
  _cert_yaml="$INGRESS_KUBECTL_DIR/$INGRESS_CERT_NAME$SOPS_EXT.yaml"
  export INGRESS_CERT_YAML="$_cert_yaml"
  # Use defaults for variables missing from config files
  if [ "$CLUSTER_INGRESS_CHART_VERSION" ]; then
    export INGRESS_CHART_VERSION="$CLUSTER_INGRESS_CHART_VERSION"
  else
    export INGRESS_CHART_VERSION="$CLUSTER_DEFAULT_INGRESS_CHART_VERSION"
  fi
  if [ "$CLUSTER_INGRESS_BACKEND_REGISTRY" ]; then
    _backend_registry="$CLUSTER_INGRESS_BACKEND_REGISTRY"
  else
    _backend_registry="$CLUSTER_DEFAULT_INGRESS_BACKEND_REGISTRY"
  fi
  export INGRESS_BACKEND_REGISTRY="$_backend_registry"
  if [ "$CLUSTER_INGRESS_BACKEND_REPO" ]; then
    export INGRESS_BACKEND_REPO="$CLUSTER_INGRESS_BACKEND_REPO"
  else
    export INGRESS_BACKEND_REPO="$CLUSTER_DEFAULT_INGRESS_BACKEND_REPO"
  fi
  if [ "$CLUSTER_INGRESS_BACKEND_TAG" ]; then
    export INGRESS_BACKEND_TAG="$CLUSTER_INGRESS_BACKEND_TAG"
  else
    export INGRESS_BACKEND_TAG="$CLUSTER_DEFAULT_INGRESS_BACKEND_TAG"
  fi
  if [ "$CLUSTER_INGRESS_CONTROLLER_REGISTRY" ]; then
    _controller_registry="$CLUSTER_INGRESS_CONTROLLER_REGISTRY"
  else
    _controller_registry="$CLUSTER_DEFAULT_INGRESS_CONTROLLER_REGISTRY"
  fi
  export INGRESS_CONTROLLER_REGISTRY="$_controller_registry"
  if [ "$CLUSTER_INGRESS_CONTROLLER_REPO" ]; then
    _controller_repo="$CLUSTER_INGRESS_CONTROLLER_REPO"
  else
    _controller_repo="$CLUSTER_DEFAULT_INGRESS_CONTROLLER_REPO"
  fi
  export INGRESS_CONTROLLER_REPO="$_controller_repo"
  if [ "$CLUSTER_INGRESS_CONTROLLER_TAG" ]; then
    export INGRESS_CONTROLLER_TAG="$CLUSTER_INGRESS_CONTROLLER_TAG"
  else
    export INGRESS_CONTROLLER_TAG="$CLUSTER_DEFAULT_INGRESS_CONTROLLER_TAG"
  fi
  if [ "$CLUSTER_INGRESS_ADD_COREDNS_CUSTOM" ]; then
    _add_coredns_custom="$CLUSTER_INGRESS_ADD_COREDNS_CUSTOM"
  else
    _add_coredns_custom="$CLUSTER_DEFAULT_INGRESS_ADD_COREDNS_CUSTOM"
  fi
  export INGRESS_ADD_COREDNS_CUSTOM="$_add_coredns_custom"
  if [ "$CLUSTER_INGRESS_USE_ALB_CONTROLLER" ]; then
    _use_alb_controller="$CLUSTER_INGRESS_USE_ALB_CONTROLLER"
  else
    _use_alb_controller="$CLUSTER_DEFAULT_INGRESS_USE_ALB_CONTROLLER"
  fi
  export INGRESS_USE_ALB_CONTROLLER="$_use_alb_controller"
  if [ "$CLUSTER_INGRESS_AWS_LOAD_BALANCER_SCHEME" ]; then
    _aws_lb_scheme="$CLUSTER_INGRESS_AWS_LOAD_BALANCER_SCHEME"
  else
    _aws_lb_scheme="$CLUSTER_DEFAULT_INGRESS_AWS_LOAD_BALANCER_SCHEME"
  fi
  export INGRESS_AWS_LOAD_BALANCER_SCHEME="$_aws_lb_scheme"
  if [ "$CLUSTER_INGRESS_AWS_LOAD_BALANCER_SSL_CERT" ]; then
    _aws_lb_ssl_cert="$CLUSTER_INGRESS_AWS_LOAD_BALANCER_SSL_CERT"
  else
    _aws_lb_ssl_cert="$CLUSTER_DEFAULT_INGRESS_AWS_LOAD_BALANCER_SSL_CERT"
  fi
  export INGRESS_AWS_LOAD_BALANCER_SSL_CERT="$_aws_lb_ssl_cert"
  # Set variable to avoid loading variables twice
  _addons_ingress_export_variables="1"
}

addons_ingress_check_directories() {
  for _d in "$INGRESS_ENV_DIR" "$INGRESS_HELM_DIR" "$INGRESS_KUBECTL_DIR"; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

addons_ingress_clean_directories() {
  # Try to remove empty dirs, except if they contain secrets
  for _d in "$INGRESS_ENV_DIR" "$INGRESS_HELM_DIR" "$INGRESS_KUBECTL_DIR"; do
    if [ -d "$_d" ]; then
      rmdir "$_d" 2>/dev/null || true
    fi
  done
}

addons_ingress_read_variables() {
  _addon="ingress"
  header "Reading $_addon settings"
  read_value "Ingress Helm Chart Version" "${INGRESS_CHART_VERSION}"
  INGRESS_CHART_VERSION=${READ_VALUE}
  read_value "Ingress Backend Image Registry" "${INGRESS_BACKEND_REGISTRY}"
  INGRESS_BACKEND_REGISTRY=${READ_VALUE}
  read_value "Ingress Backend Image Repository in Registry" \
    "${INGRESS_BACKEND_REPO}"
  INGRESS_BACKEND_REPO=${READ_VALUE}
  read_value "Ingress Backend Image Tag" "${INGRESS_BACKEND_TAG}"
  INGRESS_BACKEND_TAG=${READ_VALUE}
  read_value "Ingress Controller Image Registry" \
    "${INGRESS_CONTROLLER_REGISTRY}"
  INGRESS_CONTROLLER_REGISTRY=${READ_VALUE}
  read_value "Ingress Controller Image Repository in Registry" \
    "${INGRESS_CONTROLLER_REPO}"
  INGRESS_CONTROLLER_REPO=${READ_VALUE}
  read_value "Ingress Controller Image Tag" "${INGRESS_CONTROLLER_TAG}"
  INGRESS_CONTROLLER_TAG=${READ_VALUE}
  read_bool "Add Ingress CoreDNS Custom Config" "${INGRESS_ADD_COREDNS_CUSTOM}"
  INGRESS_ADD_COREDNS_CUSTOM=${READ_VALUE}
  read_bool "Use AWS Load Balancer Controller " "${INGRESS_USE_ALB_CONTROLLER}"
  INGRESS_USE_ALB_CONTROLLER=${READ_VALUE}
  if is_selected "$INGRESS_USE_ALB_CONTROLLER"; then
    read_value "AWS load balancer scheme (internal/internet-facing)" \
      "${INGRESS_AWS_LOAD_BALANCER_SCHEME}"
    INGRESS_AWS_LOAD_BALANCER_SCHEME=${READ_VALUE}
    read_value "AWS load balancer ssl cert" \
      "${INGRESS_AWS_LOAD_BALANCER_SSL_CERT}"
    INGRESS_AWS_LOAD_BALANCER_SSL_CERT=${READ_VALUE}
  fi
}

addons_ingress_print_variables() {
  _addon="ingress"
  cat <<EOF
# Deployment $_addon settings
# ---
# Ingress Helm Chart Version
INGRESS_CHART_VERSION=$INGRESS_CHART_VERSION
# Ingress Backend Registry (change if using a private registry only)
INGRESS_BACKEND_REGISTRY=$INGRESS_BACKEND_REGISTRY
# Ingress Backend Repo on the Registry (change if using a private registry)
INGRESS_BACKEND_REPO=$INGRESS_BACKEND_REPO
# Ingress Backend Image Tag (again, change if using a private registry only)
INGRESS_BACKEND_TAG=$INGRESS_BACKEND_TAG
# Ingress Controller Registry (change if using a private registry only)
INGRESS_CONTROLLER_REGISTRY=$INGRESS_CONTROLLER_REGISTRY
# Ingress Controller Repo on the Registry (change if using a private registry)
INGRESS_CONTROLLER_REPO=$INGRESS_CONTROLLER_REPO
# Ingress Controller Image Tag (again, change if using a private registry only)
INGRESS_CONTROLLER_TAG=$INGRESS_CONTROLLER_TAG
# Add CoreDNS Custom Config (*.CLUSTER_DOMAIN returns the internal INGRESS IP)
INGRESS_ADD_COREDNS_CUSTOM=$INGRESS_ADD_COREDNS_CUSTOM
# Use AWS load balancer controller
INGRESS_USE_ALB_CONTROLLER=$INGRESS_USE_ALB_CONTROLLER
# AWS load balancer scheme (must be 'internal' or 'internet-facing')
INGRESS_AWS_LOAD_BALANCER_SCHEME=$INGRESS_AWS_LOAD_BALANCER_SCHEME
# AWS load balancer cert (leave it empty if not using ACM certificates)
INGRESS_AWS_LOAD_BALANCER_SSL_CERT=$INGRESS_AWS_LOAD_BALANCER_SSL_CERT
# ---
EOF
}

addons_ingress_create_cert_yaml() {
  _ns="$INGRESS_NAMESPACE"
  _cert_name="$INGRESS_CERT_NAME"
  _cert_crt="$INGRESS_CERT_CRT"
  _cert_key="$INGRESS_CERT_KEY"
  create_tls_cert_yaml "$_ns" "$_cert_name" "$_cert_crt" "$_cert_key" \
    "$_cert_yaml"
}

addons_ingress_newcert() {
  addons_ingress_export_variables
  _cert_yaml="$INGRESS_CERT_YAML"
  addons_ingress_create_cert_yaml "$_cert_yaml"
  kubectl_apply "$_cert_yaml"
}

addons_ingress_install() {
  addons_ingress_export_variables
  addons_ingress_check_directories
  _addon="ingress"
  _cert_name="$INGRESS_CERT_NAME"
  _cert_yaml="$INGRESS_CERT_YAML"
  _ns="$INGRESS_NAMESPACE"
  _replicas="$CLUSTER_INGRESS_REPLICAS"
  _repo_name="$INGRESS_HELM_REPO_NAME"
  _repo_url="$INGRESS_HELM_REPO_URL"
  _coredns_custom_tmpl="$INGRESS_COREDNS_CUSTOM_TMPL"
  _coredns_custom_yaml="$INGRESS_COREDNS_CUSTOM_YAML"
  _values_tmpl="$INGRESS_HELM_VALUES_TMPL"
  _values_yaml="$INGRESS_HELM_VALUES_YAML"
  _release="$INGRESS_HELM_RELEASE"
  _chart="$INGRESS_HELM_CHART"
  _version="$INGRESS_CHART_VERSION"
  header "Installing '$_addon'"
  # Create _cert_yaml
  addons_ingress_create_cert_yaml "$_cert_yaml"
  # Check helm repo
  check_helm_repo "$_repo_name" "$_repo_url"
  # Create namespace if needed
  if ! find_namespace "$_ns"; then
    create_namespace "$_ns"
  fi
  # Add ingress certificate
  kubectl_apply "$_cert_yaml"
  # Remove AWS Load Balancer Controller section if not in use
  if is_selected "${CLUSTER_INGRESS_USE_ALB_CONTROLLER}"; then
    _aws_lb_scheme="$INGRESS_AWS_LOAD_BALANCER_SCHEME"
    _aws_lb_ssl_cert="$INGRESS_AWS_LOAD_BALANCER_SSL_CERT"
    alb_controller_sed="s%__AWS_LOAD_BALANCER_SCHEME__%$_aws_lb_scheme%"
    alb_controller_sed="s%__AWS_LOAD_BALANCER_SSL_CERT__%$_aws_lb_ssl_cert%"
  else
    alb_controller_sed="/BEG: USE_ALB_CONTROLLER/,/END: USE_ALB_CONTROLLER/d"
  fi
  # Remove kyso dev port mapping if not set
  if is_selected "${CLUSTER_MAP_KYSO_DEV_PORTS}"; then
    dev_ports_sed="s%__PORTMAPS_NAMESPACE__%$INGRESS_PORTMAPS_NAMESPACE%"
  else
    dev_ports_sed="/BEG: MAP_KYSO_DEV_PORTS/,/END: MAP_KYSO_DEV_PORTS/d"
  fi
  # Values for the chart
  sed \
    -e "s%__INGRESS_CERT_NAME__%$_cert_name%" \
    -e "s%__REPLICAS__%$_replicas%" \
    -e "s%__INGRESS_BACKEND_REGISTRY__%$INGRESS_BACKEND_REGISTRY%" \
    -e "s%__INGRESS_BACKEND_REPO__%$INGRESS_BACKEND_REPO%" \
    -e "s%__INGRESS_BACKEND_TAG__%$INGRESS_BACKEND_TAG%" \
    -e "s%__INGRESS_CONTROLLER_REGISTRY__%$INGRESS_CONTROLLER_REGISTRY%" \
    -e "s%__INGRESS_CONTROLLER_REPO__%$INGRESS_CONTROLLER_REPO%" \
    -e "s%__INGRESS_CONTROLLER_TAG__%$INGRESS_CONTROLLER_TAG%" \
    -e "$dev_ports_sed" \
    -e "$alb_controller_sed" \
    "$_values_tmpl" >"$_values_yaml"
  # Update or install chart
  helm_upgrade "$_ns" "$_values_yaml" "$_release" "$_chart" "$_version"
  # Wait for installation to complete
  kubectl rollout status deployment --timeout="$ROLLOUT_STATUS_TIMEOUT" \
    -n "$_ns" "ingress-nginx-ingress-controller"
  footer
  header "LoadBalancer info:"
  kubectl -n ingress get svc | grep -E -e NAME -e LoadBalancer
  footer
  # Add the coredns custom config, if selected
  if is_selected "${INGRESS_ADD_COREDNS_CUSTOM}"; then
    sed \
      -e "s%__CLUSTER_DOMAIN__%$CLUSTER_DOMAIN%" \
      -e "s%__HELM_RELEASE__%$INGRESS_HELM_RELEASE%" \
      -e "s%__INGRESS_NAMESPACE__%$_ns%" \
      "$_coredns_custom_tmpl" >"$_coredns_custom_yaml"
    kubectl_apply "$_coredns_custom_yaml"
  else
    kubectl_delete "$_coredns_custom_yaml"
  fi
}

addons_ingress_helm_history() {
  _cluster="$1"
  addons_ingress_export_variables "$_cluster"
  _addon="ingress"
  _ns="$INGRESS_NAMESPACE"
  _release="$INGRESS_HELM_RELEASE"
  if find_namespace "$_ns"; then
    helm_history "$_ns" "$_release"
  else
    echo "Namespace '$_ns' for '$_addon' not found!"
  fi
}

addons_ingress_helm_rollback() {
  _cluster="$1"
  addons_ingress_export_variables "$_cluster"
  _addon="ingress"
  _ns="$INGRESS_NAMESPACE"
  _release="$INGRESS_HELM_RELEASE"
  _rollback_release="$ROLLBACK_RELEASE"
  if find_namespace "$_ns"; then
    helm_rollback "$_ns" "$_release" "$_rollback_release"
  else
    echo "Namespace '$_ns' for '$_addon' not found!"
  fi
}

addons_ingress_remove() {
  addons_ingress_export_variables
  _addon="ingress"
  _ns="$INGRESS_NAMESPACE"
  _secrets="$INGRESS_CERT_YAML"
  _values="$INGRESS_HELM_VALUES_YAML"
  _release="$INGRESS_HELM_RELEASE"
  _coredns_custom_yaml="$INGRESS_COREDNS_CUSTOM_YAML"
  if find_namespace "$_ns"; then
    header "Removing '$_addon' objects"
    # Delete secrets
    kubectl_delete "$_secrets" || true
    # Remove coredns custom config
    kubectl_delete "$_coredns_custom_yaml" || true
    # Uninstall chart
    if [ -f "$_values" ]; then
      helm uninstall -n "$_ns" "$_release" || true
      rm -f "$_values"
    fi
    # Delete namespace if there are no charts deployed
    if [ -z "$(helm list -n "$_ns" -q)" ]; then
      delete_namespace "$_ns"
    fi
    footer
  else
    echo "Namespace '$_ns' for '$_addon' not found!"
  fi
  addons_ingress_clean_directories
}

addons_ingress_status() {
  addons_ingress_export_variables
  _addon="ingress"
  _ns="$INGRESS_NAMESPACE"
  if find_namespace "$_ns"; then
    kubectl get all,endpoints,ingress,secrets -n "$_ns"
  else
    echo "Namespace '$_ns' for '$_addon' not found!"
  fi
}

addons_ingress_summary() {
  addons_ingress_export_variables
  _addon="ingress"
  _ns="$INGRESS_NAMESPACE"
  _release="$INGRESS_HELM_RELEASE"
  print_helm_summary "$_ns" "$_addon" "$_release"
}

addons_ingress_env_edit() {
  if [ "$EDITOR" ]; then
    _addon="ingress"
    _cluster="$1"
    addons_export_variables "$_cluster"
    _env_file="$INGRESS_ENV_DIR/$_addon.env"
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

addons_ingress_env_path() {
  _addon="ingress"
  _cluster="$1"
  addons_export_variables "$_cluster"
  _env_file="$INGRESS_ENV_DIR/$_addon.env"
  echo "$_env_file"
}

addons_ingress_env_save() {
  _addon="ingress"
  _cluster="$1"
  _env_file="$2"
  addons_ingress_check_directories
  addons_ingress_print_variables "$_cluster" | stdout_to_file "$_env_file"
}

addons_ingress_env_update() {
  _addon="ingress"
  _cluster="$1"
  addons_export_variables "$_cluster"
  _env_file="$INGRESS_ENV_DIR/$_addon.env"
  header "$_addon configuration variables"
  addons_ingress_print_variables "$_cluster" | grep -v "^#"
  if [ -f "$_env_file" ]; then
    footer
    [ "$KITT_AUTOUPDATE" = "true" ] && _update="Yes" || _update="No"
    read_bool "Update $_addon env vars?" "$_update"
  else
    READ_VALUE="Yes"
  fi
  if is_selected "${READ_VALUE}"; then
    footer
    addons_ingress_read_variables
    if [ -f "$_env_file" ]; then
      footer
      read_bool "Save updated $_addon env vars?" "Yes"
    else
      READ_VALUE="Yes"
    fi
    if is_selected "${READ_VALUE}"; then
      addons_ingress_env_save "$_cluster" "$_env_file"
      footer
      echo "$_addon configuration saved to '$_env_file'"
      footer
    fi
  fi
}

addons_ingress_command() {
  case "$1" in
  env-edit | env_edit) addons_ingress_env_edit "$_cluster" ;;
  env-path | env_path) addons_ingress_env_path "$_cluster" ;;
  env-show | env_show)
    addons_ingress_print_variables "$_cluster" | grep -v '^#'
    ;;
  env-update | env_update) addons_ingress_env_update "$_cluster" ;;
  helm-history) addons_ingress_helm_history "$_cluster" ;;
  helm-rollback) addons_ingress_helm_rollback "$_cluster" ;;
  install) addons_ingress_install ;;
  remove) addons_ingress_remove ;;
  renew) addons_ingress_newcert ;;
  status) addons_ingress_status ;;
  summary) addons_ingress_summary ;;
  *)
    echo "Unknown ingress subcommand '$1'"
    exit 1
    ;;
  esac
}

addons_ingress_command_list() {
  commands="env-edit env-path env-show env-update helm-history helm-rollback"
  commands="$commands install remove renew status summary"
  echo "$commands"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
