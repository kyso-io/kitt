#!/bin/sh
# ----
# File:        common/kubectl.sh
# Description: Auxiliary functions to work with kubectl.
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_KUBECTL_SH="1"

# Set the ROLLOUT_STATUS_TIMEOUT to 5 minutes by default
export ROLLOUT_STATUS_TIMEOUT="${ROLLOUT_STATUS_TIMEOUT:-300s}"

# --------
# Includes
# --------

if [ -d "$INCL_DIR" ]; then
  # shellcheck source=./io.sh
  [ "$INCL_COMMON_IO_SH" = "1" ] || . "$INCL_DIR/common/io.sh"
  # shellcheck source=./registry.sh
  [ "$INCL_COMMON_REGISTRY_SH" = "1" ] || . "$INCL_DIR/common/registry.sh"
fi

# Auxiliary function to call kubectl
kubectl_op() {
  if [ "$#" -ne "2" ]; then
    echo "Wrong arguments, expecting kubectl OPERATION and YAML file path"
    exit 1
  fi
  op="$1"
  file="$2"
  ret="0"
  [ -f "$file" ] || return "$ret"
  file_to_stdout "$file" | kubectl "$op" -f - || ret="$?"
  if [ "$op" = "delete" ]; then
    rm -f "$file"
  fi
  return "$ret"
}

# Function to call kubectl apply using a file as input (the namespace must be
# adjusted on the yaml file)
kubectl_apply() {
  if [ "$#" -ne "1" ]; then
    echo "Wrong arguments, expecting YAML file path"
    exit 1
  fi
  kubectl_op "apply" "$1"
}

kubectl_delete() {
  if [ "$#" -ne "1" ]; then
    echo "Wrong arguments, expecting YAML file path"
    exit 1
  fi
  kubectl_op "delete" "$1"
}

create_basic_auth_yaml() {
  if [ "$#" -ne "5" ]; then
    echo "Wrong arguments, expecting NS, NAME, USER and TEXT & YAML file paths"
    exit 1
  fi
  _ns="$1"
  _auth="$2"
  _user="$3"
  _text="$4"
  _apr1="${_text%.text}.apr1"
  _yaml="$5"
  # Create plain version if not present
  if [ -f "$_text" ]; then
    _pass="$(file_to_stdout "$_text" | sed -ne "s/^$_user://p")"
  else
    _pass=""
  fi
  if [ -z "$_pass" ]; then
    _pass="$(openssl rand -base64 12 | sed -e 's%+%-%g;s%/%_%g')"
    : >"$_text"
    chmod 0600 "$_text"
    echo "$_user:$_pass" | stdout_to_file "$_text"
  fi
  : >"$_apr1"
  chmod 0600 "$_apr1"
  printf "%s\n" "$_user:$(openssl passwd -apr1 "$_pass")" >"$_apr1"
  : >"$_yaml"
  chmod 0600 "$_yaml"
  kubectl create secret generic "$_auth" --dry-run=client -o yaml \
    --namespace "$_ns" --from-file=auth="$_apr1" |
    stdout_to_file "$_yaml"
  rm -f "$_apr1"
}

