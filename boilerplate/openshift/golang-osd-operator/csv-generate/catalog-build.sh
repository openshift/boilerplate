#!/bin/bash

usage() { echo "Usage: $0 -o operator_name -i operator_image -c saas-repository-channel [-t]" 1>&2; exit 1; }

while getopts "o:h:c:" option; do
    case "${option}" in
        o)
            operator_name=${OPTARG}
            ;;
        c)
            operator_channel=${OPTARG}
            ;;
        h)
            operator_commit_hash=${OPTARG}
            ;;
        *)
            usage
    esac
done

# Checking parameters
unset csv_missing_param_error

if [ -z "$operator_channel" ] ; then 
    echo "Missing operator_channel parameter"
    csv_missing_param_error = true
fi

if [ -z "$operator_name" ] ; then 
    echo "Missing operator_name parameter"
    csv_missing_param_error = true
fi

if [ -z "$operator_commit_hash" ] ; then 
    echo "Missing operator_commit_hash parameter"
    csv_missing_param_error = true
fi

if [ ! -z "$csv_missing_param_error" ] ; then
    usage
fi

# If no override, using the gitlab repo
if [ -z "$GIT_PATH" ] ; then 
    GIT_PATH="https://app:@gitlab.cee.redhat.com/service/saas-${operator_name}-bundle.git"
fi

# Calculate previous version
SAAS_OPERATOR_DIR="saas-${operator_name}-bundle"
BUNDLE_DIR="$SAAS_OPERATOR_DIR/${operator_name}/"

OPERATOR_PREV_VERSION="$(ls "$BUNDLE_DIR" | sort -t . -k 3 -g | tail -n 1)"

# build the registry image
REGISTRY_IMG="quay.io/app-sre/${operator_name}-registry"
DOCKERFILE_REGISTRY="Dockerfile.olm-registry"

cat <<EOF > $DOCKERFILE_REGISTRY
FROM quay.io/openshift/origin-operator-registry:latest
COPY $SAAS_OPERATOR_DIR manifests
RUN initializer --permissive
CMD ["registry-server", "-t", "/tmp/terminate.log"]
EOF

docker build -f $DOCKERFILE_REGISTRY --tag "${REGISTRY_IMG}:${operator_channel}-latest" .

# TODO : Test the image and the version it contains