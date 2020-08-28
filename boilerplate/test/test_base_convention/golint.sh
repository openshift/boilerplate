#!/usr/bin/env bash

CMD=${0##*/}

# TODO(efried): Accept optional targets override
targets=$(go list -f '{{ .Dir }}' ./...)
# TODO(efried): Accept optional ignores regex override
# This is a grep-ish regex
ignores='/zz_generated.*\.go'

usage () {
    cat <<EOF
Usage: $CMD [{-f|--fix}]

Lints go files with gofmt.

See TARGETS below for directories that are searched for go files.

Default mode is non-invasive: reports files in which discrepancies are
found and prints diffs that would repair them.

Ignores paths matching this (grep-ish) regex: '$ignores'

Exits zero if files are clean; nonzero if discrepancies are found.

OPTIONS
    -f, --fix
        Fixes the problems it finds. (Don't forget to commit the
	changes.)

TARGETS:
$targets

EOF

    exit -1
}

err() {
    echo "$@" >&2
    exit -1
}

OPTS=$(getopt -o hf --long fix,help -n "$CMD" -- "$@")
[ $? != 0 ] && usage

eval set -- "$OPTS"

FIX=
while true; do
    case "$1" in
	-f | --fix )
	    FIX=1
	    shift
	    ;;
        -h | --help ) usage;;
	-- ) shift; break ;;
    esac
done

[ $@ ] && err "Unrecognized argument(s): '$@'
Specify -h for help."

tmpd=`mktemp -d`
trap "rm -fr $tmpd" EXIT
lintylist=$tmpd/linty.list

gofmt -s -l $targets | grep ".*\.go" | grep -v "$ignores" > $lintylist
if ! [ -s $lintylist ]; then
    echo "You are lint free. Congratulations."
    exit 0
fi

# Okay, we're linty. Print the diffs.
echo '=============='
echo 'YOU ARE LINTY!'
echo '=============='
cat $lintylist
echo '=============='
cat $lintylist | xargs gofmt -s -d
echo '=============='

if [ -z $FIX ]; then
    echo 'Specify `--fix` to write the above changes.'
    exit 1
fi

echo "Fixing..."
cat $lintylist | xargs gofmt -s -w
echo "Done. Don't forget to commit the changes."

exit 0