create_tls_cert_yaml() {
  if [ "$#" -ne "5" ]; then
    echo "Wrong arguments, expecting NS, CERT_NAME, CRT, KEY & YAML file path"
    exit 1
  fi
  _ns="$1"
  _cert_name="$2"
  _cert_crt="$3"
  _cert_key="$4"
  _cert_yaml="$5"
  _missing_files=""
  [ -f "$_cert_crt" ] ||  _missing_files="$_missing_files $_cert_crt"
  [ -f "$_cert_key" ] ||  _missing_files="$_missing_files $_cert_key"
  if [ "$_missing_files" ]; then
    cat <<EOF
Can't create TLS secret '$_cert_name', we need the following files:

$(for _mf in $_missing_files; do echo "- '$_mf'"; done)

Generate them with certbot, get them from another CA or use a tool like
'mkcert' (https://github.com/FiloSottile/mkcert) to create self-signed
certificates.

For local development it is a good idea to use certificates for DNS domains
that resolve to the loopback address (127.0.0.1 in IPv4).
EOF
    return 1
  fi
  # Create a secret with the server certificate
  : >"$_cert_yaml"
  chmod 0600 "$_cert_yaml"
  tmp_dir="$(mktemp -d)"
  chmod 0700 "$tmp_dir"
  file_to_stdout "$_cert_key" > "$tmp_dir/tls.key"
  kubectl --dry-run=client -o yaml \
    create secret tls "$_cert_name" \
    --namespace "$_ns" \
    --cert "$_cert_crt" \
    --key "$tmp_dir/tls.key" |
    stdout_to_file "$_cert_yaml"
  rm -rf "$tmp_dir"
}

find_namespace() {
  if [ "$#" -ne "1" ]; then
    echo "Wrong arguments, expecting NAMESPACE"
    exit 1
  fi
  kubectl get ns -o name | grep -q "^namespace/$1$" || return "$?"
}

create_namespace() {
  _ns="$1"
  if [ "$#" -ne "1" ]; then
    echo "Wrong arguments, expecting NAMESPACE"
    exit 1
  fi
  # Create namespace
  find_namespace "$_ns" || kubectl create namespace "$_ns"
  # Adjust the default account to use imagePullSecrets if needed
  if is_selected "$CLUSTER_PULL_SECRETS_IN_NS"; then
    _name="$CLUSTER_PULL_SECRETS_NAME"
    _yaml="$CLUST_NS_KUBECTL_DIR/$_ns-$_name$SOPS_EXT.yaml"
    # Create/update docker config secret
    create_pull_secrets_yaml "$_name" "$_ns" "$_yaml"
    # Add it to the namespace
    kubectl_apply "$_yaml"
    # Patch the default account to use the previous secret to pull images
    _pull_secrets_patch="$(
      printf '{"imagePullSecrets": [{"name": "%s"}]}' "$_name"
    )"
    kubectl patch serviceaccount default -n "$_ns" -p "$_pull_secrets_patch"
  fi
}

delete_namespace() {
  _ns="$1"
  _name="$CLUSTER_PULL_SECRETS_NAME"
  _yaml="$CLUST_NS_KUBECTL_DIR/$_ns-$_name$SOPS_EXT.yaml"
  if [ "$#" -ne "1" ]; then
    echo "Wrong arguments, expecting NAMESPACE"
    exit 1
  fi
  if find_namespace "$_ns"; then
    kubectl delete namespace "$_ns" || true
  fi
  if [ -f "$_yaml" ]; then
    rm -f "$_yaml"
  fi
}

create_pull_secrets_yaml() {
  if [ "$#" -ne "3" ]; then
    echo "Wrong arguments, expecting SECRET_NAME, NAMESPACE & YAML file path"
    exit 1
  fi
  _name="$1"
  _ns="$2"
  _yaml="$3"
  load_registry_conf
  : >"$_yaml"
  chmod 0600 "$_yaml"
  kubectl --dry-run=client -o yaml \
    create secret docker-registry "$_name" \
    --docker-server="$REMOTE_REGISTRY_URL" \
    --docker-username="$REMOTE_REGISTRY_USER" \
    --docker-password="$REMOTE_REGISTRY_PASS" \
    --namespace="$_ns" |
    stdout_to_file "$_yaml"
}

deployment_restart() {
  if [ "$#" -ne "2" ]; then
    echo "Wrong arguments, expecting NAMESPACE & APP name"
    exit 1
  fi
  _ns="$1"
  _app="$2"
  # Call the rollout restart command
  kubectl rollout -n "$_ns" restart deployment "$_app"
  # Wait until the restart succeeds or fails
  kubectl rollout status deployment --timeout="$ROLLOUT_STATUS_TIMEOUT" \
    -n "$_ns" "$_app"
}

