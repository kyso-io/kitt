#!/bin/sh
# ----
# File:        pf.sh
# Description: Functions to run a port-forwards against kyso services on k8s
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022-2023 Kyso Inc.
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_PF_SH="1"

# --------
# Includes
# --------

if [ -d "$INCL_DIR" ]; then
  # shellcheck source=./common.sh
  [ "$INCL_COMMON_SH" = "1" ] || . "$INCL_DIR/common.sh"
  # shellcheck source=./apps/elasticsearch.sh
  [ "$INCL_APPS_ELASTICSEARCH_SH" = "1" ] || . "$INCL_DIR/apps/elasticsearch.sh"
  # shellcheck source=./apps/mongodb.sh
  [ "$INCL_APPS_MONGODB_SH" = "1" ] || . "$INCL_DIR/apps/mongodb.sh"
  # shellcheck source=./apps/kyso-scs.sh
  [ "$INCL_APPS_KYSO_SCS_SH" = "1" ] || . "$INCL_DIR/apps/kyso-scs.sh"
  # shellcheck source=./apps/nats.sh
  [ "$INCL_APPS_NATS_SH" = "1" ] || . "$INCL_DIR/apps/nats.sh"
  # shellcheck source=./dam/kyso-dam.sh
  [ "$INCL_DAM_KYSO_DAM_SH" = "1" ] || . "$INCL_DIR/dam/kyso-dam.sh"
else
  echo "This file has to be sourced using kitt.sh"
  exit 1
fi

# ---------
# Functions
# ---------

pf_note() {
  header "NOTE"
  cat <<EOF
Replace the value of LOCAL_IP_AND_PORT or LOCAL_PORT if using multiple
connections at the same time or if the port is in use on the local server.

EOF
}

pf_running() {
  _pidf="$1"
  [ -f "$_pidf" ] || return 1
  if ! kill -0 "$(cat "$_pidf")" 2>/dev/null; then
    rm -f "$_pidf"
    return 1
  fi
  return 0
}

pf_host_port() {
  _pidf="$1"
  _outf="$2"
  if pf_running "$_pidf" && [ -f "$_outf" ]; then
    sed -ne 's/^Forwarding from \(.*\) -> .*$/\1/p' "$_outf"
  fi
}

pf_status() {
  _name="$1"
  _pidf="$2"
  _outf="$3"
  _hp="$(pf_host_port "$_pidf" "$_outf")"
  [ "$_hp" ] || _hp="NOT RUNNING"
  echo "$_name port-forward: $_hp"
}

pf_stop() {
  _name="$1"
  _pidf="$2"
  _outf="$3"
  if [ -f "$_pidf" ]; then
    echo "Stopping $_name port-forward"
    kill -9 "$(cat "$_pidf")" 2>/dev/null || true
    rm -f "$_pidf"
  else
    pf_status "$_name" "$_pidf" "$_outf"
  fi
  rm -f "$_outf"
}

# Elasticsearch

pf_info_elastic() {
  _name="elasticsearch"
  _pidf="$ELASTICSEARCH_PF_PID"
  _outf="$ELASTICSEARCH_PF_OUT"
  header "$_name port-forward info"
  if ! pf_running "$_pidf"; then
    cat <<EOF

The '$_name' port-forward for the '$DEPLOYMENT_NAME' deployment is not running.

EOF
    return 0
  fi
  host_port="$(pf_host_port "$_pidf" "$_outf")"
  cat <<EOF

Use the URL 'http://$host_port' to connect to elasticsearch locally.

If you are working from a remote host redirect the ports using ssh:

  LOCAL_IP_AND_PORT="127.0.0.1:9200"
  ssh $(hostname) -L \$LOCAL_IP_AND_PORT:$host_port sleep infinity

While the ssh session is running you can connect to the database using the URL
'http://\$LOCAL_IP_AND_PORT'

EOF
}

