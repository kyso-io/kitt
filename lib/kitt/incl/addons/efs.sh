#!/bin/sh
# ----
# File:        addons/efs.sh
# Description: Functions to install and remove the efs-csi-driver from a cluster
# Author:      Sergio Talens-Oliag <sto@kyso.io>
# Copyright:   (c) 2022-2023 Kyso Inc.
# ----

set -e

# Set the variable to 1 to avoid including the file more than once
# shellcheck disable=SC2034
INCL_ADDONS_EFS_SH="1"

# ---------
# Variables
# ---------

# CMND_DSC="efs: install or remove the efs-csi-driver on a cluster (eks)"

# Fixed values
export EFS_NAMESPACE="kube-system"
export EFS_HELM_REPO_NAME="aws-efs-csi-driver"
export EFS_HELM_REPO_URL="https://kubernetes-sigs.github.io/aws-efs-csi-driver"
export EFS_HELM_CHART="$EFS_HELM_REPO_NAME/aws-efs-csi-driver"
export EFS_HELM_RELEASE="efs-csi-driver"
export EFS_EKS_FILESYSTEM_NAME_SUFFIX="efs-filesystem"
export EFS_EKS_FILESYSTEM_INGRESS_RULE_SUFFIX="kyso-efs-eks-ingress-rule"
export DEFAULT_EKS_EFS_SG_DESC="EKS EFS Access Security Group"

# --------
# Includes
# --------

if [ -d "$INCL_DIR" ]; then
  # shellcheck source=../common.sh
  [ "$INCL_COMMON_SH" = "1" ] || . "$INCL_DIR/common.sh"
  # shellcheck source=../ctools/eks.sh
  [ "$INCL_CTOOLS_EKS_SH" = "1" ] || . "$INCL_DIR/ctools/eks.sh"
fi

# ---------
# Functions
# ---------

addons_efs_export_variables() {
  [ -z "$__addons_efs_export_variables" ] || return 0
  # Load EKS variables
  ctool_eks_export_variables
  # Directories
  export EFS_TMPL_DIR="$TMPL_DIR/addons/efs"
  export EFS_HELM_DIR="$CLUST_HELM_DIR/efs"
  export EFS_KUBECTL_DIR="$CLUST_KUBECTL_DIR/efs"
  # Templates
  export EFS_HELM_VALUES_TMPL="$EFS_TMPL_DIR/values.yaml"
  # Files
  export EFS_HELM_VALUES_YAML="$EFS_HELM_DIR/values.yaml"
  # Set variable to avoid loading variables twice
  __addons_efs_export_variables="1"
}

addons_efs_check_directories() {
  for _d in "$EFS_HELM_DIR" "$EFS_KUBECTL_DIR"; do
    [ -d "$_d" ] || mkdir "$_d"
  done
}

addons_efs_clean_directories() {
  # Try to remove empty dirs, except if they contain secrets
  for _d in "$EFS_HELM_DIR" "$EFS_KUBECTL_DIR"; do
    if [ -d "$_d" ]; then
      rmdir "$_d" 2>/dev/null || true
    fi
  done
}

addons_efs_check_efs() {
  _file_system_info="$(
    aws efs describe-file-systems \
      --region "$_region" \
      --file-system-id "$CLUSTER_EFS_FILESYSTEMID" \
      --output text 2>/dev/null
  )" || true
  
  if [ "$_file_system_info" ]; then
    echo "EFS filesystem '$_orig_efs_filesystemid' already exists"
  fi
}

