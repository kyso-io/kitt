#!/bin/sh
# ----
# File:        j2f/webhook.sh
# Description: Functions to process json files with data from gitlab web hooks
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022-2023 Kyso Inc.
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_J2F_WEBHOOK_SH="1"

# ---------
# Variables
# ---------

# CMND_DSC="webhook: process json files with messages from gitlab"

export DEFAULT_J2F_MAIL_PREFIX="[GITLAB-WEBHOOK] "
export DEFAULT_J2F_EXEC_COMMAND="true"
export DEFAULT_J2F_MAIL_ERRFILE="false"
export DEFAULT_J2F_MAIL_LOGFILE="false"
export DEFAULT_J2F_SYSADMIN_EMAIL=""

# Fixed values

# Query to get variables from gitlab json file
J2F_ENV_VARS_QUERY="$(
  printf "%s" \
    '(.commit | @sh "gl_url=\(.url);gl_ci_name=\(.name);' \
    'gl_ci_email=\(.email);")' \
    ',(.object_attributes | @sh "gl_ref=\(.ref);gl_sha=\(.sha);' \
    'gl_source=\(.source);gl_status=\(.status);gl_tag=\(.tag);")' \
    ',(@sh "gl_object_kind=\(.object_kind);")' \
    ',(@sh "gl_project_name=\(.project.name);")' \
    ',(@sh "gl_web_url=\(.project.web_url);")' \
    ',(.user | @sh "gl_name=\(.name);gl_email=\(.email);")'
)"
export J2F_ENV_VARS_QUERY

# --------
# Includes
# --------

if [ -d "$INCL_DIR" ]; then
  # shellcheck source=../common.sh
  [ "$INCL_COMMON_SH" = "1" ] || . "$INCL_DIR/common.sh"
else
  echo "This file has to be sourced using kitt.sh"
  exit 1
fi

# ---------
# Functions
# ---------

j2f_webhook_log() {
  echo "$(date -R) $*" >>"$J2F_WEBHOOK_LOGFILE_PATH"
}

