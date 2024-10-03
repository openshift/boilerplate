if [ "$BOILERPLATE_SET_X" ]; then
    set -x
fi

# NOTE: Change this when publishing a new image tag.
LATEST_IMAGE_TAG=image-v4.0.1

REPO_ROOT=$(git rev-parse --show-toplevel)
# Make all tests use this local clone by default.
export BOILERPLATE_GIT_REPO=$REPO_ROOT
export LOG_DIR=$(mktemp -d -t boilerplate-logs-XXXXXXXX)

# Location of the convention config, relative to the repo root
export UPDATE_CFG=boilerplate/update.cfg
# Location of the nexus Makefile include, relative to a repo root
export NEXUS_MK=boilerplate/generated-includes.mk

_BP_TEST_TEMP_DIRS=

# ANSI colors
RED='\033[0;31m'
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
RESET='\033[0m'

# Set SED variable
if LANG=C sed --help 2>&1 | grep -q GNU; then
  SED="sed"
elif command -v gsed &>/dev/null; then
  SED="gsed"
else
  echo "Failed to find GNU sed as sed or gsed. If you are on Mac: brew install gnu-sed." >&2
  exit 1
fi


colorprint() {
  color=$1
  shift
  /bin/echo -e "${color}$@${RESET}"
}

err() {
  colorprint $RED "==ERROR== $@" >&2
  exit 1
}

# Override "echo" so test output is visually distinguished.
# NOTE: This means when you need to echo something raw (e.g. when
# constructing a file, or as "output" from a function), you need to use
# /bin/echo explicitly.
echo() {
  colorprint ${ORANGE} "$@"
}

_cleanup() {
    echo
    echo "Cleaning up"

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
    git init -b main >&2
    git config user.name "Test Boilerplate" >&2
    git config user.email "test@example.com" >&2
    # Add a remote for REPO_NAME discovery
    git remote add origin git@example.com:example-org/test-repo.git
    popd >&2
    /bin/echo $tmpd
}

## bootstrap_project PATH TEST_PROJECT INITIAL_CONVENTION
#
# Build a temp boilerplated git project containing test_project files
# - Copies in boilerplate/update from $REPO_ROOT
# - Creates an empty boilerplate/update.cfg
# It DOES run the update in order to allow using boilerplate/generated-includes.mk
#
# :param PATH: An existing directory that has been `git init`ed, like
#       what you get when you run `empty_repo`.
# :param TEST_PROJECT: the test_project (from test/projects)
# :param INITIAL_CONVENTION: The convention(s) to be used for initializing the
#       project. If it contains several conventions, they need to be passed
#       between " (eg "test_convention/foo test_convention/bar")
bootstrap_project() {
    repodir=$1
    test_project=$2
    (
        cp -R $REPO_ROOT/test/projects/$test_project/* $repodir/.
        cd $repodir
        # Commit the base files
        git add -A
        git commit -m "Commit baseline test project files"
        mkdir boilerplate
        cp $REPO_ROOT/boilerplate/update boilerplate
        printf "\n.PHONY: boilerplate-update\nboilerplate-update:\n\t@boilerplate/update\n" >> Makefile
        touch boilerplate/update.cfg
        for convention in $3 ; do
            add_convention . $convention
        done
        BOILERPLATE_IN_CI=1 make boilerplate-update
        ${SED?} -i '1s,^,include boilerplate/generated-includes.mk\n\n,' Makefile
        BOILERPLATE_IN_CI=1 make boilerplate-commit
    )
}

## bootstrap_repo PATH
#
# Gets a git repo ready for boilerplate:
# - Copies in boilerplate/update from $REPO_ROOT
# - Seeds the Makefile with the boilerplate-update target
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
.PHONY: boilerplate-update
boilerplate-update:
	@boilerplate/update
EOF
        > $UPDATE_CFG
    )
}

hr() {
    echo "========================="
}

## compare_data_file PATH EXPECTED_VALUE
#
# Check that the file at PATH exists and contains EXPECTED_VALUE.
# Writes any errors to $LOG_FILE.
#
# :param PATH: File system path, which may be relative to
#     $REPO_ROOT/boilerplate, of the data file to inspect.
# :param EXPECTED_VALUE: The expected contents of the file.
compare_data_file() {
    local datafile=$1
    local expected=$2
    if [[ ! -f $datafile ]]; then
        echo "$datafile does not exist" >> $LOG_FILE
    fi
    local actual=$(cat $datafile)
    if [[ "$actual" != "$expected" ]]; then
        cat <<EOF >> $LOG_FILE
Bad $datafile.
Expected: $expected
Actual:   $actual
EOF
    fi
}

## compare FOLDER LOG_FILE
#
# Check FOLDER is properly sync'ed, determining the reference base on FOLDER
#
# :param FOLDER: An existing directory sync'ed by boilerplate and to be checked
# :param LOG_FILE: The log file used to aggregate the output of the `diff` calls
compare() {
    if [ $1 = "_data" ] ; then
        compare_data_file _data/last-boilerplate-commit $(cd $BOILERPLATE_GIT_REPO; git rev-parse HEAD)
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
        /bin/echo "$2" >> "$file"
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
        ${SED?} -i "1s,^,$line\n\n," $file
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
    # HACK: Set safe.directory using environment variables in CI because we can't modify the global config, e.g. with
    # git config --global --add safe.directory '/go/src/github.com/openshift/boilerplate/.git'
    GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0='safe.directory' GIT_CONFIG_VALUE_0='/go/src/github.com/openshift/boilerplate/.git' git clone https://github.com/openshift/boilerplate.git $clone >&2
    if [ $# = 1 ] ; then
        pushd $clone > /dev/null
        git checkout $1
        popd > /dev/null
    fi
    # Print the directory. (It is important that nothing else above
    # prints to stdout.)
    /bin/echo $clone
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

## current_commit REPO
#
# Outputs the commit hash of the current commit in the REPO directory
current_commit() {
    (
        cd $1
        git rev-parse HEAD
    )
}

## current_branch REPO
#
# Outputs the name of the current branch in the REPO directory
current_branch() {
    (
        cd $1
        git rev-parse --abbrev-ref HEAD
    )
}

## last_commit_message REPO
#
# Outputs the last commit message in the REPO directory, skipping the
# commit/author/date and the following blank line, preserving the indent
# as output by `git log`.
last_commit_message() {
    (
        cd $1
        git log -1 | tail -n +5
    )
}

## expect_failure ERROR_STRING CMD ARGS...
#
# Runs CMD with ARGS...
# Fails if CMD succeeds.
# If CMD fails, the output (stdout+stderr) is grepped for ERROR_STRING,
# and we succeed iff it is found.
# CMD ARGS... is run via eval "$@". Quote accordingly.
expect_failure () {
    local errstr=$1
    shift
    local logf=$(mktemp -p $LOG_DIR)
    rc=0
    echo "Running command:"
    echo "   $@"
    echo "And expecting failure including output:"
    echo "   $errstr"
    eval "$@" >$logf 2>&1 || rc=$?
    if [[ $rc -eq 0 ]]; then
        echo "Expected failure but got success!" >&2
        return 1
    fi
    if ! grep -q "$errstr" $logf; then
        echo "Expected output not found!" >&2
        return 1
    fi
    return 0
}


## local_dummy_commit
#
# Generate dummy commit in the current location
local_dummy_commit () {
    new_file=`mktemp dummy-commit-XXXXXXXXXX`
    git add .
    git commit -m "Adding ${new_file}"
}
