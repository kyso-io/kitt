#!/bin/sh
# ----
# File:        j2f/systemd.sh
# Description: Functions to manage the j2f subcommand as a systemd service.
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_J2F_SYSTEMD_SH="1"

# ---------
# Variables
# ---------

# CMND_DSC="systemd: configure systemd services (json2file & webhook processor)"

# Fixed values
export J2F_SPOOLER_SERVICE_NAME="kitt-j2f-$USER-spooler"
J2F_SPOOLER_SERVICE_FILE="/etc/systemd/system/$J2F_SPOOLER_SERVICE_NAME.service"
export J2F_SPOOLER_SERVICE_FILE
export J2F_BASEDIR_FILE="/etc/json2file-go/basedir"
export J2F_DIRLIST_FILE="/etc/json2file-go/dirlist"
export J2F_CRT_FILE="/etc/json2file-go/certfile"
export J2F_KEY_FILE="/etc/json2file-go/keyfile"
export J2F_JSON2FILE_SERVICE_NAME="json2file-go"
export J2F_JSON2FILE_SERVICE_DIR="/etc/systemd/system/json2file-go.service.d"
export J2F_JSON2FILE_SERVICE_OVERRIDE="$J2F_JSON2FILE_SERVICE_DIR/override.conf"
export J2F_JSON2FILE_SOCKET_DIR="/etc/systemd/system/json2file-go.socket.d"
export J2F_JSON2FILE_SOCKET_OVERRIDE="$J2F_JSON2FILE_SOCKET_DIR/override.conf"

# --------
# Includes
# --------

if [ -d "$INCL_DIR" ]; then
  # shellcheck source=./common.sh
  [ "$INCL_J2F_COMMON_SH" = "1" ] || . "$INCL_DIR/j2f/common.sh"
fi

# ---------
# Functions
# ---------

j2f_systemd_export_variables() {
  # Check if we need to run the function
  [ -z "$__j2f_systemd_export_variables" ] || return 0
  j2f_common_export_variables
  if [ -z "$J2F_USER" ]; then
    J2F_USER="$(id -u)"
    export J2F_USER
  fi
  if [ -z "$J2F_GROUP" ]; then
    J2F_GROUP="$(id -g)"
    export J2F_GROUP
  fi
  # Compute tsp tmp dir
  export J2F_JSON2FILE_DIR="$J2F_DIR/json2file"
  export J2F_TLS_DIR="$J2F_DIR/tls"
  export J2F_CRT_PATH="$J2F_TLS_DIR/crt.pem"
  export J2F_KEY_PATH="$J2F_TLS_DIR/key.pem"
  # Generate J2F_DIRLIST if not defined
  if [ -z "$J2F_DIRLIST" ]; then
    J2F_DIRLIST="kyso-api:$(uuid);kyso-front:$(uuid)"
    J2F_DIRLIST="$J2F_DIRLIST;kyso-indexer:$(uuid)"
    J2F_DIRLIST="$J2F_DIRLIST;activity-feed-consumer:$(uuid)"
    J2F_DIRLIST="$J2F_DIRLIST;notification-consumer:$(uuid)"
    J2F_DIRLIST="$J2F_DIRLIST;slack-notifications-consumer:$(uuid)"
    export J2F_DIRLIST
  fi
  # set variable to avoid running the function twice
  __j2f_systemd_export_variables="1"
}

