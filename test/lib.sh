if [ "$BOILERPLATE_SET_X" ]; then
    set -x
fi

REPO_ROOT=$(git rev-parse --show-toplevel)
# Make all tests use this local clone by default.
export BOILERPLATE_GIT_REPO=$REPO_ROOT
export LOG_DIR=$(mktemp -d -t boilerplate-logs-XXXXXXXX)

# Location of the convention config, relative to the repo root
export UPDATE_CFG=boilerplate/update.cfg
# Location of the nexus Makefile include, relative to a repo root
export NEXUS_MK=boilerplate/generated-includes.mk

_BP_TEST_TEMP_DIRS=

_cleanup() {
    echo
    echo "Cleaning up"
    [ -z "$_BP_TEST_TEMP_DIRS" ] && return

    if [ -z "$PRESERVE_TEMP_DIRS" ]; then
        echo "Removing temporary directories"
        rm -fr $_BP_TEST_TEMP_DIRS
        rm -rf $LOG_DIR
    else
        echo "Preserving temporary directories: $_BP_TEST_TEMP_DIRS $LOG_DIR"
    fi
}
trap _cleanup EXIT

add_cleanup() {
    # Stage this temp dir for cleanup
    _BP_TEST_TEMP_DIRS="$_BP_TEST_TEMP_DIRS $1"
}

## empty_repo
#
# Creates a temporary directory and initializes it as a git repository.
# Outputs the directory. Does not register it for cleanup.
empty_repo() {
    tmpd=$(mktemp -d -t boilerplate-test-XXXXXXXX)
    pushd $tmpd >&2
    git init >&2
    # Add a remote for REPO_NAME discovery
    git remote add origin git@example.com:example-org/test-repo.git
    popd >&2
    echo $tmpd
}

## bootstrap_repo PATH
#
# Gets a git repo ready for boilerplate:
# - Copies in boilerplate/update from $REPO_ROOT
# - Seeds the Makefile with the update-boilerplate target
# - Creates an empty boilerplate/update.cfg
# It does not run the update.
#
# :param PATH: An existing directory that has been `git init`ed, like
#       what you get when you run `empty_repo`.
bootstrap_repo() {
    repodir=$1
    (
        cd $repodir
        mkdir -p boilerplate
        cp $REPO_ROOT/boilerplate/update boilerplate
        cat <<EOF > Makefile
.PHONY: update-boilerplate
update-boilerplate:
	@boilerplate/update
EOF
        > $UPDATE_CFG
        # update requires a clean checkout
        git add -A
        git commit -m "Bootstrap"
    )
}

hr() {
    echo "========================="
}

## compare FOLDER LOG_FILE
#
# Check FOLDER is properly sync'ed, determining the reference base on FOLDER
#
# :param FOLDER: An existing directory sync'ed by boilerplate and to be checked
# :param LOG_FILE: The log file used to aggregate the output of the `diff` calls
compare() {
    if [ $1 = "_data" ] ; then
        if [ ! -f _data/last-boilerplate-commit ] ; then
            echo "_data/last-boilerplate-commit does not exist" >> $LOG_FILE
        fi
        local expected=$(cd $BOILERPLATE_GIT_REPO; git rev-parse HEAD)
        local actual=$(cat _data/last-boilerplate-commit)
        if [[  $actual != $expected ]]; then
            cat <<EOF >> $LOG_FILE
Bad last-boilerplate-commit.
Expected: $expected
Actual:   $actual
EOF
        fi
    else
        # Don't let this kill tests using -e. The failure is detected
        # later based on the $LOG_FILE being nonempty.
        diff --recursive -q $1 $BOILERPLATE_GIT_REPO/boilerplate/$1 >> $LOG_FILE 2>&1 || true
    fi
}

## check_update REPO (LOG_FILE)
#
# Check the boilerplate synchronization is properly working, covering generics and convention
# specific parts
# :param REPO: The boilerplate repository to be checked
# :param LOG_FILE: Log file name (optional). If none is provided, a name will be generated.
# If file isn't empty, it will be truncated.
check_update() {
    local convention

    if [ $# -gt 2 ] ; then
        echo "Usage: check_update REPO (LOG_FILE)"
        return 1
    fi

    REPO=$1
    pushd $REPO/boilerplate > /dev/null

    if [ $# = 2 ] ; then
        LOG_FILE=$LOG_DIR/$2
        rm -f $LOG_FILE
        touch $LOG_FILE
    else
        LOG_FILE=`mktemp $LOG_DIR/log.XXXXXXXX`
    fi

    compare _data $LOG_FILE
    compare _lib $LOG_FILE

    while read convention ; do
      if [ -d $BOILERPLATE_GIT_REPO/boilerplate/$convention ] ; then
          compare $convention $LOG_FILE
      else
          echo "$BOILERPLATE_GIT_REPO/boilerplate/$convention is not a directory" >> $LOG_FILE
      fi
    done < $REPO/$UPDATE_CFG

    popd > /dev/null

    if [[ -s $LOG_FILE ]] ; then
        cat $LOG_FILE
        return 1
    else
        return 0
    fi
}

## _is_line_in_file LINE FILE
# Succeeds if LINE exists (anywhere) in FILE; fails otherwise.
# :param LINE: The complete line of text to search for. Note that this
# is processed with `grep`, so regexes should be escaped if it matters.
# :param FILE: The path to the file to search.
_is_line_in_file() {
    grep -q "^$1\$" "$2" 2>/dev/null
}

## add_convention TARGET CONVENTION
#
# Add a convention if not already present in the TARGET repository
# :param TARGET: The target repository
# :param CONVENTION: An existing convention
add_convention() {
    file="$1/$UPDATE_CFG"
    if ! _is_line_in_file "$2" "$file" ; then
        echo "$2" >> "$file"
    fi
}

## ensure_nexus_makefile_include
#
# Make sure the base Makefile in the TARGET repository includes the
# nexus Makefile include.
# :param TARGET: The target repository
ensure_nexus_makefile_include() {
    file=$1/Makefile
    # NOTE: Escape the period for `grep` (paranoid), but collapse it for `sed`.
    line='include boilerplate/generated-includes\.mk'

    if ! _is_line_in_file $line $file; then
        # Put the line at the top.
        sed -i "1s,^,$line\n\n," $file
        # Commit for update's clean check
        git commit -am "Include nexus makefile"
    fi
}

## new_boilerplate_clone POS
#
# Make a new clone of boilerplate, checking out POS (may it be branch or
# commit ID). The directory is registered for cleanup on exit.
# :param POS: The position in the git repository to checkout (branch or commit ID)
#
# Outputs the path to the new clone.
new_boilerplate_clone() {
    local clone=$(mktemp -d -t boilerplate-clone-XXXXXXXX)
    add_cleanup $clone
    git clone https://github.com/openshift/boilerplate.git $clone >&2
    if [ $# = 1 ] ; then
        pushd $clone > /dev/null
        git checkout $1
        popd > /dev/null
    fi
    # Print the directory. (It is important that nothing else above
    # prints to stdout.)
    echo $clone
}

## override_boilerplate_repo NEW_PATH
#
# Override the boilerplate repository to be used for the testing.
# :param NEW_PATH: A clone of boilerplate to be used for the future steps
override_boilerplate_repo() {
    if ! [ -d $1 ] ; then
        echo "$1: Not a directory"
        return 1
    fi
    BOILERPLATE_GIT_REPO=$1
}

## reset_boilerplate_repo
#
# Reset the boilerplate repository to be used to the 'tested' clone.
reset_boilerplate_repo() {
    BOILERPLATE_GIT_REPO=$REPO_ROOT
}
