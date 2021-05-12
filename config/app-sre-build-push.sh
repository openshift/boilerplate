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

# Decide whether we need to build and push a new image "release" tag.
# This gets us the last non-merge commit:
commit=$(git rev-list --no-merges -n 1 HEAD)
# If that commit corresponds to an image tag, this gets the tag:
tag=$(git describe --exact-match --tag --match image-v* $commit 2>/dev/null || true)
if [[ -n "$tag" ]]; then
    build_cumulative $tag
    push_for_tag $tag
else
    echo "No tag here. All done."
fi
exit 0