pf_start_elastic() {
  _name="elasticsearch"
  _ns="$ELASTICSEARCH_NAMESPACE"
  _svc="svc/elasticsearch-master"
  _addr="$DEPLOYMENT_PF_ADDR"
  _pf_port="$ELASTICSEARCH_PF_PORT"
  _svc_port="9200"
  _pidf="$ELASTICSEARCH_PF_PID"
  _outf="$ELASTICSEARCH_PF_OUT"
  if ! pf_running "$_pidf"; then
    _pf_dir="$(dirname "$_pidf")"
    if [ -z "$_pidf" ] || [ ! -d "$_pf_dir" ]; then
      echo "Directory '$_pf_dir' not found!"
      echo "Have you installed '$_name'?"
      exit 1
    fi
    echo "Starting $_name port-forward"
    nohup kubectl port-forward -n "$_ns" "$_svc" --address "$_addr" \
      "$_pf_port:$_svc_port" >"$_outf" 2>/dev/null &
    echo "$!" >"$_pidf"
    sleep 1
  fi
  pf_status "$_name" "$_pidf" "$_outf"
}

pf_status_elastic() {
  _name="elasticsearch"
  _pidf="$ELASTICSEARCH_PF_PID"
  _outf="$ELASTICSEARCH_PF_OUT"
  pf_status "$_name" "$_pidf" "$_outf"
}

pf_stop_elastic() {
  _name="elasticsearch"
  _pidf="$ELASTICSEARCH_PF_PID"
  _outf="$ELASTICSEARCH_PF_OUT"
  pf_stop "$_name" "$_pidf" "$_outf"
}

# kyso-indexer

pf_info_indexer() {
  _name="indexer"
  _pidf="$KYSO_SCS_INDEXER_PF_PID"
  _outf="$KYSO_SCS_INDEXER_PF_OUT"
  header "$_name port-forward info"
  if ! pf_running "$_pidf"; then
    cat <<EOF

The '$_name' port-forward for the '$DEPLOYMENT_NAME' deployment is not running.

EOF
    return 0
  fi
  host_port="$(pf_host_port "$_pidf" "$_outf")"
  cat <<EOF

Use the URL 'http://$host_port' to connect to the indexer locally.

If you are working from a remote host redirect the ports using ssh:

  LOCAL_IP_AND_PORT="127.0.0.1:8080"
  ssh $(hostname) -L \$LOCAL_IP_AND_PORT:$host_port sleep infinity

While the ssh session is running you can connect to the indexer using the URL
'http://\$LOCAL_IP_AND_PORT'

EOF
}

pf_start_indexer() {
  _name="indexer"
  _ns="$KYSO_SCS_NAMESPACE"
  _svc="svc/kyso-scs"
  _addr="$DEPLOYMENT_PF_ADDR"
  _pf_port="$KYSO_SCS_INDEXER_PF_PORT"
  _svc_port="8080"
  _pidf="$KYSO_SCS_INDEXER_PF_PID"
  _outf="$KYSO_SCS_INDEXER_PF_OUT"
  if ! pf_running "$_pidf"; then
    _pf_dir="$(dirname "$_pidf")"
    if [ -z "$_pidf" ] || [ ! -d "$_pf_dir" ]; then
      echo "Directory '$_pf_dir' not found!"
      echo "Have you installed '$_name'?"
      exit 1
    fi
    echo "Starting $_name port-forward"
    nohup kubectl port-forward -n "$_ns" "$_svc" --address "$_addr" \
      "$_pf_port:$_svc_port" >"$_outf" 2>/dev/null &
    echo "$!" >"$_pidf"
    sleep 1
  fi
  pf_status "$_name" "$_pidf" "$_outf"
}

pf_status_indexer() {
  _name="indexer"
  _pidf="$KYSO_SCS_INDEXER_PF_PID"
  _outf="$KYSO_SCS_INDEXER_PF_OUT"
  pf_status "$_name" "$_pidf" "$_outf"
}

pf_stop_indexer() {
  _name="indexer"
  _pidf="$KYSO_SCS_INDEXER_PF_PID"
  _outf="$KYSO_SCS_INDEXER_PF_OUT"
  pf_stop "$_name" "$_pidf" "$_outf"
}

# kyso-dam