j2f_webhook_export_variables() {
  # Check if we need to run the function
  [ -z "$__j2f_webhook_export_variables" ] || return 0
  j2f_common_export_variables
  # Directories
  export J2F_SLACK_DIR="$J2F_DIR/slack"
  export J2F_WEBHOOK_DIR="$J2F_DIR/webhook"
  export J2F_WEBHOOK_ACCEPTED="$J2F_WEBHOOK_DIR/accepted"
  export J2F_WEBHOOK_DEPLOYED="$J2F_WEBHOOK_DIR/deployed"
  export J2F_WEBHOOK_REJECTED="$J2F_WEBHOOK_DIR/rejected"
  export J2F_WEBHOOK_TROUBLED="$J2F_WEBHOOK_DIR/troubled"
  export J2F_WEBHOOK_LOG_DIR="$J2F_WEBHOOK_DIR/log"
  # Labels
  export J2F_MAIL_PREFIX="${J2F_MAIL_PREFIX:-$DEFAULT_J2F_MAIL_PREFIX}"
  export J2F_EXEC_COMMAND="${J2F_EXEC_COMMAND:-$DEFAULT_J2F_EXEC_COMMAND}"
  export J2F_MAIL_ERRFILE="${J2F_MAIL_ERRFILE:-$DEFAULT_J2F_MAIL_ERRFILE}"
  export J2F_MAIL_LOGFILE="${J2F_MAIL_LOGFILE:-$DEFAULT_J2F_MAIL_LOGFILE}"
  export J2F_SYSADMIN_EMAIL="${J2F_SYSADMIN_EMAIL:-$DEFAULT_J2F_SYSADMIN_EMAIL}"
  # Files
  export J2F_SLACK_CHANNEL_FILE="$J2F_SLACK_DIR/channel.txt"
  export J2F_SLACK_TOKEN_FILE="$J2F_SLACK_DIR/token${SOPS_EXT}.txt"
  # Derived values
  TODAY="$(date +%Y%m%d)"
  OUTPUT_BASENAME="$(date +%Y%m%d-%H%M%S.%N)"
  export J2F_WEBHOOK_LOGFILE_PATH="$J2F_WEBHOOK_LOG_DIR/$OUTPUT_BASENAME.log"
  export J2F_WEBHOOK_ACCEPTED_JSON="$J2F_WEBHOOK_ACCEPTED/$OUTPUT_BASENAME.json"
  export J2F_WEBHOOK_ACCEPTED_LOGF="$J2F_WEBHOOK_ACCEPTED/$OUTPUT_BASENAME.log"
  export J2F_WEBHOOK_REJECTED_TODAY="$J2F_WEBHOOK_REJECTED/$TODAY"
  J2F_WEBHOOK_REJECTED_JSON="$J2F_WEBHOOK_REJECTED_TODAY/$OUTPUT_BASENAME.json"
  export J2F_WEBHOOK_REJECTED_JSON
  J2F_WEBHOOK_REJECTED_LOGF="$J2F_WEBHOOK_REJECTED_TODAY/$OUTPUT_BASENAME.log"
  export J2F_WEBHOOK_REJECTED_LOGF
  export J2F_WEBHOOK_DEPLOYED_TODAY="$J2F_WEBHOOK_DEPLOYED/$TODAY"
  J2F_WEBHOOK_DEPLOYED_JSON="$J2F_WEBHOOK_DEPLOYED_TODAY/$OUTPUT_BASENAME.json"
  export J2F_WEBHOOK_DEPLOYED_JSON
  J2F_WEBHOOK_DEPLOYED_LOGF="$J2F_WEBHOOK_DEPLOYED_TODAY/$OUTPUT_BASENAME.log"
  export J2F_WEBHOOK_DEPLOYED_LOGF
  export J2F_WEBHOOK_TROUBLED_TODAY="$J2F_WEBHOOK_TROUBLED/$TODAY"
  J2F_WEBHOOK_TROUBLED_JSON="$J2F_WEBHOOK_TROUBLED_TODAY/$OUTPUT_BASENAME.json"
  export J2F_WEBHOOK_TROUBLED_JSON
  J2F_WEBHOOK_TROUBLED_LOGF="$J2F_WEBHOOK_TROUBLED_TODAY/$OUTPUT_BASENAME.log"
  export J2F_WEBHOOK_TROUBLED_LOGF
  if [ -f "$J2F_SLACK_CHANNEL_FILE" ]; then
    J2F_SLACK_CHANNEL="$(head -1 "$J2F_SLACK_CHANNEL_FILE")"
  else
    J2F_SLACK_CHANNEL=""
  fi
  export J2F_SLACK_CHANNEL
  if [ -f "$J2F_SLACK_TOKEN_FILE" ]; then
    J2F_SLACK_TOKEN="$(file_to_stdout "$J2F_SLACK_TOKEN_FILE" | head -1)"
  else
    J2F_SLACK_TOKEN=""
  fi
  export J2F_SLACK_TOKEN
  # set variable to avoid running the function twice
  __j2f_webhook_export_variables="1"
}

