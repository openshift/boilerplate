#!/bin/bash -x

usage() { echo "Usage: $0 -o operator_name -i operator_image -c saas-repository-channel [-t]" 1>&2; exit 1; }

while getopts "o:i:c:n:h:t" option; do
    case "${option}" in
        c)
            operator_channel=${OPTARG}
            ;;
        o)
            operator_name=${OPTARG}
            ;;
        n)
            operator_commit_number=${OPTARG}
            ;;
        h)
            operator_commit_hash=${OPTARG}
            ;;
        *)
            usage
    esac
done

# Testing variable
#GIT_PATH="https://app:@gitlab.cee.redhat.com/service/saas-${operator_name}-bundle.git"
GIT_PATH="/Users/bdematte/git/fake/saas-file-generate-bundle"

# Calculate previous version
SAAS_OPERATOR_DIR="saas-${operator_name}-bundle"
BUNDLE_DIR="$SAAS_OPERATOR_DIR/${operator_name}/"
OPERATOR_NEW_VERSION=$(ls "$BUNDLE_DIR" | sort -t . -k 3 -g | tail -n 1)
OPERATOR_PREV_VERSION=$(ls "${BUNDLE_DIR}" | sort -t . -k 3 -g | tail -n 2 | head -n 1)

# create package yaml
cat <<EOF > $BUNDLE_DIR/${operator_name}.package.yaml
packageName: ${operator_name}
channels:
- name: $operator_channel
  currentCSV: ${operator_name}.v${OPERATOR_NEW_VERSION}
EOF

# add, commit & push
pushd $SAAS_OPERATOR_DIR

git add .

MESSAGE="add version $operator_commit_number-$operator_commit_hash
replaces $OPERATOR_PREV_VERSION
removed versions: $REMOVED_VERSIONS"

git commit -m "$MESSAGE"
git push origin "$operator_channel"

popd