j2f_systemd_check_directories() {
  for _d in "$J2F_JSON2FILE_DIR" "$J2F_TLS_DIR"; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

j2f_systemd_clean_directories() {
  # Try to remove empty dirs
  for _d in "$J2F_JSON2FILE_DIR" "$J2F_TLS_DIR"; do
    if [ -d "$_d" ]; then
      rmdir "$_d" 2>/dev/null || true
    fi
  done
}

j2f_systemd_read_variables() {
  read_value "json2file listening port" "$J2F_PORT"
  J2F_PORT=${READ_VALUE}
  read_value "json2file user" "$J2F_USER"
  J2F_USER=${READ_VALUE}
  read_value "json2file group" "$J2F_GROUP"
  J2F_GROUP=${READ_VALUE}
  read_value "json2file dirlist (i.e. 'dir:\$(uuid);dir2:\$(uuid)')" \
    "$J2F_DIRLIST"
  J2F_DIRLIST=${READ_VALUE}
}

j2f_systemd_print_variables() {
  cat <<EOF
PORT=$J2F_PORT
USER=$J2F_USER
GROUP=$J2F_GROUP
DIRLIST=$J2F_DIRLIST
EOF
}

j2f_systemd_install_services() {
  j2f_systemd_export_variables
  _command="$APP_REAL_PATH j2f spooler '$J2F_JSON2FILE_DIR'"
  j2f_common_check_tools "inotifywait json2file-go tsp uuid"
  # Configure json2file
  sudo sh -c "echo '$J2F_JSON2FILE_DIR' >'$J2F_BASEDIR_FILE'"
  if [ ! -f "$J2F_CRT_PATH" ] || [ ! -f "$J2F_KEY_PATH" ]; then
    mkcert -cert-file "$J2F_CRT_PATH" -key-file "$J2F_KEY_PATH" "$(hostname -f)"
  fi
  sudo sh -c "echo '$J2F_CRT_PATH' >'$J2F_CRT_FILE'"
  sudo sh -c "echo '$J2F_KEY_PATH' >'$J2F_KEY_FILE'"
  sudo sh -c "cat >'$J2F_DIRLIST_FILE'" <<EOF
$(echo "$J2F_DIRLIST" | tr ';' '\n')
EOF
  # Service override
  test -d "$J2F_JSON2FILE_SERVICE_DIR" ||
    sudo mkdir "$J2F_JSON2FILE_SERVICE_DIR"
  sudo sh -c "cat >'$J2F_JSON2FILE_SERVICE_OVERRIDE'" <<EOF
[Service]                                                                                                                                                                             
User=$J2F_USER
Group=$J2F_GROUP
EOF
  # Socket override
  test -d "$J2F_JSON2FILE_SOCKET_DIR" ||
    sudo mkdir "$J2F_JSON2FILE_SOCKET_DIR"
  sudo sh -c "cat >'$J2F_JSON2FILE_SOCKET_OVERRIDE'" <<EOF
[Socket]
ListenStream=
ListenStream=$J2F_PORT
EOF
  # Configure spooler service
  sudo sh -c "cat > $J2F_SPOOLER_SERVICE_FILE" <<EOF
[Install]
WantedBy=multi-user.target
 
[Unit]
Description=json2file spooler for $USER
After=docker.service
 
[Service]
Type=simple
User=$J2F_USER
Group=$J2F_GROUP
ExecStart=$_command
WorkingDirectory=~
EOF
  # Restart and enable services
  sudo systemctl daemon-reload
  sudo systemctl stop "$J2F_JSON2FILE_SERVICE_NAME"
  sudo systemctl start "$J2F_JSON2FILE_SERVICE_NAME"
  sudo systemctl enable "$J2F_JSON2FILE_SERVICE_NAME"
  sudo systemctl stop "$J2F_SPOOLER_SERVICE_NAME"
  sudo systemctl start "$J2F_SPOOLER_SERVICE_NAME"
  sudo systemctl enable "$J2F_SPOOLER_SERVICE_NAME"
}

j2f_systemd_remove_services() {
  sudo systemctl stop "$J2F_JSON2FILE_SERVICE_NAME" || true
  sudo systemctl disable "$J2F_JSON2FILE_SERVICE_NAME" || true
  if [ -f "$J2F_SPOOLER_SERVICE_FILE" ]; then
    sudo systemctl stop "$J2F_SPOOLER_SERVICE_NAME"
    sudo systemctl disable "$J2F_SPOOLER_SERVICE_NAME"
    sudo rm -f "$J2F_SPOOLER_SERVICE_FILE"
  fi
  sudo systemctl daemon-reload
}

j2f_systemd_restart_services() {
  sudo systemctl restart "$J2F_JSON2FILE_SERVICE_NAME"
  sudo systemctl restart "$J2F_SPOOLER_SERVICE_NAME"
}

j2f_systemd_command() {
  _command="$1"
  case "$_command" in
    install) j2f_systemd_install_services ;;
    remove) j2f_systemd_remove_services ;;
    restart) j2f_systemd_restart_services ;;
    *) echo "Unknown config subcommand '$_command'"; exit 1 ;;
  esac
}

j2f_systemd_command_args() {
  echo "install remove restart"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
