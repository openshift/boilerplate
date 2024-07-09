#!/usr/bin/env bash

# Usage: app-sre-build-push.sh
# e.g. ./app-sre-build-push.sh
# Builds and pushes a new tagged image IF the most recent tag does not yet have an image.
# Checks out the right version for the tag beforehand. 
# Assumes $QUAY_USER and $QUAY_TOKEN are set in the env.

image_exists_in_repo() {
    local image_uri=$1
    local output
    local rc

    local skopeo_stderr=$(mktemp)

    output=$(skopeo inspect docker://${image_uri} 2>$skopeo_stderr)
    rc=$?
    # So we can delete the temp file right away...
    stderr=$(cat $skopeo_stderr)
    rm -f $skopeo_stderr
    if [[ $rc -eq 0 ]]; then
        # The image exists. Sanity check the output.
        local digest=$(echo $output | jq -r .Digest)
        if [[ -z "$digest" ]]; then
            echo "Unexpected error: skopeo inspect succeeded, but output contained no .Digest"
            echo "Here's the output:"
            echo "$output"
            echo "...and stderr:"
            echo "$stderr"
            exit 1
        fi
        echo "Image ${image_uri} exists with digest $digest."
        return 0
    elif [[ "$stderr" == *"manifest unknown"* ]]; then
        # We were able to talk to the repository, but the tag doesn't exist.
        # This is the normal "green field" case.
        echo "Image ${image_uri} does not exist in the repository."
        return 1
    elif [[ "$stderr" == *"was deleted or has expired"* ]]; then
        # This should be rare, but accounts for cases where we had to
        # manually delete an image.
        echo "Image ${image_uri} was deleted from the repository."
        echo "Proceeding as if it never existed."
        return 1
    else
        # Any other error. For example:
        #   - "unauthorized: access to the requested resource is not
        #     authorized". This happens not just on auth errors, but if we
        #     reference a repository that doesn't exist.
        #   - "no such host".
        #   - Network or other infrastructure failures.
        # In all these cases, we want to bail, because we don't know whether
        # the image exists (and we'd likely fail to push it anyway).
        echo "Error querying the repository for ${image_uri}:"
        echo "stdout: $output"
        echo "stderr: $stderr"
        exit 1
    fi
}

set -ex

# Get the most recent tag starting with "image-v*"
latest_tag=$(git describe --tags --match "image-v*" --abbrev=0)
if [ -z ${latest_tag} ]; then
    echo "No tag matching pattern 'image-v*' found."
    exit 1
fi

# E.g. quay.io/app-sre/boilerplate:image-v1.0.0
IMAGE="quay.io/app-sre/boilerplate:${latest_tag}"
HERE=$(realpath ${0%/*})

# Copy the node container auth file so that we get access to the registries the
# parent node has access to, i.e. registry.ci.openshift.org
CONTAINER_ENGINE_CONFIG_DIR=.docker
mkdir -p "${CONTAINER_ENGINE_CONFIG_DIR}"
export REGISTRY_AUTH_FILE=${CONTAINER_ENGINE_CONFIG_DIR}/config.json
cp /var/lib/jenkins/.docker/config.json "$REGISTRY_AUTH_FILE"

podman login -u="${QUAY_USER}" -p="${QUAY_TOKEN}" quay.io

# Check if the image exists already
if image_exists_in_repo "${IMAGE}"; then
    echo "Image: ${IMAGE} already exists. Skipping image build/push."
    exit 0
fi

echo "Image: ${IMAGE} does not exist. Starting image build/push"
git checkout ${latest_tag}
podman build "${HERE}" -f "${HERE}/Dockerfile.appsre" -t "${IMAGE}"
podman push "${IMAGE}"

exit 0
