#!/bin/bash -e

# Usage: push.sh REGISTRY NAMESPACE NAME
# e.g. push.sh quay.io app-sre boilerplate
# Assumes $QUAY_USER and $QUAY_TOKEN are set in the env.
# Assumes ${NAME}:latest has already been built locally.

registry=$1
namespace=$2
name=$3

quay_image=$registry/$namespace/$name
git_hash=$(git rev-parse --short=7 HEAD)

push_for_tag() {
    local tag=$1
    echo "Pushing for tag $tag"
    skopeo copy --dest-creds "$(QUAY_USER):$(QUAY_TOKEN)" \
        "docker-daemon:$(name):latest" \
        "docker://$(quay_image):$tag"
}

push_for_tag latest

push_for_tag $git_hash

# Now decide whether we need to push a new image "release" tag.
# This gets us the last non-merge commit:
commit=$(git rev-list --no-merges -n 1 HEAD)
# If that commit corresponds to an image tag, this gets the tag:
tag=$(git describe --exact-match --tag --match image-v* $commit 2>/dev/null || true)
if [[ -n "$tag" ]]; then
    push_for_tag $tag
else
    echo "No tag here. All done."
fi
exit 0