pf_info_dam() {
  _name="dam"
  _pidf="$KYSO_DAM_PF_PID"
  _outf="$KYSO_DAM_PF_OUT"
  header "$_name port-forward info"
  if ! pf_running "$_pidf"; then
    cat <<EOF

The '$_name' port-forward for the '$DEPLOYMENT_NAME' deployment is not running.

EOF
    return 0
  fi
  host_port="$(pf_host_port "$_pidf" "$_outf")"
  cat <<EOF

Use the URL 'http://$host_port' to connect to the dam locally.

If you are working from a remote host redirect the ports using ssh:

  LOCAL_IP_AND_PORT="127.0.0.1:8880"
  ssh $(hostname) -L \$LOCAL_IP_AND_PORT:$host_port sleep infinity

While the ssh session is running you can connect to the dam using the URL
'http://\$LOCAL_IP_AND_PORT'

EOF
}

pf_start_dam() {
  _name="dam"
  _ns="$KYSO_DAM_NAMESPACE"
  _svc="svc/kyso-dam"
  _addr="$DEPLOYMENT_PF_ADDR"
  _pf_port="$KYSO_DAM_PF_PORT"
  _svc_port="80"
  _pidf="$KYSO_DAM_PF_PID"
  _outf="$KYSO_DAM_PF_OUT"
  if ! pf_running "$_pidf"; then
    _pf_dir="$(dirname "$_pidf")"
    if [ -z "$_pidf" ] || [ ! -d "$_pf_dir" ]; then
      echo "Directory '$_pf_dir' not found!"
      echo "Have you installed '$_name'?"
      exit 1
    fi
    echo "Starting $_name port-forward"
    nohup kubectl port-forward -n "$_ns" "$_svc" --address "$_addr" \
      "$_pf_port:$_svc_port" >"$_outf" 2>/dev/null &
    echo "$!" >"$_pidf"
    sleep 1
  fi
  pf_status "$_name" "$_pidf" "$_outf"
}

pf_status_dam() {
  _name="dam"
  _pidf="$KYSO_DAM_PF_PID"
  _outf="$KYSO_DAM_PF_OUT"
  pf_status "$_name" "$_pidf" "$_outf"
}

pf_stop_dam() {
  _name="dam"
  _pidf="$KYSO_DAM_PF_PID"
  _outf="$KYSO_DAM_PF_OUT"
  pf_stop "$_name" "$_pidf" "$_outf"
}

# Mongodb

pf_info_mongodb() {
  _name="mongodb"
  _pidf="$MONGODB_PF_PID"
  _outf="$MONGODB_PF_OUT"
  header "$_name port-forward info"
  if ! pf_running "$_pidf"; then
    cat <<EOF

The '$_name' port-forward for the '$DEPLOYMENT_NAME' deployment is not running.

EOF
    return 0
  fi
  host_port="$(pf_host_port "$_pidf" "$_outf")"
  mongodb_root_local_uri="$(
    apps_mongodb_print_root_database_uri "$_deployment" "$_cluster" \
      "$host_port"
  )"
  mongodb_root_remote_uri="$(
    apps_mongodb_print_root_database_uri "$_deployment" "$_cluster" \
      "\$LOCAL_IP_AND_PORT"
  )"
  mongodb_user_local_uri="$(
    apps_mongodb_print_user_database_uri "$_deployment" "$_cluster" \
      "$host_port"
  )"
  mongodb_user_remote_uri="$(
    apps_mongodb_print_user_database_uri "$_deployment" "$_cluster" \
      "\$LOCAL_IP_AND_PORT"
  )"
  cat <<EOF

Use the following URIs to connect to the user/db pairs locally:

  - root/admin: $mongodb_root_local_uri
  - $MONGODB_DB_USER/$MONGODB_DB_NAME: $mongodb_user_local_uri

If you are working from a remote host redirect the ports using ssh:

  LOCAL_IP_AND_PORT="127.0.0.1:27017"
  ssh $(hostname) -L \$LOCAL_IP_AND_PORT:$host_port sleep infinity

While the ssh session is running you can connect using following URIs:

  - root/admin: $mongodb_root_remote_uri
  - $MONGODB_DB_USER/$MONGODB_DB_NAME: $mongodb_user_remote_uri

EOF
}

