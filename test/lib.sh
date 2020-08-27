#!/bin/bash

REPO_ROOT=$(git rev-parse --show-toplevel)
# Make all tests use this local clone by default.
export BOILERPLATE_GIT_REPO=$REPO_ROOT

_BP_TEST_TEMP_DIRS=

_cleanup() {
    echo
    echo "Cleaning up"
    [ -z "$_BP_TEST_TEMP_DIRS" ] && return

    if [ -z "$PRESERVE_TEMP_DIRS" ]; then
        echo "Removing temporary directories"
        rm -fr $_BP_TEST_TEMP_DIRS
    else
        echo "Preserving temporary directories: $_BP_TEST_TEMP_DIRS"
    fi
}
trap _cleanup EXIT

add_cleanup() {
    # Stage this temp dir for cleanup
    _BP_TEST_TEMP_DIRS="$_BP_TEST_TEMP_DIRS $1"
}

empty_repo() {
    tmpd=$(mktemp -d)
    git init $tmpd >&2
    echo $tmpd
}

## bootstrap_repo PATH
#
# Gets a git repo ready for boilerplate:
# - Copies in boilerplate/update from $REPO_ROOT
# - Seeds the Makefile with the update_boilerplate target
# - Creates an empty boilerplate/update.cfg
# It does not run the update.
#
# :param PATH: An existing directory that has been `git init`ed, like
#       what you get when you run `empty_repo`.
bootstrap_repo() {
    repodir=$1
    (
        cd $repodir
        mkdir boilerplate
        cp $REPO_ROOT/boilerplate/update boilerplate
        cat <<EOF > Makefile
.PHONY: update_boilerplate
update_boilerplate:
	@boilerplate/update
EOF
        > boilerplate/update.cfg
    )
}

hr() {
    echo "========================="
}
