#!/usr/bin/env bash

# Utility for terraform plan and apply

set -euo pipefail

function usage()
{
    echo "usage ${0} [--debug] [--plan-only] [--destroy] [--no-lock] [--root-dir <root directory>] <template name>[ <template name>]" >&2
    echo "This script will apply a terraform template" >&2
    echo "Specify <template name> of cleanup-resources and/or cluster to apply desired templates" >&2
}

function args() {
  apply="yes"
  destroy=""
  lock=""
  root_dir="${BASE_DIR:-}"
  debug=""

  arg_list=( "$@" )
  arg_count=${#arg_list[@]}
  arg_index=0
  while (( arg_index < arg_count )); do
    case "${arg_list[${arg_index}]}" in
          "--debug") debug="--debug";set -x;;
          "--plan-only") unset apply;;
          "--destroy") destroy="-destroy";;
          "--root-dir") (( arg_index+=1 ));root_dir=${arg_list[${arg_index}]};;
          "--no-lock") lock="-lock=false";;
               "-h") usage; exit;;
           "--help") usage; exit;;
               "-?") usage; exit;;
        *) if [ "${arg_list[${arg_index}]:0:2}" == "--" ];then
              echo "invalid argument: ${arg_list[${arg_index}]}" >&2
              usage; exit 1
           fi;
           break;;
    esac
    (( arg_index+=1 ))
  done

  templates="${arg_list[@]:${arg_index}}"
  if [ -z "${templates}" ]; then
    echo "No templates specified" >&2
    usage; exit 1
  fi

}

args "$@"

export state_bucket=medx-terraform-state
export lock_table=medx-tfstate-lock

for template in $templates
do
  if [ ! -d $template ]; then
    echo "Template $template does not exist" >&2
    exit 1
  fi
  
  echo "planning: $template"

  export GITLAB_TOKEN="$(kubectl get secret -n flux-system  tf-gitlab-token -o json | jq -r '.data.gitlab_token' | base64 -d)"
  cp $root_dir/clusters/infra/$CLUSTER_NAME/${template}.tfvars ${template}/${template}.tfvars

  export TEMPLATE_NAME=$template
  cat ../resources/templates/backend.tf | envsubst > ${template}/backend.tf

  pushd ${template}
  echo "tfvars file..."
  cat ${template}.tfvars
  echo "backend.tf file..."
  cat backend.tf
  set +e
  terraform init $lock 2>/tmp/state-$$ 1>&2
  result=$?
  set -e
  if [ $result -ne 0 ]; then
    set +e
    grep 'use "terraform init -reconfigure' /tmp/state-$$ 2>&1 >/dev/null
    result=$?
    set -e
    if [ $result -eq 0 ]; then
      terraform init $lock -reconfigure  2>/tmp/state-$$ 1>&2
    else
      echo "Error initialising terraform state" >&2
      cat /tmp/state-$$ >&2
      exit 1
    fi
  fi
  cat /tmp/state-$$
  terraform  validate

  terraform $lock plan -var-file=${template}.tfvars $destroy -out $template.tfplan

  if [ -n "${apply:-}" ]; then
    if [ -n "${destroy:-}" ]; then
      terraform $lock destroy -auto-approve -var-file=${template}.tfvars
    else   
      terraform $lock apply -auto-approve $template.tfplan
    fi
  fi
  popd
done






