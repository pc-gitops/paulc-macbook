#!/usr/bin/env bash

# Build image

set -xe

export SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
export BASE_DIR=$(git rev-parse --show-toplevel)

pushd ${BASE_DIR}/infra-runner

export BASE_IMAGE=alpine:3.19.0
export INFRA_EXEC_VERSION=1.5.7
export INFRA_EXEC_NAME=terraform
export INFRA_EXEC_URL_PREFIX=https://releases.hashicorp.com/terraform/
export VERSION=0.0.1

export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

docker build . -f Dockerfile --no-cache \
    --build-arg="BASE_IMAGE=$BASE_IMAGE" \
    --build-arg="INFRA_EXEC_VERSION=$INFRA_EXEC_VERSION" \
    --build-arg="INFRA_EXEC_NAME=$INFRA_EXEC_NAME" \
    --build-arg="INFRA_EXEC_URL_PREFIX=$INFRA_EXEC_URL_PREFIX" \
    -t $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/infra-runner:$VERSION

# Login to ECR
ecr_pass="$(aws ecr get-login-password --region $AWS_REGION)"
docker login --username AWS --password $ecr_pass $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/infra-runner:$VERSION
