#!/usr/bin/env bash

# Utility for generatring the files for a new cluster
# Version: 1.0
# Author: Paul Carlton (mailto:paul.carlton414@gmail.com)

set -euo pipefail

function usage()
{
    echo "usage ${0} [--debug] --cluster-name <cluster name> [ --multi-step --tf-version <tag, commit or branch> --region <region> --account <aws account id>]" >&2
    echo "This script will create files in clusters/management/infra sub folder for a new cluster" >&2
}

function args() {
  export CLUSTER_NAME=""
  export REGION="ca-central-1"
  export ACCOUNT_ID="493949468944"
  export TF_VERSION=""
  steps=""

  arg_list=( "$@" )
  arg_count=${#arg_list[@]}
  arg_index=0
  while (( arg_index < arg_count )); do
    case "${arg_list[${arg_index}]}" in
          "--debug") set -x;;
          "--cluster-name") (( arg_index+=1 ));CLUSTER_NAME=${arg_list[${arg_index}]};;
          "--tf-version") (( arg_index+=1 ));TF_VERSION=${arg_list[${arg_index}]};;
          "--multi-step") steps=1;;
          "--region") (( arg_index+=1 ));REGION=${arg_list[${arg_index}]};;
          "--account") (( arg_index+=1 ));ACCOUNT_ID=${arg_list[${arg_index}]};;
               "-h") usage; exit;;
           "--help") usage; exit;;
               "-?") usage; exit;;
        *) if [ "${arg_list[${arg_index}]:0:2}" == "--" ];then
              echo "invalid argument: ${arg_list[${arg_index}]}" >&2
              usage; exit
           fi;
           break;;
    esac
    (( arg_index+=1 ))
  done

  if [ -z "${CLUSTER_NAME}" ]; then
    echo "No cluster name specified" >&2
    usage; exit
  fi

}

args "$@"

export SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
export BASE_DIR=$(git rev-parse --show-toplevel)

pushd $BASE_DIR >/dev/null

mkdir -p clusters/management/infra/${CLUSTER_NAME}

cp  infra-runner/resources/templates/tf-version.sh  clusters/management/infra/${CLUSTER_NAME}
if [ -n "$TF_VERSION" ]; then
  echo "export tf_version=$TF_VERSION" > clusters/management/infra/${CLUSTER_NAME}/tf-version.sh
fi

if [ -n "$steps" ]; then
  cp  infra-runner/resources/templates/multi-step.txt  clusters/management/infra/${CLUSTER_NAME}
  if [ -e clusters/management/infra/${CLUSTER_NAME}/cluster-core.tfvars ]; then
    echo "clusters/management/infra/${CLUSTER_NAME}/cluster-core.tfvars already exists, not updating"
  else
    cat infra-runner/resources/templates/cluster-core.tfvars | envsubst > clusters/management/infra/${CLUSTER_NAME}/cluster-core.tfvars
    cat infra-runner/resources/templates/cluster-config.tfvars | envsubst > clusters/management/infra/${CLUSTER_NAME}/cluster-config.tfvars
  fi
else
  if [ -e clusters/management/infra/${CLUSTER_NAME}/cluster.tfvars ]; then
    echo "clusters/management/infra/${CLUSTER_NAME}/cluster.tfvars already exists, not updating"
  else
    cat infra-runner/resources/templates/cluster.tfvars | envsubst > clusters/management/infra/${CLUSTER_NAME}/cluster.tfvars
  fi
fi