pf_start_mongodb() {
  _name="mongodb"
  _ns="$MONGODB_NAMESPACE"
  _svc="svc/kyso-mongodb-headless"
  _addr="$DEPLOYMENT_PF_ADDR"
  _pf_port="$MONGODB_PF_PORT"
  _svc_port="27017"
  _pidf="$MONGODB_PF_PID"
  _outf="$MONGODB_PF_OUT"
  if ! pf_running "$_pidf"; then
    _pf_dir="$(dirname "$_pidf")"
    if [ -z "$_pidf" ] || [ ! -d "$_pf_dir" ]; then
      echo "Directory '$_pf_dir' not found!"
      echo "Have you installed '$_name'?"
      exit 1
    fi
    echo "Starting $_name port-forward"
    echo kubectl port-forward -n "$_ns" "$_svc" --address "$_addr" \
      "$_pf_port:$_svc_port"
    nohup kubectl port-forward -n "$_ns" "$_svc" --address "$_addr" \
      "$_pf_port:$_svc_port" >"$_outf" 2>/dev/null &
    echo "$!" >"$_pidf"
    sleep 1
  fi
  pf_status "$_name" "$_pidf" "$_outf"
}

pf_status_mongodb() {
  _name="mongodb"
  _pidf="$MONGODB_PF_PID"
  _outf="$MONGODB_PF_OUT"
  pf_status "$_name" "$_pidf" "$_outf"
}

pf_stop_mongodb() {
  _name="mongodb"
  _pidf="$MONGODB_PF_PID"
  _outf="$MONGODB_PF_OUT"
  pf_stop "$_name" "$_pidf" "$_outf"
}

# Myssh

pf_info_myssh() {
  _name="myssh"
  _pidf="$KYSO_SCS_MYSSH_PF_PID"
  _outf="$KYSO_SCS_MYSSH_PF_OUT"
  header "$_name port-forward info"
  if ! pf_running "$_pidf"; then
    cat <<EOF

The '$_name' port-forward for the '$DEPLOYMENT_NAME' deployment is not running.

EOF
    return 0
  fi
  host_port="$(pf_host_port "$_pidf" "$_outf")"
  sftp_host="${host_port%:*}"
  sftp_port="${host_port#*:}"
  user_pass="$(
    file_to_stdout "$KYSO_SCS_USERS_TAR" | tar xOf - user_pass.txt |
      sed -e 's/^/  - /'
  )"
  cat <<EOF

To connect to the sftp server locally do:

  sftp -P ${sftp_port} \$sftp_user@${sftp_host}

using one of the following users and its password:

$user_pass

If you are working from a remote host redirect the ports using ssh:

  LOCAL_IP="127.0.0.1"; LOCAL_PORT="2020"
  ssh $(hostname) -L \$LOCAL_IP:\$LOCAL_PORT:$host_port sleep infinity

While the ssh session is running you can connect to the sftp as follows using
the same password or key used locally:

  sftp -P \$LOCAL_PORT \$sftp_user@\$LOCAL_IP

EOF
}

pf_start_myssh() {
  _name="myssh"
  _ns="$KYSO_SCS_NAMESPACE"
  _svc="svc/kyso-scs"
  _addr="$DEPLOYMENT_PF_ADDR"
  _pf_port="$KYSO_SCS_MYSSH_PF_PORT"
  _svc_port="22"
  _pidf="$KYSO_SCS_MYSSH_PF_PID"
  _outf="$KYSO_SCS_MYSSH_PF_OUT"
  if ! pf_running "$_pidf"; then
    _pf_dir="$(dirname "$_pidf")"
    if [ -z "$_pidf" ] || [ ! -d "$_pf_dir" ]; then
      echo "Directory '$_pf_dir' not found!"
      echo "Have you installed '$_name'?"
      exit 1
    fi
    echo "Starting $_name port-forward"
    nohup kubectl port-forward -n "$_ns" "$_svc" --address "$_addr" \
      "$_pf_port:$_svc_port" >"$_outf" 2>/dev/null &
    echo "$!" >"$_pidf"
    sleep 1
  fi
  pf_status "$_name" "$_pidf" "$_outf"
}

pf_status_myssh() {
  _name="myssh"
  _pidf="$KYSO_SCS_MYSSH_PF_PID"
  _outf="$KYSO_SCS_MYSSH_PF_OUT"
  pf_status "$_name" "$_pidf" "$_outf"
}

