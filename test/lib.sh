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

## diff BASELINE
#
# Recursively compare the current repository content to the BASELINE repository
#
# :param BASELINE: An existing directory used as reference to compared sync'ed files
diff() {
	for file in `ls` ; do 
		if [ -d $file ] ; then 
			pushd $file  > /dev/null
			diff $1/$file 
			popd  > /dev/null
		elif [ -f $file ] ; then
			cmp $file $1/$file
			if [ ! $? = 0 ] ; then
				handle_error_counter INC
			fi
		fi
	done
}

## compare FOLDER
#
# Check FOLDER is properly sync'ed, determining the reference base on FOLDER 
#
# :param FOLDER: An existing directory sync'ed by boilerplate and to be checked
compare() {
	if [ $1 = "_data" ] ; then
		if [ ! -f $repo/boilerplate/_data/last_boilerplate_commit ] ; then
			# TODO: Check the content of the file to ensure it contains the proper commit in addition to the file existence
			handle_error_counter INC
		fi
	else
		pushd $1  > /dev/null
		diff $BOILERPLATE_GIT_REPO/boilerplate/$1
		popd > /dev/null
	fi
}

## check_update
#
# Check the boilerplate synchronization is properly working, covering generics and convention
# specific parts
check_update() {
	handle_error_counter INIT
	pushd $repo/boilerplate > /dev/null
	
	compare _data
	compare _lib
	
	while read convention ; do
	  if [ -d $BOILERPLATE_GIT_REPO/boilerplate/$convention ] ; then
		  compare $convention
	  fi
	done < $repo/boilerplate/update.cfg
	
	popd > /dev/null
	
	handle_error_counter CHECK
	
	exit $?
}

## add_convention CONVENTION
#
# Add a convention and run the update script for the project to pick it up
# :param CONVENTION: An existing convention
add_convention() {
	if grep -q "^$1\$" $repo/boilerplate/update.cfg ; then
		echo $1 >> $repo/boilerplate/update.cfg
	fi
}

## handle_error_counter FUNCTION
#
# Function managing the error counter to increment in case of diff found for a file and print before returning
# :param FUNCTION: action to be done on the error counter
#  - RESET : Initilize the error counter to 0 
#  - INC : Increment the internal counter by 1
#  - CHECK : Check the number of diff is 0. If it is not, returns 1 and print the number of errors found
handle_error_counter() {
	declare -i error_counter
	if [ $1 = "RESET" ] ; then 
		error_counter=0
	elif [ $1 = "INC" ] ; then
		error_counter=`expr $error_counter+1`
	elif [ $1 = "CHECK" ] ; then 
		if [ ! $error_counter = 0 ] ; then 
			echo "$error_counter differences have been detected between the project and the convention"
			exit 1
		fi
	fi
	
	exit 0
}
