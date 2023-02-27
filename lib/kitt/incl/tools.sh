#!/bin/sh
# ----
# File:        tools.sh
# Description: Functions to check and install tools used by us
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022-2023 Sergio Talens-Oliag <sto@kyso.io>
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

# Versions
AWS_IAM_AUTHENTICATOR_VERSION="0.5.9"
# GET_HELM_URL ... set it to get the latest helm version
# - https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
HELM_VERSION="3.11.1"
KUBECTL_VERSION="1.24.10"

# --------
# Includes
# --------

if [ -d "$INCL_DIR" ]; then
  # shellcheck source=./common/io.sh
  [ "$INCL_COMMON_IO_SH" = "1" ] || . "$INCL_DIR/common/io.sh"
else
  echo "This file has to be sourced using kitt.sh"
  exit 1
fi

# ---------
# Functions
# ---------

# Auxiliary function to check if an application is installed
tools_app_installed() {
  _app="$1"
  type "$_app" >/dev/null 2>&1 || return 1
}

tools_check_apps_installed() {
  _missing=""
  for _app in "$@"; do
    tools_app_installed "$_app" || _missing="$_missing $_app"
  done
  if [ "$_missing" ]; then
    echo "The following apps could not be found:"
    for _app in $_missing; do
      echo "- $_app"
    done
    exit 1
  fi
}

# Auxiliary function to check if we want to install an app
tools_install_app() {
  _app="$1"
  if tools_app_installed "$_app"; then
    echo "$_app found ($(type "$_app"))."
    MSG="Re-install in /usr/local/bin?"
    OPT="false"
  else
    echo "$_app could not be found."
    MSG="Install it in /usr/local/bin?"
    OPT="true"
  fi
  if [ "$KITT_NONINTERACTIVE" = "true" ]; then
    READ_VALUE="$OPT"
  else
    read_bool "$MSG" "$OPT"
  fi
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

tools_check_age_keygen() {
  if tools_install_app "age-keygen"; then
    repo_path="FiloSottile/age"
    case "$(uname)" in
    Linux) os_arch="linux-amd64" ;;
    Darwin) os_arch="darwin-amd64" ;;
    esac
    download_url="$(
      curl -sL "https://api.github.com/repos/$repo_path/releases/latest" |
        sed -n "s/^.*\"browser_download_url\": \"\(.*.$os_arch.tar.gz\)\"/\1/p"
    )"
    [ -d "/usr/local/bin" ] || sudo mkdir "/usr/local/bin"
    tmp_dir="$(mktemp -d)"
    curl -sL "$download_url" -o "$tmp_dir/age.tar.gz"
    tar xzf "$tmp_dir/age.tar.gz" -C "$tmp_dir" "age/age-keygen"
    sudo install "$tmp_dir/age/age-keygen" /usr/local/bin/
    cd "$orig_pwd"
    rm -rf "$tmp_dir"
    age-keygen --version
  fi
}

tools_check_aws() {
  if tools_install_app "aws"; then
    orig_pwd="$(pwd)"
    tmp_dir="$(mktemp -d)"
    cd "$tmp_dir"
    curl -fsSL -o "./awscliv2.zip" \
      "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
    unzip ./awscliv2.zip
    if [ -d "/usr/local/aws-cli/v2/current" ]; then
      sudo ./aws/install --update
    else
      sudo ./aws/install
    fi
    cd "$orig_pwd"
    rm -rf "$tmp_dir"
    aws --version
  fi
}

