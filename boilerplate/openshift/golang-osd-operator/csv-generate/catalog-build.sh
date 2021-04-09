#!/bin/bash -e

source `dirname $0`/common.sh

usage() { echo "Usage: $0 -o operator-name -c saas-repository-channel -r registry-image" 1>&2; exit 1; }

while getopts "o:c:r:" option; do
    case "${option}" in
        o)
            operator_name=${OPTARG}
            ;;
        c)
            operator_channel=${OPTARG}
            ;;
        r)
            # NOTE: This is the URL without the tag/digest
            registry_image=${OPTARG}
            ;;
        *)
            usage
    esac
done

# Checking parameters
check_mandatory_params operator_channel operator_name  

# Parameters for the Dockerfile
SAAS_OPERATOR_DIR="saas-${operator_name}-bundle"
DOCKERFILE_REGISTRY="Dockerfile.olm-registry"

# Checking SAAS_OPERATOR_DIR exist
if [ ! -d "${SAAS_OPERATOR_DIR}/.git" ] ; then
    echo "${SAAS_OPERATOR_DIR} should exist and be a git repository"
    exit 1
fi

cat <<EOF > $DOCKERFILE_REGISTRY
FROM quay.io/openshift/origin-operator-registry:4.7.0
COPY $SAAS_OPERATOR_DIR manifests
RUN initializer --permissive
CMD ["registry-server", "-t", "/tmp/terminate.log"]
EOF

docker build -f $DOCKERFILE_REGISTRY --tag "${registry_image}:${operator_channel}-latest" .

if [ $? -ne 0 ] ; then 
    echo "docker build failed, exiting..."
    exit 1
fi

# TODO : Test the image and the version it contains
