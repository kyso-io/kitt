#!/bin/sh
# ----
# File:        common.sh
# Description: Auxiliary functions for kitt tools.
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_COMMON_SH="1"

# --------
# Includes
# --------

if [ -d "$INCL_DIR" ]; then
  # shellcheck source=./common/aws.sh
  [ "$INCL_COMMON_AWS_SH" = "1" ] || . "$INCL_DIR/common/aws.sh"
  # shellcheck source=./common/cluster.sh
  [ "$INCL_COMMON_CLUSTER_SH" = "1" ] || . "$INCL_DIR/common/cluster.sh"
  # shellcheck source=./common/deployment.sh
  [ "$INCL_COMMON_DEPLOYMENT_SH" = "1" ] || . "$INCL_DIR/common/deployment.sh"
  # shellcheck source=./common/helm.sh
  [ "$INCL_COMMON_HELM_SH" = "1" ] || . "$INCL_DIR/common/helm.sh"
  # shellcheck source=./common/ingress.sh
  [ "$INCL_COMMON_INGRESS_SH" = "1" ] || . "$INCL_DIR/common/ingress.sh"
  # shellcheck source=./common/io.sh
  [ "$INCL_COMMON_IO_SH" = "1" ] || . "$INCL_DIR/common/io.sh"
  # shellcheck source=./common/kubectl.sh
  [ "$INCL_COMMON_KUBECTL_SH" = "1" ] || . "$INCL_DIR/common/kubectl.sh"
  # shellcheck source=./common/network.sh
  [ "$INCL_COMMON_NETWORK_SH" = "1" ] || . "$INCL_DIR/common/network.sh"
  # shellcheck source=./common/registry.sh
  [ "$INCL_COMMON_REGISTRY_SH" = "1" ] || . "$INCL_DIR/common/registry.sh"
else
  echo "This file has to be sourced using kitt.sh"
  exit 1
fi

# ----
# vim: ts=2:sw=2:et:ai:sts=2
