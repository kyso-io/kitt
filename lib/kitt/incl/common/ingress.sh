#!/bin/sh
# ----
# File:        common/ingress.sh
# Description: Auxiliary functions to work with ingress definitions
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022-2023 Kyso Inc.
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

# Create or update plain auth_file, if the file exists but the user does not it
# is updated, not replaced.
auth_file_update() {
  _auth_user="$1"
  _auth_file="$2"
  if [ "$#" -ne "2" ]; then
    echo "Wrong number of arguments, expected 2:"
    echo "- 'auth_user' & 'auth_file'"
    exit 1
  fi
  if [ ! -f "$_auth_file" ]; then
    _auth_pass="$(openssl rand -base64 12 | sed -e 's%+%-%g;s%/%_%g')"
    : >"$_auth_file"
    chmod 0600 "$_auth_file"
    echo "$_auth_user:$_auth_pass" | stdout_to_file "$_auth_file"
  else
    _auth_lines="$(file_to_stdout "$_auth_file")"
    if [ -z "$(echo "$_auth_lines" | sed -ne "/^$_auth_user:/p")" ]; then
      _auth_pass="$(openssl rand -base64 12 | sed -e 's%+%-%g;s%/%_%g')"
      (
        echo "$_auth_lines"
        echo "$_auth_user:$_auth_pass"
      ) |
        stdout_to_file "$_auth_file"
    fi
  fi
}

create_htpasswd_secret_yaml() {
  _ns="$1"
  _auth_name="$2"
  _auth_file="$3"
  _auth_yaml="$4"
  if [ "$#" -ne "4" ]; then
    echo "Wrong number of arguments, expected 4:"
    echo "- 'ns', 'auth_name', 'auth_file' & 'auth_yaml'"
    exit 1
  fi
  _bcrypt="$_auth_file.bcrypt"
  # Do nothing if _auth_name is empty
  [ "$_auth_name" ] || return 0
  # Do nothing if _auth_file does not exist
  [ -f "$_auth_file" ] || return 0
  : >"$_bcrypt"
  chmod 0600 "$_bcrypt"
  while read -r _auth_user _auth_pass; do
    htpasswd -bBn "$_auth_user" "$_auth_pass" >>"$_bcrypt"
  done <<EOF
$(file_to_stdout "$_auth_file" | sed -ne "s%:% %p")
EOF
  : >"$_auth_yaml"
  chmod 0600 "$_auth_yaml"
  kubectl create secret generic "$_auth_name" -n "$_ns" --dry-run=client \
    -o yaml --from-file=auth="$_bcrypt" | stdout_to_file "$_auth_yaml"
  rm -f "$_bcrypt"
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
    "$_tmpl" | stdout_to_file "$_yaml"
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
      _cert_name="$_hostname-cert"
      _cert_crt="$CERTIFICATES_DIR/$_hostname.crt"
      _cert_key="$CERTIFICATES_DIR/$_hostname${SOPS_EXT}.key"
      _cert_yaml="$_kubectl_dir/tls-$_hostname${SOPS_EXT}.yaml"
      create_tls_cert_yaml "$_ns" "$_cert_name" "$_cert_crt" "$_cert_key" \
        "$_cert_yaml"
    done
  fi
}

replace_app_ingress_values() {
  _app="$1"
  _yaml="$2"
  if [ "$#" -ne "2" ]; then
    echo "Wrong number of arguments, expected 2:"
    echo "- 'app', 'yaml'"
    exit 1
  fi
  _yaml_orig_plain="$_yaml.orig.plain"
  _yaml_annotations="$_yaml.annotations"
  _yaml_hostname_rule="$_yaml.hostname_rule"
  _yaml_hostname_tls="$_yaml.hostname_tls"
  # Copy a plain version the original _yaml file to use it for the sed commands
  # and the final replacements.
  file_to_stdout "$_yaml" >"$_yaml_orig_plain"
  # Generate ingress hostname rules
  # ----
  # NOTE
  # ----
  #
  #   We've added a ' *' pattern to the comments because sops can add whitespace
  #   on the lines when decoding ... probably it is not marked as a bug because
  #   the YAML is still valid, but for my tricks it is kind of painful ... ;)
  # ----
  _cmnd="/^ *# BEG: HOSTNAME_RULE/,/^ *# END: HOSTNAME_RULE/"
  _cmnd="$_cmnd{/^ *# \(BEG\|END\): HOSTNAME_RULE/d;p;}"
  hostname_rule="$(sed -n -e "$_cmnd" "$_yaml_orig_plain")"
  for hostname in $DEPLOYMENT_HOSTNAMES; do
    echo "$hostname_rule" | sed -e "s%__HOSTNAME__%$hostname%g"
  done >"$_yaml_hostname_rule"
  # Annotations
  # The file path is under the helm dir or the kubectl dir, check helm first
  _yaml_fname="${_yaml#"$DEPLOY_HELM_DIR/"}"
  # If the filename is equal to the original _yaml it must be on the kubectl
  # dir
  if [ "$_yaml" = "$_yaml_fname" ]; then
    _yaml_fname="${_yaml#"$DEPLOY_KUBECTL_DIR/"}"
  fi
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
        -e "/annotations:/{n;s%^\([[:space:]]\+\).*$%\1$_annotation%p}" \
        "$_yaml_orig_plain" >>"$_yaml_annotations"
    done
  else
    : >"$_yaml_annotations"
  fi
  # Generate ingress TLS rules
  if is_selected "$DEPLOYMENT_INGRESS_USE_TLS_CERTS"; then
    _cmnd="/^ *# BEG: HOSTNAME_TLS/,/^ *# END: HOSTNAME_TLS/"
    _cmnd="$_cmnd{/^ *# \(BEG\|END\): HOSTNAME_TLS/d;p;}"
    hostname_tls="$(sed -n -e "$_cmnd" "$_yaml_orig_plain")"
    for hostname in $DEPLOYMENT_HOSTNAMES; do
      echo "$hostname_tls" | sed -e "s%__HOSTNAME__%$hostname%g"
    done >"$_yaml_hostname_tls"
    rm_tls_sed=""
  else
    rm_tls_sed="/^ *# BEG: TLS_RULES/,/^ *# END: TLS_RULES/d"
  fi
  # Generate ingress YAML file
  sed \
    -e "/annotations:/r $_yaml_annotations" \
    -e "/^ *# END: HOSTNAME_RULE/r $_yaml_hostname_rule" \
    -e "/^ *# END: HOSTNAME_TLS/r $_yaml_hostname_tls" \
    -e "/^ *# BEG: HOSTNAME_RULE/,/^ *# END: HOSTNAME_RULE/d" \
    -e "/^ *# BEG: HOSTNAME_TLS/,/^ *# END: HOSTNAME_TLS/d" \
    -e "s%__FORCE_SSL_REDIRECT__%$CLUSTER_FORCE_SSL_REDIRECT%g" \
    -e "$rm_tls_sed" \
    "$_yaml_orig_plain" | stdout_to_file "$_yaml"
  # Remove temporary files
  rm -f "$_yaml_annotations" "$_yaml_hostname_rule" "$_yaml_hostname_tls" \
    "$_yaml_orig_plain"
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
  # Generate ingress YAML file
  sed \
    -e "$basic_auth_sed" \
    -e "s%__APP__%$_app%" \
    -e "s%__NAMESPACE__%$_ns%" \
    -e "s%__MAX_BODY_SIZE__%$_max_body_size%g" \
    "$_tmpl" | stdout_to_file "$_yaml"
  # And replace app ingress values
  replace_app_ingress_values "$_app" "$_yaml"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
