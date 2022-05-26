#!/bin/sh
# ----
# File:        common/ingress.sh
# Description: Auxiliary functions to work with ingress definitions
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_COMMON_INGRESS_SH="1"

# --------
# Includes
# --------

if [ -d "$INCL_DIR" ]; then
  # shellcheck source=./kubectl.sh
  [ "$INCL_COMMON_KUBECTL_SH" = "1" ] || . "$INCL_DIR/common/kubectl.sh"
fi

# ---------
# Functions
# ---------

create_htpasswd_secret_yaml() {
  _ns="$1"
  _auth_name="$2"
  _auth_user="$3"
  _auth_file="$4"
  _auth_yaml="$5"
  if [ "$#" -ne "5" ]; then
    echo "Wrong number of arguments, expected 5:"
    echo "- 'ns', 'auth_name', 'auth_user', 'auth_file' & 'auth_yaml'"
    exit 1
  fi
  _apr1="$_auth_file.apr1"
  # Do nothing if _auth_name is empty
  [ "$_auth_name" ] || return 0
  # Create plain version if not present
  if [ -f "$_auth_file" ]; then
    _pass="$(file_to_stdout "$_auth_file" | sed -ne "s%^$_auth_user:%%p")"
  else
    _pass=""
  fi
  if [ -z "$_pass" ]; then
    _pass="$(openssl rand -base64 12 | sed -e 's%+%-%g;s%/%_%g')"
    : >"$_auth_file"
    chmod 0600 "$_auth_file"
    echo "$_auth_user:$_pass" | stdout_to_file "$_auth_file"
  fi
  : >"$_apr1"
  chmod 0600 "$_apr1"
  printf "%s:%s\n" "$_auth_user" "$(openssl passwd -apr1 "$_pass")" >"$_apr1"
  : >"$_auth_yaml"
  chmod 0600 "$_auth_yaml"
  kubectl create secret generic "$_auth_name" -n "$_ns" --dry-run=client \
    -o yaml --from-file=auth="$_apr1" | stdout_to_file "$_auth_yaml"
  rm -f "$_apr1"
}

create_addon_ingress_yaml() {
  _ns="$1"
  _tmpl="$2"
  _yaml="$3"
  _auth_name="$4"
  _release="$5"
  if [ "$#" -ne "5" ]; then
    echo "Wrong number of arguments, expected 5:"
    echo "- 'ns', 'tmpl', 'yaml', 'auth_name' & 'release'"
    exit 1
  fi
  if [ "$_auth_name" ]; then
    basic_auth_sed="s%__AUTH_SECRET__%$_auth_name%"
  else
    basic_auth_sed="/nginx.ingress.kubernetes.io\/auth-/d"
  fi
  sed \
    -e "$basic_auth_sed" \
    -e "s%__NAMESPACE__%$_ns%" \
    -e "s%__CLUSTER_DOMAIN__%$CLUSTER_DOMAIN%" \
    -e "s%__RELEASE__%$_release%" \
    "$_tmpl" >"$_yaml"
}

create_app_cert_yamls() {
  if [ "$#" -ne "2" ]; then
    echo "Wrong number of arguments, expected 2:"
    echo "- 'ns' & 'kubectl_dir'"
    exit 1
  fi
  if is_selected "$DEPLOYMENT_INGRESS_TLS_CERTS"; then
    _ns="$1"
    _kubectl_dir="$2"
    if [ ! -d "$_kubectl_dir" ]; then
      echo "The kubectl_dir '$_kubectl_dir' does not exist!"
      exit 1
    fi
    for _hostname in $DEPLOYMENT_HOSTNAMES; do
      _cert_name="$_hostname"
      _cert_crt="$DEPLOY_TLS_DIR/$_hostname.crt"
      _cert_key="$DEPLOY_TLS_DIR/$_hostname${SOPS_EXT}.key"
      _cert_yaml="$_kubectl_dir/tls-$_hostname${SOPS_EXT}.yaml"
      create_tls_cert_yaml "$_ns" "$_cert_name" "$_cert_crt" "$_cert_key" \
        "$_cert_yaml"
    done
  fi
}

