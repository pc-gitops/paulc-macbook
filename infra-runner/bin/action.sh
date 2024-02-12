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

if [ -n "$debug" ]; then
    env | sort
    pwd
    ls -laR .
    ls -laR /home/runner
    exit
fi

source ${SCRIPT_DIR}/bin/lib.sh

exit

if [ "${GITHUB_REF_NAME}" != main ]; then
    
    GITHUB_PR_NUM="$(echo $GITHUB_REF_NAME | cut -f1 -d/)

    curl -L -H "Accept: application/vnd.github+json" -H "Authorization: Bearer ${GITHUB_TOKEN}" -H "X-GitHub-Api-Version: 2022-11-28"  \
         ${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/pulls/${GITHUB_PR_NUM}/files | \
         jq -r '.[] | select ( .status == "removed" ) | .filename' | grep -E "^clusters/management/infra/.*/.*" > $HOME/deleted.txt || \
         echo "no deletions"

    rm -rf $HOME/destroy-list.txt
    for deleted_file in $(cat $HOME/deleted.txt)
    do
        mkdir -p $(dirname $HOME/$deleted_file)
        raw_url="$(curl -L -H "Accept: application/vnd.github+json" -H "Authorization: Bearer ${GITHUB_TOKEN}" -H "X-GitHub-Api-Version: 2022-11-28"  \
         ${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/pulls/${GITHUB_PR_NUM}/files | \
         jq --arg file_path "$deleted_file" -r '.[] | select (.filename == $file_path ) | .raw_url')"
         
        curl -L -H "Accept: application/vnd.github+json" -H "Authorization: Bearer ${GITHUB_TOKEN}" -H "X-GitHub-Api-Version: 2022-11-28"  \
         ${raw_url} | \
         jq --arg file_path "$deleted_file" -r '.[] | select (.filename == $file_path ) | .raw_url')
          | \
        grep -v -E "^@@" |sed s/^-//g > $HOME/$deleted_file
    done

    curl --header "PRIVATE-TOKEN: ${gitlab_token}" https://gitlab.com/api/v4/projects/${CI_PROJECT_ID}/repository/commits/$CI_COMMIT_SHA/diff | \
        jq -r '.[] | select (.deleted_file == true) | .new_path' | grep -E "^clusters/infra/.*/.*" | cut -f3 -d/ | sort -u > $HOME/destroyed.txt || echo ""

    curl --header "PRIVATE-TOKEN: ${gitlab_token}" https://gitlab.com/api/v4/projects/${CI_PROJECT_ID}/repository/commits/$CI_COMMIT_SHA/diff | \
        jq -r '.[] | select (.deleted_file != true) | .new_path' | grep -E "^clusters/infra/.*/.*" | cut -f3 -d/ | sort -u > $HOME/modified.txt || echo "no modificatons"

else # merge request commit

    curl --header "PRIVATE-TOKEN: ${gitlab_token}" https://gitlab.com/api/v4/projects/${CI_PROJECT_ID}/merge_requests/${CI_MERGE_REQUEST_IID}/changes | \
        jq -r '.changes[] | select (.deleted_file == true) | .new_path' | grep -E "^clusters/infra/.*/.*" > $HOME/deleted.txt || echo "no deletions"

    rm -rf $HOME/destroy-list.txt
    for deleted_file in $(cat $HOME/deleted.txt)
    do
        mkdir -p $(dirname $HOME/$deleted_file)
        curl --header "PRIVATE-TOKEN: ${gitlab_token}" https://gitlab.com/api/v4/projects/${CI_PROJECT_ID}/merge_requests/${CI_MERGE_REQUEST_IID}/changes | \
        jq --arg file_path "$deleted_file" -r '.changes[] | select (.new_path == $file_path ) | .diff' | \
        grep -v -E "^@@" |sed s/^-//g > $HOME/$deleted_file
    done

    curl --header "PRIVATE-TOKEN: ${gitlab_token}" https://gitlab.com/api/v4/projects/${CI_PROJECT_ID}/merge_requests/${CI_MERGE_REQUEST_IID}/changes | \
        jq -r '.changes[] | select (.deleted_file == true) | .new_path' | grep -E "^clusters/infra/.*/.*" | cut -f3 -d/ | sort -u > $HOME/destroyed.txt || echo ""

    curl --header "PRIVATE-TOKEN: ${gitlab_token}" https://gitlab.com/api/v4/projects/${CI_PROJECT_ID}/merge_requests/${CI_MERGE_REQUEST_IID}/changes | \
        jq -r '.changes[] | select (.deleted_file != true) | .new_path' | grep -E "^clusters/infra/.*/.*" | cut -f3 -d/ | sort -u > $HOME/modified.txt || echo "no modificatons"

fi

ls -lR $HOME

echo "Deleted infastructure for clusters..."
cat $HOME/destroyed.txt    # Get deleted and modified

echo "Modified infrastructure for clusters.."
cat $HOME/modified.txt

if [ -e  $HOME/modified.txt ]; then
    for CLUSTER_NAME in $(cat $HOME/modified.txt)
    do
        export CLUSTER_NAME
        export tf_version=${CI_MERGE_REQUEST_SOURCE_BRANCH_NAME:-main}
        if [ -e  $BASE_DIR/clusters/infra/$CLUSTER_NAME/tf-version.sh ]; then
            source $BASE_DIR/clusters/infra/$CLUSTER_NAME/tf-version.sh
        fi
        tf_path="$(get_tf_version $tf_version)"
        pushd $tf_path/terraform > /dev/null
        steps=cluster
        if [ -e $BASE_DIR/clusters/infra/$CLUSTER_NAME/multi-step.txt ]; then
            steps="$(cat $BASE_DIR/clusters/infra/$CLUSTER_NAME/multi-step.txt)"
            if [ -n "$op" ]; then
                echo "plan not supported for multi-step terraform"
                continue
            fi
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
        if [ -e  $BASE_DIR/clusters/infra/$CLUSTER_NAME/tf-version.sh ]; then
            source $BASE_DIR/clusters/infra/$CLUSTER_NAME/tf-version.sh
        else
            if [ -e  $HOME/clusters/infra/$CLUSTER_NAME/tf-version.sh ]; then
                source $HOME/clusters/infra/$CLUSTER_NAME/tf-version.sh
            fi
        fi
        tf_path="$(get_tf_version $tf_version)"
        pushd $tf_path/terraform > /dev/null
        steps=cluster
        if [ -e $HOME/clusters/infra/$CLUSTER_NAME/multi-step.txt ]; then
            steps="$(cat $HOME/clusters/infra/$CLUSTER_NAME/multi-step.txt | awk '{ for (i=NF; i>1; i--) printf("%s ",$i); print $1; }')"
            if [ -n "$op" ]; then
                echo "plan not supported for multi-step terraform"
                continue
            fi
        fi
        $SCRIPT_DIR/tf-run.sh $debug --root-dir $HOME --destroy $op $steps
        popd
    done
fi
