#!/usr/bin/env bash

# Capture modified and deleted files

set -euo pipefail

function usage()
{
    echo "usage ${0} [--debug] [--plan-only] " >&2
    echo "This script get details of files deleted and modified in order to determine which environments to execute terraform for" >&2
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
          "--plan-only") op="--plan-only";set -x;;
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

# 
GHT="$(kubectl get secret -n github-runner-set github-runner-token -o=jsonpath='{.data.github_token}' | base64 -d)"
echo "GHT: $GHT"

export SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source ${SCRIPT_DIR}/lib.sh

if [ "${GITHUB_REF_NAME}" != main ]; then
    
    GITHUB_PR_NUM="$(echo $GITHUB_REF_NAME | cut -f1 -d/)"

    curl -L -H "Accept: application/vnd.github+json" -H "Authorization: Bearer ${GHT}" -H "X-GitHub-Api-Version: 2022-11-28"  \
         ${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/pulls/${GITHUB_PR_NUM}/files | \
         jq -r '.[] | select ( .status == "removed" ) | .filename' | grep -E "^clusters/management/infra/.*/.*" > $HOME/deleted.txt || \
         echo "no deletions"

    rm -rf $HOME/destroy-list.txt
    for deleted_file in $(cat $HOME/deleted.txt)
    do
        mkdir -p $(dirname $HOME/$deleted_file)
        raw_url="$(curl -L -H "Accept: application/vnd.github+json" -H "Authorization: Bearer ${GHT}" -H "X-GitHub-Api-Version: 2022-11-28"  \
         ${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/pulls/${GITHUB_PR_NUM}/files | \
         jq --arg file_path "$deleted_file" -r '.[] | select (.filename == $file_path ) | .raw_url')"
         
        curl -L -H "Accept: application/vnd.github+json" -H "Authorization: Bearer ${GHT}" -H "X-GitHub-Api-Version: 2022-11-28"  \
         ${raw_url} > $HOME/$deleted_file
    done

    curl -L -H "Accept: application/vnd.github+json" -H "Authorization: Bearer ${GHT}" -H "X-GitHub-Api-Version: 2022-11-28"  \
         ${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/pulls/${GITHUB_PR_NUM}/files | \
         jq -r '.[] | select ( .status == "removed" ) | .filename' | grep -E "^clusters/management/infra/.*/.*" | cut -f4 -d/ | sort -u > $HOME/destroyed.txt || echo ""

    curl -L -H "Accept: application/vnd.github+json" -H "Authorization: Bearer ${GHT}" -H "X-GitHub-Api-Version: 2022-11-28"  \
         ${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/pulls/${GITHUB_PR_NUM}/files | \
         jq -r '.[] | select ( .status == "modified" ) | .filename' | grep -E "^clusters/management/infra/.*/.*" | cut -f4 -d/ | sort -u > $HOME/modified.txt || echo "no modificatons"

else # merge request commit

     GITHUB_PR_NUM="main"

    curl -L -H "Accept: application/vnd.github+json" -H "Authorization: Bearer ${GHT}" -H "X-GitHub-Api-Version: 2022-11-28"  \
         ${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/pulls/${GITHUB_PR_NUM}/files | \
         jq -r '.[] | select ( .status == "removed" ) | .filename' | grep -E "^clusters/management/infra/.*/.*" > $HOME/deleted.txt || \
         echo "no deletions"

    rm -rf $HOME/destroy-list.txt
    for deleted_file in $(cat $HOME/deleted.txt)
    do
        mkdir -p $(dirname $HOME/$deleted_file)
        raw_url="$(curl -L -H "Accept: application/vnd.github+json" -H "Authorization: Bearer ${GHT}" -H "X-GitHub-Api-Version: 2022-11-28"  \
         ${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/pulls/${GITHUB_PR_NUM}/files | \
         jq --arg file_path "$deleted_file" -r '.[] | select (.filename == $file_path ) | .raw_url')"
         
        curl -L -H "Accept: application/vnd.github+json" -H "Authorization: Bearer ${GHT}" -H "X-GitHub-Api-Version: 2022-11-28"  \
         ${raw_url} > $HOME/$deleted_file
    done

    curl -L -H "Accept: application/vnd.github+json" -H "Authorization: Bearer ${GHT}" -H "X-GitHub-Api-Version: 2022-11-28"  \
         ${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/pulls/${GITHUB_PR_NUM}/files | \
         jq -r '.[] | select ( .status == "removed" ) | .filename' | grep -E "^clusters/management/infra/.*/.*" | cut -f4 -d/ | sort -u > $HOME/destroyed.txt || echo ""

    curl -L -H "Accept: application/vnd.github+json" -H "Authorization: Bearer ${GHT}" -H "X-GitHub-Api-Version: 2022-11-28" \
         ${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/pulls/${GITHUB_PR_NUM}/files | \
         jq -r '.[] | select ( .status == "modified" ) | .filename' | grep -E "^clusters/management/infra/.*/.*" | cut -f4 -d/ | sort -u > $HOME/modified.txt || echo "no modificatons"

fi

echo "Deleted infastructure for clusters..."
cat $HOME/destroyed.txt    # Get deleted and modified

echo "Modified infrastructure for clusters.."
cat $HOME/modified.txt

if [ -e  $HOME/modified.txt ]; then
    for CLUSTER_NAME in $(cat $HOME/modified.txt)
    do
        export CLUSTER_NAME
        export tf_version=${CI_MERGE_REQUEST_SOURCE_BRANCH_NAME:-main}
        if [ -e  $BASE_DIR/clusters/management/infra/$CLUSTER_NAME/tf-version.sh ]; then
            source $BASE_DIR/clusters/management/infra/$CLUSTER_NAME/tf-version.sh
        fi
        tf_path="$(get_tf_version $tf_version)"
        pushd $tf_path/terraform > /dev/null
        steps=cluster
        if [ -e $BASE_DIR/clusters/management/infra/$CLUSTER_NAME/multi-step.txt ]; then
            steps="$(cat $BASE_DIR/clusters/management/infra/$CLUSTER_NAME/multi-step.txt)"
        fi
        $SCRIPT_DIR/tf-run.sh $debug $op $steps
        popd
    done
fi

if [ -e  $HOME/destroyed.txt ]; then
    for CLUSTER_NAME in $(cat $HOME/destroyed.txt)
    do
        export CLUSTER_NAME
        export tf_version=${CI_MERGE_REQUEST_SOURCE_BRANCH_NAME:-main}
        if [ -e  $BASE_DIR/clusters/management/infra/$CLUSTER_NAME/tf-version.sh ]; then
            source $BASE_DIR/clusters/management/infra/$CLUSTER_NAME/tf-version.sh
        else
            if [ -e  $HOME/clusters/management/infra/$CLUSTER_NAME/tf-version.sh ]; then
                source $HOME/clusters/management/infra/$CLUSTER_NAME/tf-version.sh
            fi
        fi
        tf_path="$(get_tf_version $tf_version)"
        pushd $tf_path/terraform > /dev/null
        steps=cluster
        if [ -e $HOME/clusters/management/infra/$CLUSTER_NAME/multi-step.txt ]; then
            steps="$(cat $HOME/clusters/management/infra/$CLUSTER_NAME/multi-step.txt | awk '{ for (i=NF; i>1; i--) printf("%s ",$i); print $1; }')"
        fi
        $SCRIPT_DIR/tf-run.sh $debug --root-dir $HOME --destroy $op $steps
        popd
    done
fi
