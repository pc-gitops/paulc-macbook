#!/usr/bin/env bash

# Utility functions

set -xe

export SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
export BASE_DIR=$(git rev-parse --show-toplevel)

function get_tf_version {
    tf_version=${1:-$GITHUB_HEAD_REF}
    if [ ! -d $HOME/$tf_version ]; then
        git clone --depth 1 --branch $tf_version ${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}.git $HOME/$tf_version >/dev/null
    fi
    echo $HOME/$tf_version
}