tools_check_aws_iam_authenticator() {
  app="aws-iam-authenticator"
  if tools_install_app "$app"; then
    tmp_dir="$(mktemp -d)"
      os="$(uname -s | tr '[:upper:]' '[:lower:]')"
      case "$(uname -m)" in
      x86_64) arch="amd64" ;;
      esac
      ver="$AWS_IAM_AUTHENTICATOR_VERSION"
      url="https://github.com/kubernetes-sigs/aws-iam-authenticator/releases"
      url="$url/download/v${ver}/aws-iam-authenticator_${ver}_linux_amd64"
      curl -fsSL -o "$tmp_dir/$app" "$url"
      sudo install "$tmp_dir/$app" /usr/local/bin
    rm -rf "$tmp_dir"
    $app version
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
    if [ "$GET_HELM" ]; then
      curl -fsSL -o "$tmp_dir/get_helm.sh" "$GET_HELM"
      bash "$tmp_dir/get_helm.sh"
    else
      os="$(uname -s | tr '[:upper:]' '[:lower:]')"
      case "$(uname -m)" in
      x86_64) arch="amd64" ;;
      esac
      url="https://get.helm.sh/helm-v$HELM_VERSION-$os-$arch.tar.gz"
      curl -fsSL -o "$tmp_dir/helm.tar.gz" "$url"
      tar xzf "$tmp_dir/helm.tar.gz" -C "$tmp_dir" "$os-$arch/helm"
      sudo install "$tmp_dir/$os-$arch/helm" /usr/local/bin
    fi
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

tools_check_krew() {
  app="krew"
  if tools_install_app "$app"; then
    repo_path="kubernetes-sigs/krew"
    case "$(uname)" in
    Linux) os_arch="linux_amd64" ;;
    Darwin) os_arch="darwin_amd64" ;;
    esac
    download_url="$(
      curl -sL "https://api.github.com/repos/$repo_path/releases/latest" |
        sed -n "s/^.*\"browser_download_url\": \"\(.*-$os_arch.tar.gz\)\"/\1/p"
    )"
    [ -d "/usr/local/bin" ] || sudo mkdir "/usr/local/bin"
    orig_pwd="$(pwd)"
    tmp_dir="$(mktemp -d)"
    cd "$tmp_dir"
    curl -sL "$download_url" -o "$tmp_dir/$app.tar.gz"
    tar xzf "$app.tar.gz" "./$app-$os_arch"
    sudo install "./$app-$os_arch" "/usr/local/bin/$app"
    sudo ln -sf "./$app" "/usr/local/bin/kubectl-$app"
    cd "$orig_pwd"
    rm -rf "$tmp_dir"
    krew version
  fi
}

tools_check_kubectl() {
  if tools_install_app "kubectl"; then
    os="$(uname | tr '[:upper:]' '[:lower:]')"
    case "$(uname -m)" in
    x86_64) arch="amd64" ;;
    esac
    url="https://dl.k8s.io/release/v$KUBECTL_VERSION/bin/$os/$arch/kubectl"
    [ -d /usr/local/bin ] || sudo mkdir /usr/local/bin
    tmp_dir="$(mktemp -d)"
    curl -fsSL -o "$tmp_dir/kubectl" "$url"
    sudo install "$tmp_dir/kubectl" /usr/local/bin/
    rm -rf "$tmp_dir"
    kubectl version --client --output=yaml
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
    os="$(uname -s | tr '[:upper:]' '[:lower:]')"
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
      sudo ln -sf "./$app" "/usr/local/bin/kubectl-${app#kube}"
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