pf_stop_myssh() {
  _name="myssh"
  _pidf="$KYSO_SCS_MYSSH_PF_PID"
  _outf="$KYSO_SCS_MYSSH_PF_OUT"
  pf_stop "$_name" "$_pidf" "$_outf"
}

# NATS

pf_info_nats() {
  _name="nats"
  _pidf="$NATS_PF_PID"
  _outf="$NATS_PF_OUT"
  header "$_name port-forward info"
  if ! pf_running "$_pidf"; then
    cat <<EOF

The '$_name' port-forward for the '$DEPLOYMENT_NAME' deployment is not running.

EOF
    return 0
  fi
  host_port="$(pf_host_port "$_pidf" "$_outf")"
  cat <<EOF

Use the URL 'nats://$host_port' to connect to nats locally.

If you are working from a remote host redirect the ports using ssh:

  LOCAL_IP_AND_PORT="127.0.0.1:4222"
  ssh $(hostname) -L \$LOCAL_IP_AND_PORT:$host_port sleep infinity

While the ssh session is running you can connect to NATS using the URL
'nats://\$LOCAL_IP_AND_PORT'

EOF
}

pf_start_nats() {
  _name="nats"
  _ns="$NATS_NAMESPACE"
  _svc="svc/$NATS_RELEASE"
  _addr="$DEPLOYMENT_PF_ADDR"
  _pf_port="$NATS_PF_PORT"
  _svc_port="4222"
  _pidf="$NATS_PF_PID"
  _outf="$NATS_PF_OUT"
  if ! pf_running "$_pidf"; then
    _pf_dir="$(dirname "$_pidf")"
    if [ -z "$_pidf" ] || [ ! -d "$_pf_dir" ]; then
      echo "Directory '$_pf_dir' not found!"
      echo "Have you installed '$_name'?"
      exit 1
    fi
    echo "Starting $_name port-forward"
    nohup kubectl port-forward -n "$_ns" "$_svc" --address "$_addr" \
      "$_pf_port:$_svc_port" >"$_outf" 2>/dev/null &
    echo "$!" >"$_pidf"
    sleep 1
  fi
  pf_status "$_name" "$_pidf" "$_outf"
}

pf_status_nats() {
  _name="nats"
  _pidf="$NATS_PF_PID"
  _outf="$NATS_PF_OUT"
  pf_status "$_name" "$_pidf" "$_outf"
}

pf_stop_nats() {
  _name="nats"
  _pidf="$NATS_PF_PID"
  _outf="$NATS_PF_OUT"
  pf_stop "$_name" "$_pidf" "$_outf"
}

# Webhook

pf_info_webhook() {
  _name="webhook"
  _pidf="$KYSO_SCS_WEBHOOK_PF_PID"
  _outf="$KYSO_SCS_WEBHOOK_PF_OUT"
  header "$_name port-forward info"
  if ! pf_running "$_pidf"; then
    cat <<EOF

The '$_name' port-forward for the '$DEPLOYMENT_NAME' deployment is not running.

EOF
    return 0
  fi
  host_port="$(pf_host_port "$_pidf" "$_outf")"
  cat <<EOF

Use the URL 'http://$host_port/hooks/{id}' to connect to webhook locally.

If you are working from a remote host redirect the ports using ssh:

  LOCAL_IP_AND_PORT="127.0.0.1:9000"
  ssh $(hostname) -L \$LOCAL_IP_AND_PORT:$host_port sleep infinity

While the ssh session is running you can connect to the database using the URL
'http://\$LOCAL_IP_AND_PORT'

EOF
}

pf_start_webhook() {
  _name="webhook"
  _ns="$KYSO_SCS_NAMESPACE"
  _svc="svc/kyso-scs"
  _addr="$DEPLOYMENT_PF_ADDR"
  _pf_port="$KYSO_SCS_WEBHOOK_PF_PORT"
  _svc_port="9000"
  _pidf="$KYSO_SCS_WEBHOOK_PF_PID"
  _outf="$KYSO_SCS_WEBHOOK_PF_OUT"
  if ! pf_running "$_pidf"; then
    _pf_dir="$(dirname "$_pidf")"
    if [ -z "$_pidf" ] || [ ! -d "$_pf_dir" ]; then
      echo "Directory '$_pf_dir' not found!"
      echo "Have you installed '$_name'?"
      exit 1
    fi
    echo "Starting $_name port-forward"
    nohup kubectl port-forward -n "$_ns" "$_svc" --address "$_addr" \
      "$_pf_port:$_svc_port" >"$_outf" 2>/dev/null &
    echo "$!" >"$_pidf"
    sleep 1
  fi
  pf_status "$_name" "$_pidf" "$_outf"
}

