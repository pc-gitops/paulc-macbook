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

source infra-runner/bin/lib.sh

if [ -n "$debug" ]; then
    env | sort
fi

# git config --file /home/infra/.gitconfig --add safe.directory /builds/MedxHealthCorp/environments

if [ -n "${CI_COMMIT_BRANCH:-}" ]; then # merge to main
    if [ "$CI_COMMIT_BRANCH" != main ]; then
        echo "Expecting main branch!"
        exit 1
    fi

    curl --header "PRIVATE-TOKEN: ${gitlab_token}" https://gitlab.com/api/v4/projects/${CI_PROJECT_ID}/repository/commits/$CI_COMMIT_SHA/diff | \
        jq -r '.[] | select (.deleted_file == true) | .new_path' | grep -E "^clusters/infra/.*/.*" > $HOME/deleted.txt || echo "no deletions"

    rm -rf $HOME/destroy-list.txt
    for deleted_file in $(cat $HOME/deleted.txt)
    do
        mkdir -p $(dirname $HOME/$deleted_file)
        curl --header "PRIVATE-TOKEN: ${gitlab_token}" https://gitlab.com/api/v4/projects/${CI_PROJECT_ID}/repository/commits/$CI_COMMIT_SHA/diff | \
        jq --arg file_path "$deleted_file" -r '.[] | select (.new_path == $file_path ) | .diff' | \
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
