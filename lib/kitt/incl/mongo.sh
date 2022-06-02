#!/bin/sh
# ----
# File:        mongo.sh
# Description: Functions to run a mongo-cli against a kyso database on k8s
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_MONGO_SH="1"

# --------
# Includes
# --------

if [ -d "$INCL_DIR" ]; then
  # shellcheck source=./common.sh
  [ "$INCL_COMMON_SH" = "1" ] || . "$INCL_DIR/common.sh"
  # shellcheck source=./apps/mongodb.sh
  [ "$INCL_APPS_MONGODB_SH" = "1" ] || . "$INCL_DIR/apps/mongodb.sh"
else
  echo "This file has to be sourced using kitt.sh"
  exit 1
fi

# ---------
# Functions
# ---------

mongo_command() {
  _cmnd="$1"
  _arg="$2"
  _deployment="$3"
  _cluster="$4"
  apps_mongodb_export_variables "$_deployment" "$_cluster"
  if ! find_namespace "$MONGODB_NAMESPACE"; then
    echo "MongoDB Namespace '$MONGODB_NAMESPACE' not found, can't run command"
    return 1
  fi
  export MONGODB_CLI_IMAGE="$MONGODB_REGISTRY/$MONGODB_REPO:$MONGODB_CLI_TAG"
  _root_database_uri="$(
    apps_mongodb_print_root_database_uri "$_deployment" "$_cluster"
  )"
  _user_database_uri="$(
    apps_mongodb_print_user_database_uri "$_deployment" "$_cluster"
  )"
  _cmnd=""
  _file=""
  case "$1" in
  cli)
    case "$_arg" in
    root) _cmnd="mongo $_root_database_uri" ;;
    user|kyso|'') _cmnd="mongo $_user_database_uri" ;;
    *) echo "Unknown user '$_arg'"; exit 1;;
    esac
    ;;
  dump)
    if [ "$_arg" ]; then
      _cmnd="mongodump --uri $_user_database_uri --archive 2>/dev/null"
      _fdir="stdout"
      _file="$_arg"
    fi
    ;;
  restore)
    if [ "$_arg" ]; then
      _cmnd="mongorestore --uri $_user_database_uri --archive --drop"
      _file="stdin"
      _file="$_arg"
    fi
    ;;
  run)
    shift 1
    _cmnd="$_arg"
    ;;
  settings-export)
    if [ "$_arg" ]; then
      _cmnd="mongoexport --uri $_user_database_uri -c KysoSettings"
      _cmnd="$_cmnd -f key,value --type=csv 2>/dev/null"
      _fdir="stdout"
      _file="$_arg"
    fi
    ;;
  settings-merge)
    if [ "$_arg" ]; then
      _cmnd="mongoimport --uri $_user_database_uri -c KysoSettings"
      _cmnd="$_cmnd --mode=merge --headerline --upsertFields=key --type=csv"
      _cmnd="$_cmnd 2>/dev/null"
      _fdir="stdin"
      _file="$_arg"
    fi
    ;;
  esac
  # NOTE: We use diferent container names to make sure each command runs in
  # different PODs and avoid race conditions (i.e. trying to exec a command
  # when the POD is being removed)
  TS="$(date +%Y%m%d-%H%M%S)"
  container_name="mongo-cli-$TS"
  if [ -z "$_file" ]; then
    kubectl run -n "$MONGODB_NAMESPACE" "$container_name" \
      --rm --stdin --tty --wait=true --restart='Never' \
      --env "MONGODB_KYSO_DATABASE_URI=$_user_database_uri" \
      --env "MONGODB_ROOT_DATABASE_URI=$_root_database_uri" \
      --image "$MONGODB_CLI_IMAGE" --command -- /bin/sh -c "$_cmnd"
  else
    ret="0"
    kubectl run -n "$MONGODB_NAMESPACE" "$container_name" \
      --quiet --restart='Never' \
      --env "MONGODB_KYSO_DATABASE_URI=$_user_database_uri" \
      --env "MONGODB_ROOT_DATABASE_URI=$_root_database_uri" \
      --image "$MONGODB_CLI_IMAGE" --command -- /bin/sh -c "sleep infinity" \
      1>&2 || ret="$?"
    # Wait until the pod is ready
    if [ "$ret" -eq "0" ]; then
      kubectl wait pods -n "$MONGODB_NAMESPACE" -l run="$container_name" \
        --for condition=Ready --timeout=30s 1>&2 || ret="$?"
    fi
    if [ "$ret" -eq "0" ]; then
      if [ "$_fdir" = "stdout" ]; then
        kubectl exec -n "$MONGODB_NAMESPACE" "$container_name" \
          --stdin --quiet -- /bin/sh -c "$_cmnd" |
          stdout_to_file "$_file" || ret="$?"
      else
        file_to_stdout "$_file" | kubectl exec -n "$MONGODB_NAMESPACE" \
          "$container_name" --stdin --quiet -- /bin/sh -c "$_cmnd" || ret="$?"
      fi
    fi
    kubectl delete -n "$MONGODB_NAMESPACE" "pod/$container_name" --now 1>&2
  fi
  # cluster_git_update
}

mongo_command_list() {
  cat <<EOF
cli: Run the mongo client using 'root' or the 'kyso' user
dump: Dump the kyso database to the passed file
restore: Restore the kyso database from the passed file
run: Run the given command on a containter (it is executed using /bin/sh -c)
settings-export: Export the KysoSettings collection to a CSV file
settings-merge: Merge the CSV data into the KysoSettings collection
EOF
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