pf_status_webhook() {
  _name="webhook"
  _pidf="$KYSO_SCS_WEBHOOK_PF_PID"
  _outf="$KYSO_SCS_WEBHOOK_PF_OUT"
  pf_status "$_name" "$_pidf" "$_outf"
}

pf_stop_webhook() {
  _name="webhook"
  _pidf="$KYSO_SCS_WEBHOOK_PF_PID"
  _outf="$KYSO_SCS_WEBHOOK_PF_OUT"
  pf_stop "$_name" "$_pidf" "$_outf"
}

# Main commands function

pf_command() {
  _arg="$1"
  _cmnd="$2"
  _deployment="$3"
  _cluster="$4"
  apps_elasticsearch_export_variables "$_deployment" "$_cluster"
  apps_mongodb_export_variables "$_deployment" "$_cluster"
  apps_kyso_scs_export_variables "$_deployment" "$_cluster"
  apps_nats_export_variables "$_deployment" "$_cluster"
  dam_kyso_dam_export_variables "$_deployment" "$_cluster"
  case "$_arg" in
  all | "")
    case "$_cmnd" in
    info)
      pf_info_dam "$_deployment" "$_cluster"
      pf_info_elastic "$_deployment" "$_cluster"
      pf_info_indexer "$_deployment" "$_cluster"
      pf_info_mongodb "$_deployment" "$_cluster"
      pf_info_myssh "$_deployment" "$_cluster"
      pf_info_nats "$_deployment" "$_cluster"
      pf_info_webhook "$_deployment" "$_cluster"
      for _pidf in "$ELASTICSEARCH_PF_PID" "$MONGODB_PF_PID" \
        "$KYSO_SCS_MYSSH_PF_PID" "$NATS_PF_PID"; do
        if pf_running "$_pidf"; then
          pf_note
          break
        fi
      done
      ;;
    start)
      pf_start_dam "$_deployment" "$_cluster"
      pf_start_elastic "$_deployment" "$_cluster"
      pf_start_indexer "$_deployment" "$_cluster"
      pf_start_mongodb "$_deployment" "$_cluster"
      pf_start_myssh "$_deployment" "$_cluster"
      pf_start_nats "$_deployment" "$_cluster"
      pf_start_webhook "$_deployment" "$_cluster"
      ;;
    stop)
      pf_stop_dam "$_deployment" "$_cluster"
      pf_stop_elastic "$_deployment" "$_cluster"
      pf_stop_indexer "$_deployment" "$_cluster"
      pf_stop_mongodb "$_deployment" "$_cluster"
      pf_stop_myssh "$_deployment" "$_cluster"
      pf_stop_nats "$_deployment" "$_cluster"
      pf_stop_webhook "$_deployment" "$_cluster"
      ;;
    status)
      pf_status_dam "$_deployment" "$_cluster"
      pf_status_elastic "$_deployment" "$_cluster"
      pf_status_indexer "$_deployment" "$_cluster"
      pf_status_mongodb "$_deployment" "$_cluster"
      pf_status_myssh "$_deployment" "$_cluster"
      pf_status_nats "$_deployment" "$_cluster"
      pf_status_webhook "$_deployment" "$_cluster"
      ;;
    *)
      echo "Unknown subcommand '$_cmnd'"
      exit 1
      ;;
    esac
    ;;
  dam)
    case "$_cmnd" in
    info)
      pf_info_dam "$_deployment" "$_cluster"
      if pf_running "$DAM_PF_PID"; then pf_note; fi
      ;;
    start) pf_start_dam "$_deployment" "$_cluster" ;;
    stop) pf_stop_dam "$_deployment" "$_cluster" ;;
    status) pf_status_dam "$_deployment" "$_cluster" ;;
    *)
      echo "Unknown subcommand '$_cmnd'"
      exit 1
      ;;
    esac
    ;;
  elastic | elasticsearch)
    case "$_cmnd" in
    info)
      pf_info_elastic "$_deployment" "$_cluster"
      if pf_running "$ELASTICSEARCH_PF_PID"; then pf_note; fi
      ;;
    start) pf_start_elastic "$_deployment" "$_cluster" ;;
    stop) pf_stop_elastic "$_deployment" "$_cluster" ;;
    status) pf_status_elastic "$_deployment" "$_cluster" ;;
    *)
      echo "Unknown subcommand '$_cmnd'"
      exit 1
      ;;
    esac
    ;;
  indexer)
    case "$_cmnd" in
    info)
      pf_info_indexer "$_deployment" "$_cluster"
      if pf_running "$INDEXER_PF_PID"; then pf_note; fi
      ;;
    start) pf_start_indexer "$_deployment" "$_cluster" ;;
    stop) pf_stop_indexer "$_deployment" "$_cluster" ;;
    status) pf_status_indexer "$_deployment" "$_cluster" ;;
    *)
      echo "Unknown subcommand '$_cmnd'"
      exit 1
      ;;
    esac
    ;;
  mongodb)
    case "$_cmnd" in
    info)
      pf_info_mongodb "$_deployment" "$_cluster"
      if pf_running "$MONGODB_PF_PID"; then pf_note; fi
      ;;
    start) pf_start_mongodb "$_deployment" "$_cluster" ;;
    stop) pf_stop_mongodb "$_deployment" "$_cluster" ;;
    status) pf_status_mongodb "$_deployment" "$_cluster" ;;
    *)
      echo "Unknown subcommand '$_cmnd'"
      exit 1
      ;;
    esac
    ;;
  myssh | sftp)
    case "$_cmnd" in
    info)
      pf_info_myssh "$_deployment" "$_cluster"
      if pf_running "$KYSO_SCS_MYSSH_PF_PID"; then pf_note; fi
      ;;
    start) pf_start_myssh "$_deployment" "$_cluster" ;;
    stop) pf_stop_myssh "$_deployment" "$_cluster" ;;
    status) pf_status_myssh "$_deployment" "$_cluster" ;;
    *)
      exit 1
      echo "Unknown subcommand '$_cmnd'"
      ;;
    esac
    ;;
  nats)
    case "$_cmnd" in
    info)
      pf_info_nats "$_deployment" "$_cluster"
      if pf_running "$NATS_PF_PID"; then pf_note; fi
      ;;
    start) pf_start_nats "$_deployment" "$_cluster" ;;
    stop) pf_stop_nats "$_deployment" "$_cluster" ;;
    status) pf_status_nats "$_deployment" "$_cluster" ;;
    *)
      echo "Unknown subcommand '$_cmnd'"
      exit 1
      ;;
    esac
    ;;
  webhook)
    case "$_cmnd" in
    info)
      pf_info_webhook "$_deployment" "$_cluster"
      if pf_running "$NATS_PF_PID"; then pf_note; fi
      ;;
    start) pf_start_webhook "$_deployment" "$_cluster" ;;
    stop) pf_stop_webhook "$_deployment" "$_cluster" ;;
    status) pf_status_webhook "$_deployment" "$_cluster" ;;
    *)
      echo "Unknown subcommand '$_cmnd'"
      exit 1
      ;;
    esac
    ;;
  *)
    echo "Unknown service '$_arg'"
    exit 1
    ;;
  esac
  # Update git ... do we really need to?
  case "$_cmnd" in
  info | status) ;;
  *) cluster_git_update ;;
  esac
}

pf_command_list() {
  cat <<EOF
info: print information about a port-forward
start: start a port-forward
stop: stop a port-forward
status: show the status of a port-forward
EOF
}

pf_service_list() {
  cat <<EOF
all: work on all the port-forwards
dam: operate on the dam port
elastic|elastisearch: operate on the elasticsearch web port
indexer: operate on the kyso-indexer port
mongodb: operate on the mongodb database port
myssh|sftp: operate on the the kyso-scs sftp port
nats: operate on the nats client port
webhook: operate on the webhook http server port
EOF
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
