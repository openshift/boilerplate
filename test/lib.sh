#!/bin/bash

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

## compare FOLDER LOG_DIR
#
# Check FOLDER is properly sync'ed, determining the reference base on FOLDER 
#
# :param FOLDER: An existing directory sync'ed by boilerplate and to be checked
# :param LOG_FILE: The log file used to aggregate the output of the `diff` calls
compare() {
	if [ $1 = "_data" ] ; then
		if [ ! -f $repo/boilerplate/_data/last_boilerplate_commit ] ; then
			# TODO: Check the content of the file to ensure it contains the proper commit in addition to the file existence
			echo "$repo/boilerplate/_data/last_boilerplate_commit does not exist" >> $LOG_FILE
		fi
	else
		if [ -d $1 ] ; then
			diff --recursive -q $1 $BOILERPLATE_GIT_REPO/boilerplate/$1 >> $LOG_FILE
		else
			echo "`pwd`/$1 does not exist" >> $LOG_FILE
		fi
	fi
}

## check_update PREFIX
#
# Check the boilerplate synchronization is properly working, covering generics and convention
# specific parts
# :param PREFIX: Logs prefix (optional)
check_update() {
	pushd $repo/boilerplate > /dev/null
	
	if [ $# = 1 ] ; then
		LOG_FILE=$LOG_DIR/$1
		rm $LOG_FILE
	else 
		log=`cat /dev/urandom | env LC_CTYPE=C tr -cd 'a-f0-9' | head -c 10`
		LOG_FILE=$LOG_DIR/$log
	fi
	
	compare _data $LOG_FILE
	compare _lib $LOG_FILE
	
	while read convention ; do
	  if [ -d $BOILERPLATE_GIT_REPO/boilerplate/$convention ] ; then
		  compare $convention $LOG_FILE
	  fi
	done < $repo/boilerplate/update.cfg
	
	popd > /dev/null
	
	if [ `cat $LOG_FILE | wc -l` != 0 ] ; then
		cat $LOG_FILE
		return 1
	else
		return 0
	fi
}

## add_convention CONVENTION
#
# Add a convention and run the update script for the project to pick it up
# :param CONVENTION: An existing convention
add_convention() {
	if ! grep -q "^$1\$" $repo/boilerplate/update.cfg ; then
		echo $1 >> $repo/boilerplate/update.cfg
	fi
}
