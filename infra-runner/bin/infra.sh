#!/usr/bin/env bash

# Capture modified and deleted files

set -euo pipefail

function usage()
{
    echo "usage ${0} [--debug]" >&2
    echo "This script syncs the workflow commit and calls the action.sh script" >&2
}

function args() {
  debug=""
  op=""

  arg_list=( "$@" )
  arg_count=${#arg_list[@]}
  arg_index=0
  while (( arg_index < arg_count )); do
    case "${arg_list[${arg_index}]}" in
          "--debug") debug="--debug";set -x;;
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
}

args "$@"

if [ -n "$debug" ]; then
    env | sort
    pwd
fi

git clone --depth 1 --branch $tf_version ${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}.git ${GITHUB_SHA} >/dev/null

export WORK_DIR=$PWD

pushd ${GITHUB_SHA}

[ "${GITHUB_REF_NAME}" == main ] && plan="" || plan="--plan-only"

${GITHUB_SHA}/infra-runner/bin/action.sh $debug $plan

popd
