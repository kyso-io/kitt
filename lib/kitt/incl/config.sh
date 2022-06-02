#!/bin/sh
# ----
# File:        config.sh
# Description: Functions to read configuration files & adjust default values
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_CONFIG_SH="1"

# ---------
# Variables
# ---------

# File names
export APP_CONF_NAME=".kitt.conf"
# File extensions
export APP_DEFAULT_SOPS_EXT=".sops"
# Object names
export APP_DEFAULT_CLUSTER_PULL_SECRETS_NAME="dockerconfigjson"

# Default data directory path
[ "$APP_DEFAULT_DATA_DIR" ] || APP_DEFAULT_DATA_DIR="$HOME/kitt-data"
export APP_DEFAULT_DATA_DIR

# Default labels for cluster
[ "$APP_DEFAULT_CLUSTER_NAME" ] || APP_DEFAULT_CLUSTER_NAME="default"
export APP_DEFAULT_CLUSTER_NAME

[ "$APP_DEFAULT_CLUSTER_DOMAIN" ] || APP_DEFAULT_CLUSTER_DOMAIN="lo.kyso.io"
export APP_DEFAULT_CLUSTER_DOMAIN

[ "$APP_DEFAULT_CLUSTER_LOCAL_DOMAIN" ] ||
  APP_DEFAULT_CLUSTER_LOCAL_DOMAIN="lo.kyso.io"
export APP_DEFAULT_CLUSTER_LOCAL_DOMAIN

# Default labels for deployment
[ "$APP_DEFAULT_DEPLOYMENT_NAME" ] || APP_DEFAULT_DEPLOYMENT_NAME="dev"
export APP_DEFAULT_DEPLOYMENT_NAME

# Boolean values for cluster
[ "$APP_DEFAULT_CLUSTER_DATA_IN_GIT" ] || APP_DEFAULT_CLUSTER_DATA_IN_GIT="true"
export APP_DEFAULT_CLUSTER_DATA_IN_GIT

[ "$APP_DEFAULT_CLUSTER_USE_LOCAL_STORAGE" ] ||
  APP_DEFAULT_CLUSTER_USE_LOCAL_STORAGE="false"
export APP_DEFAULT_CLUSTER_USE_LOCAL_STORAGE

[ "$APP_DEFAULT_CLUSTER_PULL_SECRETS_IN_NS" ] ||
  APP_DEFAULT_CLUSTER_PULL_SECRETS_IN_NS="true"
export APP_DEFAULT_CLUSTER_PULL_SECRETS_IN_NS

[ "$APP_DEFAULT_CLUSTER_USE_BASIC_AUTH" ] ||
  APP_DEFAULT_CLUSTER_USE_BASIC_AUTH="true"
export APP_DEFAULT_CLUSTER_USE_BASIC_AUTH

[ "$APP_DEFAULT_CLUSTER_USE_SOPS" ] || APP_DEFAULT_CLUSTER_USE_SOPS="false"
export APP_DEFAULT_CLUSTER_USE_SOPS

# --------
# Includes
# --------

if [ -d "$INCL_DIR" ]; then
  # shellcheck source=./common.sh
  [ "$INCL_COMMON_SH" = "1" ] || . "$INCL_DIR/common.sh"
else
  echo "This file has to be sourced using kitt.sh"
  exit 1
fi

# ---------
# Functions
# ---------

# Edit the application configuration file
config_app_edit_variables() {
  if [ "$EDITOR" ]; then
    exec "$EDITOR" "$APP_CONF_PATH"
  else
    echo "Export the EDITOR environment variable to use this subcommand"
    exit 1
  fi
}

# Load app configuration from the KITT_CONF file if it exists, from the
# APP_CONF_NAME file found on the on the current directory or from the
# APP_CONF_NAME file on the user's HOME; note that only one file is processed,
# so the configuration needs to have all the values that we want to set.
config_app_load_variables() {
  app_conf_name="${APP_CONF_NAME}"
  env_conf_path="${KITT_CONF}"
  file="$env_conf_path"
  if [ ! -f "$file" ]; then
    file="$(pwd)/$app_conf_name"
  fi
  if [ ! -f "$file" ]; then
    file="$HOME/$app_conf_name"
  fi
  export_env_file_vars "$file" "APP"
  # Export the last file tried, note that if none exists it will be the
  # APP_CONF_NAME on the user's HOME
  export APP_CONF_PATH="$file"
}

