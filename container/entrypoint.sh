#!/bin/sh
# ----
# File:        entrypoint.sh
# Description: kitt.sh container entrypoint (used to setup sudo)
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

if [ "$DEBUG" = "true" ]; then
  set -x
fi

USER_NAME="${USER_NAME:-root}"
USER_UID="$(id -u "$USER_NAME")"

if [ "$USER_UID" -eq "0" ]; then
  if [ "$*" ]; then
    exec /bin/sh -c "$*"
  else
    exec /bin/bash
  fi
else
  echo "$USER_NAME ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/kitt-user
  # shellcheck disable=SC2086
  if [ "$*" ]; then
    exec su -s /bin/sh -c "$*" "$USER_NAME"
  else
    exec su -s /bin/bash "$USER_NAME"
  fi
fi

# vim: ts=2:sw=2:et:ai:sts=2