deployment_status() {
  ns="$1"
  shift 1
  if find_namespace "$ns"; then
    kubectl get -n "$ns" all,ingress,endpoints,secrets "$@"
  else
    echo "Namespace '$ns' not found!"
  fi
}

deployment_summary() {
  _ns="$1"
  _app="$2"
  _filter="(.status|{replicas})"
  _filter="$_filter,(.status|{availableReplicas})"
  _filter="$_filter,(.status|{readyReplicas})"
  _filter="$_filter,(.spec.template.spec.containers[]|{image})"
  _dinfo="$(
    kubectl get deployment -n "$_ns" -o jsonpath='{.items[0]}' 2>/dev/null |
     jq -c "if .metadata.name==\"$_app\" then . else \"\" end | ($_filter)"
  )" || true
  if [ "$_dinfo" ]; then
    echo "FOUND '$_app' on namespace '$_ns':"
    echo "$_dinfo" | sed -e 's/"//g;s/{//;s/}//;s/:/: /;s/^/- /'
  else
    echo "MISSING '$_app' on namespace '$_ns'!"
  fi
}

deployment_container_images(){
  _ns="$1"
  _app="$2"
  _filter="(.spec.template.spec.containers[]|@text \"\(.name) \(.image)\")"
  _images="$(
    kubectl get deployment -n "$_ns" -o jsonpath='{.items[0]}' 2>/dev/null |
     jq -r "if .metadata.name==\"$_app\" then . else \"\" end | ($_filter)"
  )" || true
  if [ "$_images" ]; then
    echo "$_images"
  fi
}

statefulset_restart() {
  if [ "$#" -ne "2" ]; then
    echo "Wrong arguments, expecting NAMESPACE & APP name"
    exit 1
  fi
  _ns="$1"
  _app="$2"
  # Call the rollout restart command
  kubectl rollout -n "$_ns" restart statefulset "$_app"
  # Wait until the restart succeeds or fails
  kubectl rollout status statefulset --timeout="$ROLLOUT_STATUS_TIMEOUT" \
    -n "$_ns" "$_app"
}

statefulset_status() {
  ns="$1"
  shift 1
  if find_namespace "$ns"; then
    kubectl get -n "$ns" all,ingress,endpoints,secrets "$@"
  else
    echo "Namespace '$ns' not found!"
  fi
}

statefulset_summary() {
  _ns="$1"
  _app="$2"
  _ns_info="$3"
  _filter="(.status|{replicas})"
  _filter="$_filter,(.status|{currentReplicas})"
  _filter="$_filter,(.status|{readyReplicas})"
  _filter="$_filter,(.spec.template.spec.containers[]|{image})"
  _dinfo="$(
    kubectl get statefulset -n "$_ns" -o jsonpath='{.items[0]}' 2>/dev/null |
     jq -c "if .metadata.name==\"$_app\" then . else \"\" end | ($_filter)"
  )" || true
  if [ "$_dinfo" ]; then
    [ "$_ns_info" = "quiet" ] || echo "FOUND '$_app' on namespace '$_ns':"
    echo "$_dinfo" | sed -e 's/"//g;s/{//;s/}//;s/:/: /;s/^/- /'
  else
    [ "$_ns_info" = "quiet" ] || echo "MISSING '$_app' on namespace '$_ns'!"
  fi
}

statefulset_helm_summary() {
  statefulset_summary "$1" "$2" "quiet"
}

statefulset_container_images(){
  _ns="$1"
  _app="$2"
  _filter="(.spec.template.spec.containers[]|@text \"\(.name) \(.image)\")"
  _images="$(
    kubectl get statefulset -n "$_ns" -o jsonpath='{.items[0]}' 2>/dev/null |
     jq -r "if .metadata.name==\"$_app\" then . else \"\" end | ($_filter)"
  )" || true
  if [ "$_images" ]; then
    echo "$_images"
  fi
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
