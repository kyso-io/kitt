#!/bin/sh
# ----
# File:        tools.sh
# Description: Functions to check and install tools used by us
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022 Sergio Talens-Oliag <sto@kyso.io>
# ----

set -e

# Set variable to avoid loading this file more than once
# shellcheck disable=SC2034
INCL_TOOLS_SH="1"

# ---------
# Variables
# ---------

# System dirs
BASH_COMPLETION="/etc/bash_completion.d"
ZSH_COMPLETIONS="/usr/share/zsh/vendor-completions"

# --------
# Includes
# --------

if [ -d "$INCL_DIR" ]; then
  # shellcheck source=./common.sh
  [ "$INCL_COMMON_SH" = "1" ] || . "$INCL_DIR/common.sh"
else
  echo "This file has to be sourced using kitt.sh"
  exit 1
fi

# ---------
# Functions
# ---------

# Auxiliary function to check if we want to install an app
tools_install_app() {
  _app="$1"
  _type="$(type "$_app" 2>/dev/null)" && found="true" || found="false"
  if [ "$found" = "true" ]; then
    echo "$_app found ($_type)."
    MSG="Re-install in /usr/local/bin?"
    OPT="false"
  else
    echo "$_app could not be found."
    MSG="Install it in /usr/local/bin?"
    OPT="true"
  fi
  read_bool "$MSG" "$OPT"
  is_selected "${READ_VALUE}" && return 0 || return 1
}

tools_install_pkg() {
  _app="$1"
  _type="$(type "$_app" 2>/dev/null)" && found="true" || found="false"
  if [ "$found" = "true" ]; then
    echo "$_app found ($_type)."
    MSG="Re-install using apt?"
    OPT="false"
  else
    echo "$_app could not be found."
    MSG="Install it using apt?"
    OPT="true"
  fi
  read_bool "$MSG" "$OPT"
  is_selected "${READ_VALUE}" && return 0 || return 1
}

tools_check_aws() {
  if tools_install_app "aws"; then
    orig_pwd="$(pwd)"
    tmp_dir="$(mktemp -d)"
    cd "$tmp_dir"
    curl -fsSL -o "./awscliv2.zip" \
      "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
    unzip ./awscliv2.zip
    sudo ./aws/install
    cd "$orig_pwd"
    rm -rf "$tmp_dir"
    aws --version
  fi
}

tools_check_docker() {
  if tools_install_app "docker"; then
    tmp_dir="$(mktemp -d)"
    curl -fsSL -o "$tmp_dir/install-docker.sh" "https://get.docker.com"
    sh "$tmp_dir/install-docker.sh"
    rm -rf "$tmp_dir"
    sudo usermod -aG docker "$(id -un)"
    docker --version
  fi
}

tools_check_eksctl() {
  if tools_install_app "eksctl"; then
    orig_pwd="$(pwd)"
    tmp_dir="$(mktemp -d)"
    cd "$tmp_dir"
    tgz="eksctl_$(uname -s)_amd64.tar.gz"
    curl -fsSL -o "./$tgz" \
      "https://github.com/weaveworks/eksctl/releases/latest/download/$tgz"
    tar xzf "./$tgz"
    sudo install eksctl /usr/local/bin
    cd "$orig_pwd"
    rm -rf "$tmp_dir"
    eksctl version
    if [ -d "$BASH_COMPLETION" ]; then
      sudo sh -c "eksctl completion bash > $BASH_COMPLETION/eksctl"
    fi
    if [ -d "$ZSH_COMPLETIONS" ]; then
      sudo sh -c "eksctl completion zsh > $ZSH_COMPLETIONS/_eksctl"
    fi
  fi
}

tools_check_helm() {
  if tools_install_app "helm"; then
    tmp_dir="$(mktemp -d)"
    curl -fsSL -o "$tmp_dir/get_helm.sh" \
      https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
    bash "$tmp_dir/get_helm.sh"
    rm -rf "$tmp_dir"
    helm version
    if [ -d "$BASH_COMPLETION" ]; then
      sudo sh -c "helm completion bash > $BASH_COMPLETION/helm"
    fi
    if [ -d "$ZSH_COMPLETIONS" ]; then
      sudo sh -c "helm completion zsh > $ZSH_COMPLETIONS/_helm"
    fi
  fi
}

tools_check_inotifywait() {
  if tools_install_pkg "inotifywait"; then
    sudo apt update && sudo apt install inotify-tools && sudo apt clean
  fi
}