create_app_ingress_yaml() {
  _ns="$1"
  _app="$2"
  _tmpl="$3"
  _yaml="$4"
  _auth_name="$5"
  _max_body_size="$6"
  if [ "$#" -ne "6" ]; then
    echo "Wrong number of arguments, expected 6:"
    echo "- 'ns', 'app', 'tmpl', 'yaml', 'auth_name' & 'max_body_size'"
    exit 1
  fi
  if [ "$_auth_name" ]; then
    basic_auth_sed="s%__AUTH_SECRET__%$_auth_name%"
  else
    basic_auth_sed="/nginx.ingress.kubernetes.io\/auth-/d"
  fi
  _yaml_annotations="$_yaml.annotations"
  _yaml_hostname_rule="$_yaml.hostname_rule"
  _yaml_hostname_tls="$_yaml.hostname_tls"
  # Generate ingress hostname rules
  _cmnd="/^# BEG: HOSTNAME_RULE/,/^# END: HOSTNAME_RULE/"
  _cmnd="$_cmnd{/^# \(BEG\|END\): HOSTNAME_RULE/d;p;}"
  hostname_rule="$(sed -n -e "$_cmnd" "$_tmpl")"
  for hostname in $DEPLOYMENT_HOSTNAMES; do
    echo "$hostname_rule" | sed -e "s%__HOSTNAME__%$hostname%g"
  done >"$_yaml_hostname_rule"
  # Annotations
  _yaml_fname="${_yaml#"$DEPLOY_KUBECTL_DIR/"}"
  _annotations_file="$DEPLOY_ANNOTATIONS_DIR/${_yaml_fname}"
  # Backwards compatibility for JnJ, try the filename without extension
  if [ ! -f "$_annotations_file" ]; then
    _annotations_file="$DEPLOY_ANNOTATIONS_DIR/${_yaml_fname%%.*}"
  fi
  if [ -f "$_annotations_file" ]; then
    : >"$_yaml_annotations"
    # Add quotes if missing when using '=' ... not really sure if needed
    sed -ne "/^#/!{s%=\([^'\"].*[^'\"]\)$%=\"\1\"%;s%=%: %;p;}" \
      "$_annotations_file" | while read -r _annotation; do
      sed -n \
        -e "/annotations/{n;s%^\([[:space:]]\+\).*$%\1$_annotation%p}" \
        "$_tmpl" >>"$_yaml_annotations"
    done
  else
    : >"$_yaml_annotations"
  fi
  # Generate ingress TLS rules & certs
  if is_selected "$DEPLOYMENT_INGRESS_TLS_CERTS"; then
    _cmnd="/^# BEG: HOSTNAME_TLS/,/^# END: HOSTNAME_TLS/"
    _cmnd="$_cmnd{/^# \(BEG\|END\): HOSTNAME_TLS/d;p;}"
    hostname_tls="$(sed -n -e "$_cmnd" "$_tmpl")"
    for hostname in $DEPLOYMENT_HOSTNAMES; do
      echo "$hostname_tls" | sed -e "s%__HOSTNAME__%$hostname%g"
    done >"$_yaml_hostname_tls"
  fi
  # Generate ingress YAML file
  sed \
    -e "/annotations:/r $_yaml_annotations" \
    -e "/^# END: HOSTNAME_RULE/r $_yaml_hostname_rule" \
    -e "/^# END: HOSTNAME_TLS/r $_yaml_hostname_tls" \
    -e "/^# BEG: HOSTNAME_RULE/,/^# END: HOSTNAME_RULE/d" \
    -e "/^# BEG: HOSTNAME_TLS/,/^# END: HOSTNAME_TLS/d" \
    "$_tmpl" |
    sed \
      -e "$basic_auth_sed" \
      -e "s%__APP__%$_app%" \
      -e "s%__NAMESPACE__%$_ns%" \
      -e "s%__MAX_BODY_SIZE__%$_max_body_size%g" \
      -e "s%__FORCE_SSL_REDIRECT__%$CLUSTER_FORCE_SSL_REDIRECT%g" \
      >"$_yaml"
  rm -f "$_yaml_annotations" "$_yaml_hostname_rule" "$_yaml_hostname_tls"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
