#!/usr/bin/env bash

set -ex

# Usage: push.sh REGISTRY NAMESPACE NAME
# e.g. push.sh quay.io app-sre boilerplate
# Builds and pushes a new tagged image IFF we are on a tag. Otherwise it
# is a no-op.
# Assumes $QUAY_USER and $QUAY_TOKEN are set in the env.

registry=$1
namespace=$2
name=$3

quay_image=$registry/$namespace/$name

HERE=$(realpath ${0%/*})

build_cumulative() {
    local tag=$1
    local container_engine=${CONTAINER_ENGINE:-$(command -v podman || echo docker)}
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

if podman manifest inspect "quay.io/app-sre/boilerplate:${latest_tag}" &>/dev/null; then
    echo "Image 'quay.io/app-sre/boilerplate:${latest_tag}' already exists."
else
    echo "Creating image 'quay.io/app-sre/boilerplate:${latest_tag}'"
    build_cumulative ${latest_tag}
    push_for_tag ${latest_tag}
fi

exit 0
