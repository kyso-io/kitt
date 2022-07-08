#!/bin/sh
# ----
# File:        entrypoint.sh
# Description: kitt.sh container entrypoint (used to setup getent & sudo)
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

if [ "$DEBUG" = "true" ]; then
  set -x
fi

USER_NAME="${USER_NAME:-root}"
USER_UID="${USER_UID:-0}"
USER_GID="${USER_GID:-0}"
USER_HOME="${USER_HOME:-/home/$USER_NAME}"
USER_SHELL="${USER_SHELL:-/bin/bash}"

if [ "$USER_UID" -eq "0" ]; then
  if [ "$*" ]; then
    exec /bin/sh -c "$*"
  else
    exec /bin/bash -l
  fi
else
  echo "$USER_NAME:x:$USER_UID:$USER_GID:Kitt USER:$USER_HOME:$USER_SHELL" \
    >>/etc/passwd || true
  echo "$USER_NAME:::0:99999:7:::" >>/etc/shadow || true
  echo "$USER_NAME:x:$USER_GID:" >>/etc/group || true
  if [ "$DOCKER_GID" ]; then
    echo "docker:x:$DOCKER_GID:$USER_NAME" >>/etc/group || true
  fi
  echo "$USER_NAME ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/kitt-user
  # shellcheck disable=SC2086
  if [ "$*" ]; then
    exec su -s /bin/sh -c "$*" "$USER_NAME"
  else
    exec su -s /bin/bash -l "$USER_NAME"
  fi
fi

# vim: ts=2:sw=2:et:ai:sts=2