# Function from https://docs.aws.amazon.com/eks/latest/userguide/efs-csi.html
addons_efs_createfs() {
  addons_efs_export_variables
  _orig_efs_filesystemid="$CLUSTER_EFS_FILESYSTEMID"
  _cluster="$CLUSTER_NAME"
  _region="$CLUSTER_REGION"
  _sg_name="$_cluster-$EFS_EKS_FILESYSTEM_NAME_SUFFIX"
  _sg_desc="$DEFAULT_EKS_EFS_SG_DESC"
  _efs_name="$_cluster-$EFS_EKS_FILESYSTEM_NAME_SUFFIX"
  _efs_eks_ingress_rule="$_cluster-$EFS_EKS_FILESYSTEM_INGRESS_RULE_SUFFIX"
  # Check if the filesystem already exists
  addons_efs_check_efs
  # Get values
  _private_subnets="$(
    cd "$CLUST_TF_EKS_DIR"; terraform output -json private_subnets | jq '.[]' -r
  )"
  _vpc_id="$(
    aws eks describe-cluster \
      --name "$_cluster" \
      --region "$_region" \
      --query "cluster.resourcesVpcConfig.vpcId" \
      --output text
  )"
  _cidr_range="$(
    aws ec2 describe-vpcs \
      --region "$_region" \
      --vpc-ids "$_vpc_id" \
      --query "Vpcs[].CidrBlock" \
      --output text
  )"
  # Get or create the security group
  _security_group_id=""
  while [ -z "$_security_group_id" ]; do
    _security_group_id="$(
      aws ec2 describe-security-groups \
        --region "$_region" \
        --filters \
          "Name=vpc-id,Values=$_vpc_id" \
          "Name=group-name,Values=$_sg_name" \
        --query "SecurityGroups[*].[GroupId]" \
        --output text
    )"
    # Create security group if missing
    if [ -z "$_security_group_id" ]; then
      echo "Creating security group for EFS"
      _tag_spec="ResourceType=security-group,Tags=[{Key=Name,Value=$_sg_name}]"
      aws ec2 create-security-group \
        --region "$_region" \
        --group-name "$_sg_name" \
        --description "$_sg_desc" \
        --query "SecurityGroups[*].[GroupId]" \
        --vpc-id "$_vpc_id" \
        --tag-specifications "$_tag_spec" \
        --output text >/dev/null
    else
      echo "Found security group for EFS with id '$_security_group_id'"
    fi
  done
  # Get or create ingress rules
  _efs_eks_ingress_rule_id=""
  while [ -z "$_efs_eks_ingress_rule_id" ]; do
    # Allow inbound connections from the eks cluster
    _efs_eks_ingress_rule_id="$(
      aws ec2 describe-security-group-rules \
        --region "$_region" \
        --filter \
          "Name=group-id,Values=$_security_group_id" \
          "Name=tag:Name,Values=$_efs_eks_ingress_rule" \
        --query 'SecurityGroupRules[].SecurityGroupRuleId' \
        --output text
    )"
    if [ -z "$_efs_eks_ingress_rule_id" ]; then
      echo "Creating rule to allow EFS access"
      _tag_spec="ResourceType=security-group-rule"
      _tag_spec="$_tag_spec,Tags=[{Key=Name,Value=$_efs_eks_ingress_rule}]"
      aws ec2 authorize-security-group-ingress \
        --region "$_region" \
        --group-id "$_security_group_id" \
        --protocol tcp \
        --port 2049 \
        --tag-specifications "$_tag_spec" \
        --cidr "$_cidr_range"
    else
      echo "Found rule to allow EFS access with id '$_efs_eks_ingress_rule_id'"
    fi
  done
  # Create fileystem if missing
  _file_system_id=""
  while [ -z "$_file_system_id" ]; do
    _file_system_ids="$(
      aws efs describe-file-systems \
        --region "$_region" \
        --query "FileSystems[*].[FileSystemId]" \
        --output text
    )"
    for _fid in $_file_system_ids; do
      _name="$(
        aws efs list-tags-for-resource \
          --region "$_region" \
          --resource-id "$_fid" |
          jq -r '.Tags[] | select(.Key=="Name") | .Value'
      )"
      if [ "$_name" = "$_efs_name" ]; then
        _file_system_id="$_fid"
        break
      fi
    done
    if [ -z "$_file_system_id" ]; then
      echo "Creating EFS filesystem"
      aws efs create-file-system \
        --region "$_region" \
        --performance-mode generalPurpose \
        --throughput-mode bursting \
        --encrypted \
        --tags "Key=Name,Value=$_efs_name" \
        --query 'FileSystemId' \
        --output text
      # FIXME: Small delay to make sure the filesystem is created
      sleep 10
    else
      echo "Found EFS filesystem with id '$_file_system_id'"
    fi
  done
  export CLUSTER_EFS_FILESYSTEMID="$_file_system_id"
  # Create mount targets on the private subnets
  echo "$_private_subnets" | while read -r _sid; do
    _query="MountTargets[?SubnetId=='$_sid'].{MountTargetId: MountTargetId}"
    _mount_target_id="$(
      aws efs describe-mount-targets \
        --region "$_region" \
        --file-system-id "$_file_system_id" \
        --query "$_query" \
        --output text
    )"
    if [ -z "$_mount_target_id" ]; then
      echo "Creating mount target for subnet '$_sid'"
      aws efs create-mount-target \
        --region "$_region" \
        --file-system-id "$_file_system_id" \
        --subnet-id "$_sid" \
        --security-groups "$_security_group_id" || true
    else
      echo "Found mount target '$_mount_target_id' for subnet '$_sid'"
    fi
  done
  if [ "$_orig_efs_filesystemid" != "$CLUSTER_EFS_FILESYSTEMID" ]; then
    echo "The EFS filesystem '$_file_system_id' is NEW!"
    if [ -f "$CLUSTER_CONFIG" ]; then
      read_bool "Save updated configuration?" "Yes"
    else
      READ_VALUE="Yes"
    fi
    if is_selected "${READ_VALUE}"; then
      ctool_eks_check_directories
      ctool_eks_print_variables | stdout_to_file "$CLUSTER_CONFIG"
    fi
  fi
}