tools_check_kubelogin() {
  if tools_install_app "kubelogin"; then
    orig_pwd="$(pwd)"
    tmp_dir="$(mktemp -d)"
    cd "$tmp_dir"
    os="$(uname -s | tr '[:upper:]' '[:lower:]')"
    arch="amd64"
    zip="kubelogin-${os}-${arch}.zip"
    curl -fsSL -o "./$zip" \
      "https://github.com/Azure/kubelogin/releases/latest/download/$zip"
    unzip "./$zip"
    sudo install "./bin/${os}_${arch}/kubelogin" /usr/local/bin
    cd "$orig_pwd"
    rm -rf "$tmp_dir"
    kubelogin --version
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
    os="$(uname -s | tr '[:upper:]' '[:lower:]')"
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

tools_check_stern() {
  if tools_install_app "stern"; then
    repo_path="stern/stern"
    case "$(uname)" in
    Linux) os_arch="linux_amd64" ;;
    esac
    download_url="$(
      curl -sL "https://api.github.com/repos/$repo_path/releases/latest" |
        sed -n "s/^.*\"browser_download_url\": \"\(.*.$os_arch.tar.gz\)\"/\1/p"
    )"
    [ -d "/usr/local/bin" ] || sudo mkdir "/usr/local/bin"
    tmp_dir="$(mktemp -d)"
    curl -sL "$download_url" -o "$tmp_dir/stern.tar.gz"
    tar xzf "$tmp_dir/stern.tar.gz" -C "$tmp_dir" "stern"
    sudo install "$tmp_dir/stern" /usr/local/bin/
    cd "$orig_pwd"
    rm -rf "$tmp_dir"
    stern --version
    if [ -d "$BASH_COMPLETION" ]; then
      sudo sh -c "stern --completion bash > $BASH_COMPLETION/stern"
    fi
    if [ -d "$ZSH_COMPLETIONS" ]; then
      sudo sh -c "stern --completion zsh > $ZSH_COMPLETIONS/_stern"
    fi
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
    os="$(uname -s | tr '[:upper:]' '[:lower:]')"
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

tools_check_yq() {
  if tools_install_app "yq"; then
    repo_path="mikefarah/yq"
    case "$(uname)" in
    Linux) os_arch="linux_amd64" ;;
    Darwin) os_arch="darwin_amd64" ;;
    esac
    download_url="$(
      curl -sL "https://api.github.com/repos/$repo_path/releases/latest" |
        sed -n "s/^.*\"browser_download_url\": \"\(.*.$os_arch\)\"/\1/p"
    )"
    [ -d "/usr/local/bin" ] || sudo mkdir "/usr/local/bin"
    tmp_dir="$(mktemp -d)"
    curl -sL "$download_url" -o "$tmp_dir/yq"
    sudo install "$tmp_dir/yq" /usr/local/bin/
    rm -rf "$tmp_dir"
    yq --version
    if [ -d "$BASH_COMPLETION" ]; then
      sudo sh -c "yq shell-completion bash > $BASH_COMPLETION/yq"
    fi
    if [ -d "$ZSH_COMPLETIONS" ]; then
      sudo sh -c "yq shell-completion zsh > $ZSH_COMPLETIONS/_yq"
    fi
  fi
}

tools_check() {
  for _app in "$@"; do
    case "$_app" in
    age-keygen) tools_check_age_keygen ;;
    aws) tools_check_aws ;;
    aws-iam-authenticator) tools_check_aws_iam_authenticator ;;
    docker) tools_check_docker ;;
    eksctl) tools_check_eksctl ;;
    helm) tools_check_helm ;;
    inotifywait) tools_check_inotifywait ;;
    jq) tools_check_jq ;;
    json2file | json2file-go) tools_check_json2file ;;
    k3d) tools_check_k3d ;;
    krew) tools_check_krew ;;
    kubectl) tools_check_kubectl ;;
    kubectx) tools_check_kubectx ;;
    kubelogin) tools_check_kubelogin ;;
    mkcert) tools_check_mkcert ;;
    sops) tools_check_sops ;;
    stern) tools_check_stern ;;
    tsp) tools_check_tsp ;;
    uuid) tools_check_uuid ;;
    velero) tools_check_velero ;;
    yq) tools_check_yq ;;
    *) echo "Unknown application '$_app'" ;;
    esac
  done
}

tools_apps_list() {
  tools="age-keygen aws aws-iam-authenticator docker eksctl helm jq k3d krew"
  tools="$tools kubectl kubectx kubelogin sops velero"
  # Don't add stern and yq yet, not used by the scripts
  # tools="$tools stern yq"
  echo "$tools"
}

tools_pkgs_list() {
  echo "inotifywait json2file mkcert tsp uuid"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