tools_check_jq() {
  if tools_install_app "jq"; then
    repo_path="stedolan/jq"
    case "$(uname)" in
      Linux) os_arch="linux64" ;;
      Darwin) os_arch="osx-amd64" ;;
    esac
    download_url="$(
      curl -sL "https://api.github.com/repos/$repo_path/releases/latest" |
      sed -n "s/^.*\"browser_download_url\": \"\(.*.$os_arch\)\"/\1/p"
    )"
    [ -d "/usr/local/bin" ] || sudo mkdir "/usr/local/bin"
    tmp_dir="$(mktemp -d)"
    curl -sL "$download_url" -o "$tmp_dir/jq"
    sudo install "$tmp_dir/jq" /usr/local/bin/
    rm -rf "$tmp_dir"
    jq --version
  fi
}

tools_check_json2file() {
  if tools_install_pkg "json2file-go"; then
    sudo apt update && sudo apt install json2file-go && sudo apt clean
  fi
}

tools_check_jq() {
  if tools_install_app "jq"; then
    repo_path="stedolan/jq"
    case "$(uname)" in
      Linux) os_arch="linux64" ;;
      Darwin) os_arch="osx-amd64" ;;
    esac
    download_url="$(
      curl -sL "https://api.github.com/repos/$repo_path/releases/latest" |
      sed -n "s/^.*\"browser_download_url\": \"\(.*.$os_arch\)\"/\1/p"
    )"
    [ -d "/usr/local/bin" ] || sudo mkdir "/usr/local/bin"
    tmp_dir="$(mktemp -d)"
    curl -sL "$download_url" -o "$tmp_dir/jq"
    sudo install "$tmp_dir/jq" /usr/local/bin/
    rm -rf "$tmp_dir"
    jq --version
  fi
}


tools_check_k3d() {
  if tools_install_app "k3d"; then
    [ -d /usr/local/bin ] || sudo mkdir /usr/local/bin
    curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh |
      bash
    k3d version
    if [ -d "$BASH_COMPLETION" ]; then
      sudo sh -c "k3d completion bash > $BASH_COMPLETION/k3d"
    fi
    if [ -d "$ZSH_COMPLETIONS" ]; then
      sudo sh -c "k3d completion zsh > $ZSH_COMPLETIONS/_k3d"
    fi
  fi
}

tools_check_kubectl() {
  if tools_install_app "kubectl"; then
    base_url="https://storage.googleapis.com/kubernetes-release/release"
    release="$(curl -s $base_url/stable.txt)"
    os="$(uname | tr '[:upper:]' '[:lower:]')"
    arch="amd64"
    [ -d /usr/local/bin ] || sudo mkdir /usr/local/bin
    tmp_dir="$(mktemp -d)"
    curl -fsSL -o "$tmp_dir/kubectl" "$base_url/$release/bin/$os/$arch/kubectl"
    sudo install "$tmp_dir/kubectl" /usr/local/bin/
    rm -rf "$tmp_dir"
    kubectl version --client
    if [ -d "$BASH_COMPLETION" ]; then
      sudo sh -c "kubectl completion bash > $BASH_COMPLETION/kubectl"
    fi
    if [ -d "$ZSH_COMPLETIONS" ]; then
      sudo sh -c "kubectl completion zsh > $ZSH_COMPLETIONS/_kubectl"
    fi
  fi
}

tools_check_kubectx() {
  if tools_install_app "kubectx"; then
    repo_path="ahmetb/kubectx"
    os="$(uname | tr '[:upper:]' '[:lower:]')"
    arch="$(uname -m)"
    ext="${os}_${arch}.tar.gz"
    download_urls="$(
      curl -sL "https://api.github.com/repos/$repo_path/releases/latest" |
      sed -n "s/^.*\"browser_download_url\": \"\(.*.$ext\)\"/\1/p"
    )"
    _compl_url="https://raw.githubusercontent.com/$repo_path/master/completion"
    [ -d "/usr/local/bin" ] || sudo mkdir "/usr/local/bin"
    orig_pwd="$(pwd)"
    tmp_dir="$(mktemp -d)"
    cd "$tmp_dir"
    for app in kubectx kubens; do
      download_url="$(echo "$download_urls" | grep "${app}_v")"
      curl -sL "$download_url" -o "$app.tar.gz"
      tar xzf "$app.tar.gz" "$app"
      sudo install "./$app" /usr/local/bin/
      if [ -d "$BASH_COMPLETION" ]; then
        curl -sL "$_compl_url/$app.bash" |
          sudo sh -c "cat >"$BASH_COMPLETION/$app""
      fi
      if [ -d "$ZSH_COMPLETIONS" ]; then
        curl -sL "$_compl_url/_$app.zsh" |
          sudo sh -c "cat >"$ZSH_COMPLETIONS/_$app.zsh""
      fi
    done
    cd "$orig_pwd"
    rm -rf "$tmp_dir"
    kubectx --version
  fi
}

