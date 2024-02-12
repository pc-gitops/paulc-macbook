#!/usr/bin/env bash

# Build image

set -xe

version=${1:-}

if [ -z "$version" ]; then
    echo "Usage: $0 <image version>"
    exit
fi

export SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
export BASE_DIR=$(git rev-parse --show-toplevel)

pushd ${BASE_DIR}/infra-runner

export INFRA_EXEC_VERSION=1.5.7
export INFRA_EXEC_NAME=terraform
export INFRA_EXEC_URL_PREFIX=https://releases.hashicorp.com/terraform/
export VERSION=0.0.$version

docker build . -f Dockerfile --no-cache \
    --build-arg="INFRA_EXEC_VERSION=$INFRA_EXEC_VERSION" \
    --build-arg="INFRA_EXEC_NAME=$INFRA_EXEC_NAME" \
    --build-arg="INFRA_EXEC_URL_PREFIX=$INFRA_EXEC_URL_PREFIX" \
    -t pcarlton/infra-runner:$VERSION

docker push pcarlton/infra-runner:$VERSION