addons_efs_install() {
  addons_efs_export_variables
  _region="$CLUSTER_REGION"
  
  # Abort if there is no EKS_CLUSTER_EFS_FILESYSTEMID
  if [ -z "$CLUSTER_EFS_FILESYSTEMID" ]; then
    cat <<EOF
Can't setup the EFS dynamic provisioner without an EFS File system ID.

Create it with the 'createfs' subcommand and update the cluster configuration.
EOF
    exit 1
  fi
  # Abort if the filesystem can't be found
  if [ -z "$(addons_efs_check_efs)" ]; then
    cat <<EOF
Can't find the EFS file system '$CLUSTER_EFS_FILESYSTEMID'.

Create it with the 'createfs' subcommand and update the cluster configuration.
EOF
    exit 1
  fi
  addons_efs_check_directories
  _addon="efs"
  _ns="$EFS_NAMESPACE"
  _repo_name="$EFS_HELM_REPO_NAME"
  _repo_url="$EFS_HELM_REPO_URL"
  _release="$EFS_HELM_RELEASE"
  _chart="$EFS_HELM_CHART"
  _values_tmpl="$EFS_HELM_VALUES_TMPL"
  _values_yaml="$EFS_HELM_VALUES_YAML"
  header "Installing '$_addon'"
  # Check helm repo
  check_helm_repo "$_repo_name" "$_repo_url"
  # Create values.yaml
  sed \
    -e "s%__CLUSTER_NAME__%$CLUSTER_NAME%g" \
    -e "s%__EFS_FILESYSTEMID__%$CLUSTER_EFS_FILESYSTEMID%" \
    -e "s%__AWS_ACCOUNT_ID__%$_aws_account_id%g" \
    "$_values_tmpl" >"$_values_yaml"
  # Update or install chart
  helm_upgrade "$_ns" "$_values_yaml" "$_release" "$_chart"
  footer
}

addons_efs_remove() {
  addons_efs_export_variables
  _addon="efs"
  _ns="$EFS_NAMESPACE"
  _release="$EFS_HELM_RELEASE"
  _values_yaml="$EFS_HELM_VALUES_YAML"
  helm uninstall -n "$_ns" "$_release" || true
  if [ -f "$_values_yaml" ]; then
    rm -f "$_values_yaml"
  fi
  addons_efs_clean_directories
}

addons_efs_status() {
  addons_efs_export_variables
  _addon="efs"
  _ns="$EFS_NAMESPACE"
  if find_namespace "$_ns"; then
    kubectl get pod -n "$_ns" -l "app.kubernetes.io/name=aws-efs-csi-driver"
  else
    echo "Namespace '$_ns' for '$_addon' not found!"
  fi
}

addons_efs_summary() {
  addons_efs_export_variables
  _addon="efs"
  _ns="$EFS_NAMESPACE"
  _release="$EFS_HELM_RELEASE"
  print_helm_summary "$_ns" "$_addon" "$_release"
}

addons_efs_command() {
  case "$1" in
    createfs) addons_efs_createfs ;;
    install) addons_efs_install ;;
    remove) addons_efs_remove ;;
    status) addons_efs_status ;;
    summary) addons_efs_summary ;;
    *) echo "Unknown efs subcommand '$1'"; exit 1 ;;
  esac
}

addons_efs_command_list() {
  echo "createfs install remove status summary"
}

# ----
# vim: ts=2:sw=2:et:ai:sts=2