tools_check_mkcert() {
  if tools_install_pkg "mkcert"; then
    sudo apt update && sudo apt install mkcert && sudo apt clean
  fi
}

tools_check_sops() {
  if tools_install_app "sops"; then
    repo_path="mozilla/sops"
    os="$(uname | tr '[:upper:]' '[:lower:]')"
    arch="$(uname -m)"
    ext="${os}_${arch}.tar.gz"
    download_url="$(
      curl -sL "https://api.github.com/repos/$repo_path/releases/latest" |
      sed -n "s/^.*\"browser_download_url\": \"\(.*.$os\)\"/\1/p"
    )"
    [ -d "/usr/local/bin" ] || sudo mkdir "/usr/local/bin"
    orig_pwd="$(pwd)"
    tmp_dir="$(mktemp -d)"
    cd "$tmp_dir"
    curl -sL "$download_url" -o "$tmp_dir/sops"
    sudo install ./sops /usr/local/bin/
    cd "$orig_pwd"
    rm -rf "$tmp_dir"
    sops --version
  fi
}

tools_check_tsp() {
  if tools_install_pkg "tsp"; then
    sudo apt update && sudo apt install task-spooler && sudo apt clean
  fi
}

tools_check_uuid() {
  if tools_install_pkg "uuid"; then
    sudo apt update && sudo apt install uuid && sudo apt clean
  fi
}

tools_check_velero() {
  if tools_install_app "velero"; then
    repo_path="vmware-tanzu/velero"
    os="$(uname | tr '[:upper:]' '[:lower:]')"
    arch="$(uname -m)"
    case "$arch" in
    x86_64) arch="amd64" ;;
    esac
    ext="$os-$arch.tar.gz"
    download_url="$(
      curl -sL "https://api.github.com/repos/$repo_path/releases/latest" |
        sed -n "s/^.*\"browser_download_url\": \"\(.*.$ext\)\"/\1/p"
    )"
    [ -d "/usr/local/bin" ] || sudo mkdir "/usr/local/bin"
    orig_pwd="$(pwd)"
    tmp_dir="$(mktemp -d)"
    cd "$tmp_dir"
    curl -sL "$download_url" -o "./velero-$os-$arch.tgz"
    tar xf "$tmp_dir/velero-$os-$arch.tgz"
    sudo install ./velero-*-"$os"-"$arch"/velero /usr/local/bin/
    cd "$orig_pwd"
    rm -rf "$tmp_dir"
    velero version --client-only
    if [ -d "$BASH_COMPLETION" ]; then
      sudo sh -c "velero completion bash > $BASH_COMPLETION/velero"
    fi
    if [ -d "$ZSH_COMPLETIONS" ]; then
      sudo sh -c "velero completion zsh > $ZSH_COMPLETIONS/_velero"
    fi
  fi
}

tools_check() {
  for _app in "$@"; do
    case "$_app" in
    aws) tools_check_aws ;;
    docker) tools_check_docker ;;
    eksctl) tools_check_eksctl ;;
    helm) tools_check_helm ;;
    inotifywait) tools_check_inotifywait ;;
    jq) tools_check_jq ;;
    json2file|json2file-go) tools_check_json2file ;;
    k3d) tools_check_k3d ;;
    kubectl) tools_check_kubectl ;;
    kubectx) tools_check_kubectx ;;
    mkcert) tools_check_mkcert ;;
    sops) tools_check_sops ;;
    tsp) tools_check_tsp ;;
    uuid) tools_check_uuid ;;
    velero) tools_check_velero ;;
    *) echo "Unknown application '$_app'" ;;
    esac
  done
}

tools_apps_list() {
  echo "aws docker eksctl helm jq k3d kubectl kubectx sops velero"
}

tools_pkgs_list() {
  echo "inotifywait json2file mkcert tsp uuid"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