j2f_webhook_check_directories() {
  for _d in "$J2F_DIR" "$J2F_SLACK_DIR" "$J2F_WEBHOOK_DIR" \
    "$J2F_WEBHOOK_ACCEPTED" "$J2F_WEBHOOK_DEPLOYED" "$J2F_WEBHOOK_REJECTED" \
    "$J2F_WEBHOOK_TROUBLED" "$J2F_WEBHOOK_LOG_DIR"; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

j2f_webhook_clean_directories() {
  # Try to remove empty dirs
  for _d in "$J2F_WEBHOOK_ACCEPTED" "$J2F_WEBHOOK_DEPLOYED" \
    "$J2F_WEBHOOK_REJECTED" "$J2F_WEBHOOK_TROUBLED" "$J2F_WEBHOOK_LOG_DIR" \
    "$J2F_SLACK_DIR" "$J2F_WEBHOOK_DIR" "$J2F_DIR"; do
    if [ -d "$_d" ]; then
      rmdir "$_d" 2>/dev/null || true
    fi
  done
}

j2f_webhook_read_variables() {
  read_value "Mail Prefix" "$J2F_MAIL_PREFIX"
  J2F_MAIL_PREFIX=${READ_VALUE}
  read_bool "Execute command" "$J2F_EXEC_COMMAND"
  J2F_EXEC_COMMAND=${READ_VALUE}
  read_bool "Send errorfile via mail" "$J2F_MAIL_ERRFILE"
  J2F_MAIL_ERRFILE=${READ_VALUE}
  read_bool "Send logfile via mail" "$J2F_MAIL_LOGFILE"
  J2F_MAIL_LOGFILE=${READ_VALUE}
  read_value "Sysadmin email" "$J2F_SYSADMIN_EMAIL"
  J2F_SYSADMIN_EMAIL=${READ_VALUE}
  if [ -f "$J2F_SLACK_CHANNEL_FILE" ]; then
    _slack_channel="$(cat "$J2F_SLACK_CHANNEL_FILE")"
    read_bool "Slack channel is '$_slack_channel', update it?" "false"
  else
    _slack_channel=""
    echo "Missing slack channel"
    READ_VALUE="true"
  fi
  j2f_webhook_check_directories
  if is_selected "$READ_VALUE"; then
    read_value "Slack channel" "$_slack_channel"
    _slack_channel=${READ_VALUE}
    echo "$_slack_channel" >"$J2F_SLACK_CHANNEL_FILE"
    echo "Slack channel value saved to file '$J2F_SLACK_CHANNEL_FILE'"
  fi
  if [ -f "$J2F_SLACK_TOKEN_FILE" ]; then
    _slack_token="$(file_to_stdout "$J2F_SLACK_TOKEN_FILE")"
    read_bool "Slack token is '$_slack_token', update it?" "false"
  else
    _slack_token=""
    echo "Missing slack token"
    READ_VALUE="true"
  fi
  if is_selected "$READ_VALUE"; then
    read_value "Slack token" "$_slack_token"
    _slack_token=${READ_VALUE}
    echo "$_slack_token" | stdout_to_file "$J2F_SLACK_TOKEN_FILE"
    echo "Slack token value saved to file '$J2F_SLACK_TOKEN_FILE'"
  fi
}

j2f_webhook_print_variables() {
  cat <<EOF
MAIL_PREFIX=$J2F_MAIL_PREFIX
EXEC_COMMAND=$J2F_EXEC_COMMAND
MAIL_ERRFILE=$J2F_MAIL_ERRFILE
MAIL_LOGFILE=$J2F_MAIL_LOGFILE
SYSADMIN_EMAIL=$J2F_SYSADMIN_EMAIL
EOF
}

j2f_webhook_accept() {
  j2f_webhook_log "Accepted: $*"
  mv "$J2F_WEBHOOK_JSON_INPUT_FILE" "$J2F_WEBHOOK_ACCEPTED_JSON"
  mv "$J2F_WEBHOOK_LOGFILE_PATH" "$J2F_WEBHOOK_ACCEPTED_LOGF"
  J2F_WEBHOOK_LOGFILE_PATH="$J2F_WEBHOOK_ACCEPTED_LOGF"
}

j2f_webhook_reject() {
  [ -d "$J2F_WEBHOOK_REJECTED_TODAY" ] || mkdir "$J2F_WEBHOOK_REJECTED_TODAY"
  j2f_webhook_log "Rejected: $*"
  if [ -f "$J2F_WEBHOOK_JSON_INPUT_FILE" ]; then
    mv "$J2F_WEBHOOK_JSON_INPUT_FILE" "$J2F_WEBHOOK_REJECTED_JSON"
  fi
  mv "$J2F_WEBHOOK_LOGFILE_PATH" "$J2F_WEBHOOK_REJECTED_LOGF"
  exit 0
}

j2f_webhook_deployed() {
  [ -d "$J2F_WEBHOOK_DEPLOYED_TODAY" ] || mkdir "$J2F_WEBHOOK_DEPLOYED_TODAY"
  j2f_webhook_log "Deployed: $*"
  mv "$J2F_WEBHOOK_ACCEPTED_JSON" "$J2F_WEBHOOK_DEPLOYED_JSON"
  mv "$J2F_WEBHOOK_ACCEPTED_LOGF" "$J2F_WEBHOOK_DEPLOYED_LOGF"
  J2F_WEBHOOK_LOGFILE_PATH="$J2F_WEBHOOK_DEPLOYED_LOGF"
}

j2f_webhook_troubled() {
  [ -d "$J2F_WEBHOOK_TROUBLED_TODAY" ] || mkdir "$J2F_WEBHOOK_TROUBLED_TODAY"
  j2f_webhook_log "Troubled: $*"
  mv "$J2F_WEBHOOK_ACCEPTED_JSON" "$J2F_WEBHOOK_TROUBLED_JSON"
  mv "$J2F_WEBHOOK_ACCEPTED_LOGF" "$J2F_WEBHOOK_TROUBLED_LOGF"
  J2F_WEBHOOK_LOGFILE_PATH="$J2F_WEBHOOK_TROUBLED_LOGF"
}

j2f_webhook_print_mailto() {
  _addr="$1"
  # shellcheck disable=SC2154
  if [ -z "${gl_email##*@*}" ]; then
    _user_email="\"$gl_name <$gl_email>\""
  elif [ -z "${gl_ci_email##*@*}" ]; then
    _user_email="\"$gl_ci_name <$gl_ci_email>\""
  fi
  if [ "$_addr" ] && [ "$_user_email" ]; then
    echo "$_addr,$_user_email"
  elif [ "$_user_email" ]; then
    echo "$_user_email"
  elif [ "$_addr" ]; then
    echo "$_addr"
  fi
}

j2f_webhook_command() {
  j2f_webhook_export_variables
  export J2F_WEBHOOK_JSON_INPUT_FILE="$1"
  if [ ! -f "$J2F_WEBHOOK_JSON_INPUT_FILE" ]; then
    j2f_webhook_reject "Input arg '$1' is not a file, aborting"
  fi
  j2f_webhook_log "Processing file '$J2F_WEBHOOK_JSON_INPUT_FILE'"
  eval "$(jq -r "$J2F_ENV_VARS_QUERY" "$J2F_WEBHOOK_JSON_INPUT_FILE")"
  # shellcheck disable=SC2154
  if [ "$gl_object_kind" != 'pipeline' ]; then
    j2f_webhook_reject "object_kind = '$gl_object_kind', not 'pipeline'"
  fi
  # shellcheck disable=SC2154
  if [ "$gl_status" != 'success' ]; then
    j2f_webhook_reject "status = '$gl_status'"
  fi
  # shellcheck disable=SC2154
  if [ "$gl_source" != 'push' ] && [ "$gl_source" != 'web' ]; then
    j2f_webhook_reject "pipeline source = '$gl_source', not 'push' or 'web'"
  fi
  # shellcheck disable=SC2154
  project_path="${gl_web_url#"$J2F_GITLAB_URL"/}"
  case "$project_path" in
  "kyso-io/kyso-api")
    app="kyso-api"
    img_var="KYSO_API_IMAGE"
    ;;
  "kyso-io/kyso-front")
    app="kyso-front"
    img_var="KYSO_FRONT_IMAGE"
    ;;
  "kyso-io/kyso-indexer")
    app="kyso-scs"
    img_var="KYSO_INDEXER_IMAGE"
    ;;
  "kyso-io/consumers/activity-feed-consumer")
    app="activity-feed-consumer"
    img_var="ACTIVITY_FEED_CONSUMER_IMAGE"
    ;;
  "kyso-io/consumers/notification-consumer")
    app="notification-consumer"
    img_var="NOTIFICATION_CONSUMER_IMAGE"
    ;;
  "kyso-io/consumers/slack-notifications-consumer")
    app="slack-notifications-consumer"
    img_var="SLACK_NOTIFICATIONS_CONSUMER_IMAGE"
    ;;
  "kyso-io/consumers/teams-notification-consumer")
    app="teams-notification-consumer"
    img_var="TEAMS_NOTIFICATION_CONSUMER_IMAGE"
    ;;
  *) j2f_webhook_reject "web_url = '$gl_web_url', ignored" ;;
  esac
  # shellcheck disable=SC2154
  case "$gl_tag" in
  false)
    case "$gl_ref" in
    "develop") deployments="dev" ;;
    "jnj") deployments="jnj" ;;
    "main" | "master") deployments="staging" ;;
    *) j2f_webhook_reject "branch = '$gl_ref', ignored" ;;
    esac
    img_url="$J2F_REGISTRY_URI/$project_path/$gl_ref:$gl_sha"
    ref_type="branch"
    ;;
  true)
    case "$gl_ref" in
    beta-*) deployments="beta" ;;
    demo-*) deployments="demo" ;;
    prod-*) deployments="prod" ;;
    saas-*) deployments="saas" ;;
    test-*) deployments="test" ;;
    *) j2f_webhook_reject "tag = '$gl_ref', ignored" ;;
    esac
    img_url="$J2F_REGISTRY_URI/$project_path:$gl_ref"
    ref_type="tag"
    ;;
  esac
  local_deployments="$("$APP_REAL_PATH" clust lsd)"
  valid_deployments=""
  for _dep in $deployments; do
    for _ldep in $local_deployments; do
      if [ "$_dep" = "$_ldep" ]; then
        valid_deployments="$valid_deployments $_dep"
        break
      fi
    done
  done
  if [ "$valid_deployments" ]; then
    deployments="${valid_deployments# }"
  else
    j2f_webhook_reject "no '$deployments' deployments found locally, aborting!"
  fi
  # shellcheck disable=SC2154
  cat >>"$J2F_WEBHOOK_LOGFILE_PATH" <<EOF

