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
  case "$_cmnd" in
  cli | dump | restore | settings-export | settings-merge | version-set)
    _arg="$2"
    _deployment="$3"
    _cluster="$4"
    ;;
  image | shell | settings-count | version-get)
    _deployment="$2"
    _cluster="$3"
    ;;
  *)
    echo "Unkown mongo command '$_cmnd', aborting"
    exit 1
    ;;
  esac
  apps_mongodb_export_variables "$_deployment" "$_cluster"
  _cli_image="$MONGODB_IMAGE_REGISTRY/$MONGODB_IMAGE_REPO:$MONGODB_CLI_TAG"
  export MONGODB_CLI_IMAGE="$_cli_image"
  # Process the image command now (it does not use the cluster, print & exit)
  if [ "$_cmnd" = "image" ]; then
    echo "$MONGODB_CLI_IMAGE"
    return 0
  fi
  if ! find_namespace "$MONGODB_NAMESPACE"; then
    echo "MongoDB Namespace '$MONGODB_NAMESPACE' not found, can't run command"
    return 1
  fi
  _root_database_uri="$(
    apps_mongodb_print_root_database_uri "$_deployment" "$_cluster"
  )"
  _user_database_uri="$(
    apps_mongodb_print_user_database_uri "$_deployment" "$_cluster"
  )"
  _file=""
  case "$_cmnd" in
  cli)
    case "$_arg" in
    root)
      _script="mongosh $_root_database_uri"
      ;;
    kyso)
      _script="mongosh $_user_database_uri"
      ;;
    *)
      echo "Unknown user '$_arg'"
      exit 1
      ;;
    esac
    ;;
  dump)
    if [ "$_arg" ]; then
      _script="mongodump --uri $_user_database_uri --archive 2>/dev/null"
      _fdir="stdout"
      _file="$_arg"
    else
      echo "Pass the FILE to dump the database contents to"
      exit 1
    fi
    ;;
  restore)
    if [ "$_arg" ]; then
      _script="mongorestore --uri $_user_database_uri --archive --drop"
      _file="stdin"
      _file="$_arg"
    else
      echo "Pass the database dump FILE to restore"
      exit 1
    fi
    ;;
  settings-export)
    if [ "$_arg" ]; then
      _script="mongoexport --uri $_user_database_uri -c KysoSettings"
      _script="$_script -f key,value --type=csv 2>/dev/null"
      _fdir="stdout"
      _file="$_arg"
    else
      echo "Pass the CSV FILE to write settings to"
      exit 1
    fi
    ;;
  settings-merge)
    if [ "$_arg" ]; then
      _script="mongoimport --uri $_user_database_uri -c KysoSettings"
      _script="$_script --mode=merge --headerline --upsertFields=key --type=csv"
      _script="$_script 2>/dev/null"
      _fdir="stdin"
      _file="$_arg"
    else
      echo "Pass the CSV FILE to merge from (first line must be 'key,value')"
      exit 1
    fi
    ;;
  settings-count)
    _mongo_script="db.KysoSettings.countDocuments();"
    _script="mongosh $_user_database_uri --quiet --eval '$_mongo_script'"
    _fdir=""
    _file="-"
    ;;
  shell)
    _script="exec /bin/bash"
    ;;
  version-get)
    _admin_command_args="{ getParameter: 1, featureCompatibilityVersion: 1 }"
    _mongo_script="db.adminCommand($_admin_command_args);"
    _script="mongosh $_root_database_uri --quiet --eval '$_mongo_script'"
    _fdir=""
    _file="-"
    ;;
  version-set)
    if [ "$_arg" ]; then
      _admin_command_args="{ setFeatureCompatibilityVersion: \"$_arg\" }"
      _mongo_script="db.adminCommand($_admin_command_args);"
      _script="mongosh $_root_database_uri --quiet --eval '$_mongo_script'"
      _fdir=""
      _file="-"
    else
      echo "Pass the compatibility version (i.e. '5.0')"
      exit 1
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
      --image "$MONGODB_CLI_IMAGE" --command -- /bin/sh -c "$_script"
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
        kubectl exec -n "$MONGODB_NAMESPACE" "$container_name" --stdin \
          --quiet -- /bin/sh -c "$_script" | stdout_to_file "$_file" ||
          ret="$?"
      elif [ "$_fdir" = "stdin" ]; then
        file_to_stdout "$_file" | kubectl exec -n "$MONGODB_NAMESPACE" \
          "$container_name" --stdin --quiet -- /bin/sh -c "$_script" ||
          ret="$?"
      elif [ "$_file" = "-" ] && [ "$_fdir" = "" ]; then
        kubectl exec -n "$MONGODB_NAMESPACE" "$container_name" --quiet -- \
          /bin/sh -c "$_script" ||
          ret="$?"
      else
        echo "Wrong _file ('$_file') or _fdir ('$_fdir'), aborting call !!!"
        exit 1
      fi
    fi
    kubectl delete -n "$MONGODB_NAMESPACE" "pod/$container_name" --now 1>&2
  fi
}

mongo_command_list() {
  cat <<EOF
cli USER: Run mongosh or the mongo client using 'root' or 'kyso' as USER
dump FILE: Dump the kyso database to the passed FILE
image: Print the mongo cli image URI
restore FILE: Restore the kyso database from the passed FILE
settings-count: Get count of docs on the 'KysoSettings' collection [no ARG]
settings-export FILE: Export the 'KysoSettings' collection to a CSV FILE
settings-merge FILE: Merge the CSV FILE data into the 'KysoSettings' collection
shell: Execute an interactive shell on the mongo client container [no ARG]
version-get: Get the current mongodb compatibility version [no ARG]
version-set VERSION: Set the mongondb compatibility version (i.e. 5.0)
EOF
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
