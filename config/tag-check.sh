#!/usr/bin/env bash

set -e

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
# check all of them; so compare against the fork point of this branch.
# Don't compare the config/tag-check.sh file, as it's not impacted by
# build image changes.
default_branch="master"

# Ensure master branch reference is available in CI environments
if ! git rev-parse --verify $default_branch >/dev/null 2>&1; then
    echo "Master branch not found locally, attempting to fetch..."
    # Try to fetch master from origin
    if git ls-remote --heads origin $default_branch >/dev/null 2>&1; then
        git fetch origin $default_branch:$default_branch 2>/dev/null || true
    fi
    # If still not available, try using origin/master as fallback
    if ! git rev-parse --verify $default_branch >/dev/null 2>&1; then
        if git rev-parse --verify origin/$default_branch >/dev/null 2>&1; then
            echo "Using origin/$default_branch as reference..."
            default_branch="origin/$default_branch"
        else
            echo "Warning: Could not find master branch reference, using HEAD~1 as fallback"
            default_branch="HEAD~1"
        fi
    fi
fi

fork_point=$(git merge-base --fork-point $default_branch)

diff=$(git diff $fork_point --name-only -- config/ ':!config/tag-check.sh')
if [[ -n "${diff}" ]]; then
    echo "Image build configuration has changed!"
    echo "${diff}"
    echo "You must push a new image-v{X}.{Y}.{Z} tag at commit $commit!"
    echo "See https://github.com/openshift/boilerplate/blob/$commit/README.md#build-images"
    exit 1
fi

exit 0