Deploying image '$img_url'
Built from $ref_type '$gl_ref', commit $gl_url

EOF

  j2f_webhook_accept "updating '$app' on '$deployments'"
  res=0
  for _deploy in $deployments; do
    _cmnd_vars="$img_var='$img_url'"
    _cmnd="$_cmnd_vars $APP_REAL_PATH apps $app install $_deploy"
    _res="0"
    if is_selected "$J2F_EXEC_COMMAND"; then
      # Apply changes
      cat >>"$J2F_WEBHOOK_LOGFILE_PATH" <<EOF

Running command: $_cmnd

EOF
      eval "$_cmnd" >>"$J2F_WEBHOOK_LOGFILE_PATH" 2>&1 || _res="$?"
      echo "" >>"$J2F_WEBHOOK_LOGFILE_PATH"
    else
      j2f_webhook_log 'Command not executed!'
      _res="1"
    fi
    [ "$_res" -eq "0" ] || res="$((res + 1))"
  done
  to_addr="$J2F_WEBHOOK_J2F_SYSADMIN_EMAIL"
  deps="$(echo "$deployments" | sed -e 's/ /, /g')"
  # shellcheck disable=SC2154
  if [ "$res" -eq "0" ]; then
    j2f_webhook_deployed "Command execution succeeded."
    if is_selected "$J2F_MAIL_LOGFILE"; then
      to_addr="$(print_mailto "$to_addr")"
    fi
    if [ "$to_addr" ]; then
      subject="👍 $app deployment on $deps for $ref_type $gl_ref"
      subject="$subject of project $gl_project_name 👍"
      mail -s "${J2F_MAIL_PREFIX}${subject}" "$to_addr" \
        <"$J2F_WEBHOOK_LOGFILE_PATH"
    fi
    if [ "$J2F_SLACK_TOKEN" ] && [ "$J2F_SLACK_CHANNEL" ]; then
      message="👍 *$app* deployment on \`$deps\` for $ref_type \`$gl_ref\`"
      message="$message of project \`$gl_project_name\`"
      if [ "$gl_name" ]; then
        message="$message triggered by $gl_name"
      fi
      message="$message 👍"
      curl -s https://slack.com/api/chat.postMessage \
        -H "Authorization: Bearer $J2F_SLACK_TOKEN" \
        -F channel="$J2F_SLACK_CHANNEL" -F text="$message" >/dev/null
      curl -s https://slack.com/api/files.upload \
        -H "Authorization: Bearer $J2F_SLACK_TOKEN" \
        -F channels="${J2F_SLACK_CHANNEL}" \
        -F title="Deployment log for $ref_type '$gl_ref', commit '$gl_sha'" \
        -F filename="deployment-$ref_type-$gl_ref-$gl_sha.log" \
        -F filetype="text" \
        -F file=@"$J2F_WEBHOOK_LOGFILE_PATH" >/dev/null
    fi
  else
    j2f_webhook_troubled "Command execution failed."
    if is_selected "$J2F_MAIL_ERRFILE"; then
      to_addr="$(print_mailto "$to_addr")"
    fi
    if [ "$to_addr" ]; then
      subject="😱👎 $app deployment on $deps for $ref_type $gl_ref"
      subject="$subject of project $gl_project_name 👎😱"
      mail -s "${J2F_MAIL_PREFIX}${subject}" "$to_addr" \
        <"$J2F_WEBHOOK_LOGFILE_PATH"
    fi
    if [ "$J2F_SLACK_TOKEN" ] && [ "$J2F_SLACK_CHANNEL" ]; then
      message="😱👎 *$app* deployment on \`$deps\` for $ref_type \`$gl_ref\`"
      message="$message of project \`$gl_project_name\` 👎😱"
      if [ "$gl_name" ]; then
        message="$message triggered by $gl_name"
      fi
      message="$message 👎😱"
      curl -s https://slack.com/api/chat.postMessage \
        -H "Authorization: Bearer $J2F_SLACK_TOKEN" \
        -F channel="$J2F_SLACK_CHANNEL" -F text="$message" >/dev/null
      curl -s https://slack.com/api/files.upload \
        -H "Authorization: Bearer $J2F_SLACK_TOKEN" \
        -F channels="${J2F_SLACK_CHANNEL}" \
        -F title="Deployment log for $ref_type '$gl_ref', commit '$gl_sha'" \
        -F filename="deployment-$ref_type-$gl_ref-$gl_sha.log" \
        -F filetype="text" \
        -F file=@"$J2F_WEBHOOK_LOGFILE_PATH" >/dev/null
    fi
  fi
}

j2f_webhook_command_args() {
  echo "JSON_FILE_TO_PROCESS"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
