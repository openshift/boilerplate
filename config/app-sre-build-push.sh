#!/usr/bin/env bash

set -ex

# Usage: app-sre-build-push.sh REGISTRY NAMESPACE NAME
# e.g. app-sre-build-push push.sh quay.io app-sre boilerplate
# Builds and pushes a new tagged image IF the most recent tag does not yet have an image.
# Checks out the right version for the tag beforehand. 
# Assumes $QUAY_USER and $QUAY_TOKEN are set in the env.

# Get the most recent tag starting with "image-v*"
latest_tag=$(git describe --tags --match "image-v*" --abbrev=0)
if [ -z ${latest_tag} ]; then
    echo "No tag matching pattern 'image-v*' found."
    exit 1
fi

# E.g. quay.io/app-sre/boilerplate:image-v1.0.0
IMAGE="quay.io/app-sre/boilerplate:${latest_tag}"

HERE=$(realpath ${0%/*})
CONTAINER_ENGINE_CONFIG_DIR=.docker
mkdir -p "${CONTAINER_ENGINE_CONFIG_DIR}"
REGISTRY_AUTH_FILE = ${CONTAINER_ENGINE_CONFIG_DIR}/config.json

podman login -u="${QUAY_USER}" -p="${QUAY_TOKEN}" quay.io

# Check if the image exists already
inspect_output=$(skopeo inspect "${IMAGE}" 2>&1)
return_code=$?

# We need to make sure we don't re-create in case there's a different error
# so we also check that the returned output is something like 
# skopeo inspect "docker://quay.io/app-sre/boilerplate:image-v5.0.1" 2>&1
# time="2024-07-08T22:52:52-04:00" level=fatal msg="Error parsing image name \"docker://quay.io/app-sre/boilerplate:image-v5.0.1\": reading manifest image-v5.0.1 in quay.io/app-sre/boilerplate: manifest unknown"
if [ "$return_code" -eq 0 ]; then
    echo "Image: ${IMAGE} already exists. Skipping image build/push."
elif [ "$return_code" -ne 0 ] && { [[ $inspect_output == *"manifest unknown"* ]] }; then
    echo "Image: ${IMAGE} does not exist. Starting image build/push"
    git checkout ${latest_tag}
    podman build "${HERE}" -f "${HERE}/Dockerfile.appsre" -t "${IMAGE}"
    podman push "${IMAGE}"
else
    echo "Unexpected error checking for image existence. Exit code: $return_code, Output: $inspect_output"
    exit 1
fi

exit 0