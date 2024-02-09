#!/usr/bin/env bash

# Run Terrafrom plan

set -euo pipefail

function usage()
{
    echo "usage ${0} [--debug] " >&2
    echo "This script will run terraform plan" >&2
}

function args() {
  debug=""

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

infra-runner/bin/action.sh $debug --plan-only
