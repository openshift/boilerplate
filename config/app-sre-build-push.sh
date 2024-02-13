#!/usr/bin/env bash

set -ex

# Usage: push.sh REGISTRY NAMESPACE NAME
# e.g. push.sh quay.io app-sre boilerplate
# Builds and pushes a new tagged image IF the most recent tag does not yet have an image.
# Checks out the right version for the tag beforehand. 
# Assumes $QUAY_USER and $QUAY_TOKEN are set in the env.

registry=$1
namespace=$2
name=$3

quay_image=$registry/$namespace/$name

HERE=$(realpath ${0%/*})
container_engine=${CONTAINER_ENGINE:-$(command -v podman || echo docker)}

build_cumulative() {
    local tag=$1
    echo "Building for tag $tag"
    $container_engine build -t ${name}:${tag} -f ${HERE}/Dockerfile.appsre ${HERE}
}

push_for_tag() {
    local tag=$1
    echo "Pushing for tag $tag"
    skopeo copy --dest-creds "${QUAY_USER}:${QUAY_TOKEN}" \
        "docker-daemon:${name}:$tag" \
        "docker://${quay_image}:$tag"
}

# Get the most recent tag starting with "image-v*"
latest_tag=$(git describe --tags --match "image-v*" --abbrev=0)
if [ -z ${latest_tag} ]; then
    echo "No tag matching pattern 'image-v*' found."
    exit 1
fi

# Run podman manifest inspect in a subshell and capture the output and rc
inspect_output=$($container_engine manifest inspect "quay.io/app-sre/boilerplate:${latest_tag}" 2>&1) && return_code=0 || return_code=$?

# We need to make sure we don't re-create in case there's a different error
# so we also check that the returned output is something like 
# podman manifest inspect quay.io/app-sre/boilerplate:image-v5.0.0
# Error: reading image "docker://quay.io/app-sre/boilerplate:image-v5.0.0": reading manifest image-v5.0.0 in quay.io/app-sre/boilerplate: manifest unknow
# docker manifest inspect quay.io/app-sre/boilerplate:image-v5.0.0
# no such manifest: quay.io/app-sre/boilerplate:image-v5.0.0
if [ "$return_code" -eq 0 ]; then
    echo "Image 'quay.io/app-sre/boilerplate:${latest_tag}' already exists."
elif [ "$return_code" -ne 0 ] && { [[ $inspect_output == *"manifest unknown"* ]] || [[ $inspect_output == *"no such manifest"* ]]; }; then
    echo "Creating image 'quay.io/app-sre/boilerplate:${latest_tag}' does not exist."
    git checkout ${latest_tag}
    echo "Creating image 'quay.io/app-sre/boilerplate:${latest_tag}'"
    build_cumulative ${latest_tag}
    push_for_tag ${latest_tag}
else
    echo "Error checking for image existence. Exit code: $return_code, Output: $inspect_output"
    exit 1
fi

exit 0