# Auxiliary functions to save the app configuration file
config_app_read_variables() {
  header_with_note "Configuring KITT Defaults"
  read_value "Default data directory" "${APP_DEFAULT_DATA_DIR}"
  APP_DEFAULT_DATA_DIR=${READ_VALUE}
  read_value "Default cluster name" "${APP_DEFAULT_CLUSTER_NAME}"
  APP_DEFAULT_CLUSTER_NAME=${READ_VALUE}
  read_value "Default cluster domain" "${APP_DEFAULT_CLUSTER_DOMAIN}"
  APP_DEFAULT_CLUSTER_DOMAIN=${READ_VALUE}
  read_value "Default cluster local domain" \
    "${APP_DEFAULT_CLUSTER_LOCAL_DOMAIN}"
  APP_DEFAULT_CLUSTER_LOCAL_DOMAIN=${READ_VALUE}
  read_bool "Keep cluster data in git" "${APP_DEFAULT_CLUSTER_DATA_IN_GIT}"
  APP_DEFAULT_CLUSTER_DATA_IN_GIT=${READ_VALUE}
  read_bool "Cluster adds pull secrets to namespaces" \
    "${APP_DEFAULT_CLUSTER_PULL_SECRETS_IN_NS}"
  APP_DEFAULT_CLUSTER_PULL_SECRETS_IN_NS=${READ_VALUE}
  read_bool "Cluster adds HTTP Basic Auth to services" \
    "${APP_DEFAULT_CLUSTER_USE_BASIC_AUTH}"
  APP_DEFAULT_CLUSTER_USE_BASIC_AUTH=${READ_VALUE}
  read_bool "Cluster uses local storage" \
    "${APP_DEFAULT_CLUSTER_USE_LOCAL_STORAGE}"
  APP_DEFAULT_CLUSTER_USE_LOCAL_STORAGE=${READ_VALUE}
  read_bool "Cluster uses SOPS to manage secrets" "${APP_CLUSTER_USE_SOPS}"
  APP_DEFAULT_CLUSTER_USE_SOPS=${READ_VALUE}
  read_value "Default deployment name" "${APP_DEFAULT_DEPLOYMENT_NAME}"
  APP_DEFAULT_DEPLOYMENT_NAME=${READ_VALUE}
}

config_app_print_variables() {
  cat <<EOF
# KITT Defaults Configuration File
# ---
# This file only sets defaults, it is sourced from the first file of this list:
# - File referenced by the KITT_CONF variable,
# - File '$APP_CONF_NAME' on the working directory when calling 'kitt.sh',
# - File '$APP_CONF_NAME' on the user HOME directory.
# ---
# Default data directory, has to be an absolute path name
DEFAULT_DATA_DIR=$APP_DEFAULT_DATA_DIR
# Default cluster name, no need to change that unless developing 
DEFAULT_CLUSTER_NAME=$APP_DEFAULT_CLUSTER_NAME
# Default cluster domain, used as the default domain for the ingress server
DEFAULT_CLUSTER_DOMAIN=$APP_DEFAULT_CLUSTER_DOMAIN
# Default local domain used with the k3d registry, usually points to 127.0.0.1
DEFAULT_CLUSTER_LOCAL_DOMAIN=$APP_DEFAULT_CLUSTER_LOCAL_DOMAIN
# Keep cluster data in git or not
DEFAULT_CLUSTER_DATA_IN_GIT=$APP_DEFAULT_CLUSTER_DATA_IN_GIT
# Add credentials on all namespaces to get images from a private registry
DEFAULT_CLUSTER_PULL_SECRETS_IN_NS=$APP_DEFAULT_CLUSTER_PULL_SECRETS_IN_NS
# Enable basic auth for sensible services (disable only on dev deployments)
DEFAULT_CLUSTER_USE_BASIC_AUTH=$APP_DEFAULT_CLUSTER_USE_BASIC_AUTH
# Use local-storage storageClass for addons & apps (useful with k3d)
DEFAULT_CLUSTER_USE_LOCAL_STORAGE=$APP_DEFAULT_CLUSTER_USE_LOCAL_STORAGE
# Use sops to encrypt files (needs a ~/.sops.yaml file to be useful)
DEFAULT_CLUSTER_USE_SOPS=$APP_DEFAULT_CLUSTER_USE_SOPS
# Main deployment name, set it to the most used one
DEFAULT_DEPLOYMENT_NAME=$APP_DEFAULT_DEPLOYMENT_NAME
EOF
}

# Function to create or update the application configuration file
config_app_update_variables() {
  if [ -f "$APP_CONF_PATH" ]; then
    footer
    read_value "Update configuration? ${yes_no}" "No"
  else
    READ_VALUE="Yes"
  fi
  if is_selected "${READ_VALUE}"; then
    footer
    config_app_read_variables
    if [ -f "$APP_CONF_PATH" ]; then
      read_value "Save updated configuration? ${yes_no}" "Yes"
    else
      READ_VALUE="Yes"
    fi
    if is_selected "${READ_VALUE}"; then
      config_app_print_variables | stdout_to_file "$APP_CONF_PATH"
      footer
      echo "Configuration saved to '$APP_CONF_PATH'"
      footer
    fi
  fi
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
