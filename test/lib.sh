REPO_ROOT=$(git rev-parse --show-toplevel)
# Make all tests use this local clone by default.
export BOILERPLATE_GIT_REPO=$REPO_ROOT
export LOG_DIR=$(mktemp -d -t boilerplate_logs_XXXXXXXX)

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

## compare FOLDER LOG_FILE
#
# Check FOLDER is properly sync'ed, determining the reference base on FOLDER 
#
# :param FOLDER: An existing directory sync'ed by boilerplate and to be checked
# :param LOG_FILE: The log file used to aggregate the output of the `diff` calls
compare() {
    if [ $1 = "_data" ] ; then
        if [ ! -f _data/last_boilerplate_commit ] ; then
            # TODO: Check the content of the file to ensure it contains the proper commit in addition to the file existence
            echo "$repo/boilerplate/_data/last_boilerplate_commit does not exist" >> $LOG_FILE
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
    if [ $# -lt 2 ] ; then
        echo "Usage: check_update REPO (LOG_FILE)"
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
    done < $REPO/boilerplate/update.cfg
    
    popd > /dev/null
    
    if [[ -s $LOG_FILE ]] ; then
        cat $LOG_FILE
        return 1
    else
        return 0
    fi
}

## add_convention CONVENTION
#
# Add a convention if not already present in the TARGET repository
# :param TARGET: The target repository
# :param CONVENTION: An existing convention
add_convention() {
    if ! grep -q "^$2\$" $1/boilerplate/update.cfg ; then
        echo $2 >> $1/boilerplate/update.cfg
    fi
}

## new_boilerplate_repo POS
#
# Make a new clone of boilerplate, checking out POS (may it be branch or commit ID)
# :param POS: The position in the git repository to checkout (branch or commit ID)
new_boilerplate_repo() {
	pushd $(mktemp -d -t boilerplate-clone-) > /dev/null
	pwd
	git clone https://github.com/openshift/boilerplate.git > /dev/null
	if [ $# = 1 ] ; then
		git checkout $1
	fi
	popd > /dev/null
}

## override_boilerplate_version NEW_PATH
#
# Override the boilerplate version to be used for the testing. 
# :param NEW_PATH: A clone of boilerplate to be used for the future steps
override_boilerplate_version() {
	if [ -d $1 ] ; then
		BOILERPLATE_GIT_REPO=$1
	fi
}

## reset_boilerplate_version 
#
# Reset the boilerplate version to be used to the 'tested' clone. 
reset_boilerplate_version() {
	BOILERPLATE_GIT_REPO=$REPO_ROOT
}
