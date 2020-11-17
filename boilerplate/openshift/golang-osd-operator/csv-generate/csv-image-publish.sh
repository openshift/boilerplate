#!/bin/bash

usage() { echo "Usage: $0 -o operator_name -i operator_image -c saas-repository-channel [-t]" 1>&2; exit 1; }

while getopts "o:h:c:t" option; do
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

# Testing variable
#GIT_PATH="https://app:@gitlab.cee.redhat.com/service/saas-${operator_name}-bundle.git"
GIT_PATH="/Users/bdematte/git/fake/saas-file-generate-bundle"

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

# push image
skopeo copy --dest-creds "${QUAY_USER}:${QUAY_TOKEN}" \
    "docker-daemon:${REGISTRY_IMG}:${operator_channel}-latest" \
    "docker://${REGISTRY_IMG}:${operator_channel}-latest"

skopeo copy --dest-creds "${QUAY_USER}:${QUAY_TOKEN}" \
    "docker-daemon:${REGISTRY_IMG}:${operator_channel}-latest" \
    "docker://${REGISTRY_IMG}:${operator_channel}-${operator_commit_hash}"