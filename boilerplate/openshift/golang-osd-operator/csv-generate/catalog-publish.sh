#!/bin/bash -x

usage() { echo "Usage: $0 -o operator_name -i operator_image -c saas-repository-channel [-t]" 1>&2; exit 1; }

while getopts "o:c:n:h:p" option; do
    case "${option}" in
        c)
            operator_channel=${OPTARG}
            ;;
        h)
            operator_commit_hash=${OPTARG}
            ;;
        n)
            operator_commit_number=${OPTARG}
            ;;
        o)
            operator_name=${OPTARG}
            ;;
        p)
            push_catalog=true
            ;;
        *)
            usage
    esac
done

# Checking parameters
unset csv_missing_param_error

if [ -z "${operator_channel}" ] ; then 
    echo "Missing operator_channel parameter"
    csv_missing_param_error=true
fi

if [ -z "${operator_name}" ] ; then 
    echo "Missing operator_name parameter"
    csv_missing_param_error=true
fi

if [ -z "${operator_commit_hash}" ] ; then 
    echo "Missing operator_commit_hash parameter"
    csv_missing_param_error=true
fi

if [ -z "${operator_commit_number}" ] ; then 
    echo "Missing operator_commit_number parameter"
    csv_missing_param_error=true
fi

if [ ! -z "${csv_missing_param_error}" ] ; then
    usage
fi

# If no override, using the gitlab repo
if [ -z "${GIT_PATH}" ] ; then 
    GIT_PATH="https://app:@gitlab.cee.redhat.com/service/saas-${operator_name}-bundle.git"
fi

# Calculate previous version
SAAS_OPERATOR_DIR="saas-${operator_name}-bundle"
BUNDLE_DIR="${SAAS_OPERATOR_DIR}/${operator_name}/"
OPERATOR_NEW_VERSION=$(ls "${BUNDLE_DIR}" | sort -t . -k 3 -g | tail -n 1)
OPERATOR_PREV_VERSION=$(ls "${BUNDLE_DIR}" | sort -t . -k 3 -g | tail -n 2 | head -n 1)

# create package yaml
cat <<EOF > $BUNDLE_DIR/${operator_name}.package.yaml
packageName: ${operator_name}
channels:
- name: ${operator_channel}
  currentCSV: ${operator_name}.v${OPERATOR_NEW_VERSION}
EOF

# add, commit & push
pushd ${SAAS_OPERATOR_DIR}

git add .

MESSAGE="add version ${operator_commit_number}-${operator_commit_hash}
replaces ${OPERATOR_PREV_VERSION}
removed versions: ${REMOVED_VERSIONS}"

git commit -m "${MESSAGE}"
git push origin "${operator_channel}"

popd

if [ "$push_catalog" = true ] ; then
    # build the registry image
    REGISTRY_IMG="quay.io/app-sre/${operator_name}-registry"
    
    # push image
    skopeo copy --dest-creds "${QUAY_USER}:${QUAY_TOKEN}" \
        "docker-daemon:${REGISTRY_IMG}:${operator_channel}-latest" \
        "docker://${REGISTRY_IMG}:${operator_channel}-latest"
    
    skopeo copy --dest-creds "${QUAY_USER}:${QUAY_TOKEN}" \
        "docker-daemon:${REGISTRY_IMG}:${operator_channel}-latest" \
        "docker://${REGISTRY_IMG}:${operator_channel}-${operator_commit_hash}"
fi