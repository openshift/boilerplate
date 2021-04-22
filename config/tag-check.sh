#!/usr/bin/env bash

set -xe

# If you mess with the build image, you must publish a new
# image-v{X}.{Y}.{Z} tag. We can't automatically generate that tag,
# because we can't figure out what the semver should be, because we
# don't know the impact of what you've changed. So this script makes
# sure that you created the tag. And since we're running this in prow,
# it also makes sure that the tag has been pushed to upstream.

# This gets us the last non-merge commit:
commit=$(git rev-list --no-merges -n 1 HEAD)
# If that commit corresponds to an image tag, this gets the tag:
tag=$(git describe --exact-match --tag --match image-v* $commit 2>/dev/null || true)

if [[ -n "$tag" ]]; then
    echo "Found tag $tag at current commit :)"
    exit 0
fi

# No tag here. That's okay as long as there were no changes to the build
# image.

# Since we're in a PR, and there may be multiple commits, we want to
# check all of them; so compare against the last merge commit before
# this one. This should work both locally (that should correspond to
# upstream/master) and in CI (which creates a merge commit to test
# against).
# NOTE: This assumes we always merge with merge commits.
last_merge_commit=$(git log --merges -n1 HEAD^ --format=%H)
if [[ -n "$(git diff $last_merge_commit --name-only config/)" ]]; then
    echo "Image build configuration has changed!"
    echo "You must push a new image-v{X}.{Y}.{Z} tag at commit $commit!"
    echo "See https://github.com/openshift/boilerplate/blob/$commit/README.md#build-images"
    exit 1
fi

exit 0
