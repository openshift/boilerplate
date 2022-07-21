#!/usr/bin/env bash

set -v

# Global vars
CONTAINER_ENGINE=$(command -v podman || command -v docker)
CONTAINER_ENGINE_SHORT=${CONTAINER_ENGINE##*/}
REPO_ROOT=$(git rev-parse --show-toplevel)
VERSIONS_DIR=${REPO_ROOT}/versions

source $REPO_ROOT/boilerplate/_lib/common.sh

function usage() {
    cat <<EOF
    Usage: $0 REGISTRY_IMAGE_URI BASE_IMAGE_PATH
    REGISTRY_IMAGE_URI is the complete image URI that needs to be built
    BASE_IMAGE_PATH is the base URI path in the contaienr registry (ie. quay.io/app-sre/image)
EOF
    exit -1
}

function build_catalog_image() {
  local bundle_image=${1}
  local image_tag=${2}
  local opm_local_executable=${REPO_ROOT}/.opm/bin/opm

  # install opm binary
  if ! [[ -x ${opm_local_executable} ]]; then
    echo "opm binary not found, either install it manually or run 'make install-opm' "
    exit 1
  fi

  ${CONTAINER_ENGINE} pull ${bundle_image}
  # some upstream bundles images are built specifying a "replaces" field, which means it builds on top of the 
  # previous minor version. we need to check if the build fails for that reason and use another method
  echo "testing build..."
  BUILD=$(${opm_local_executable} index add --bundles ${bundle_image} --tag ${image_tag} --container-tool ${CONTAINER_ENGINE_SHORT} 2>&1)
  ERR_COUNT=$(echo $BUILD | grep -c 'non-existent replacement')
  
  # Dump output of build since its stderr and won't show for to variable capture to work
  echo -e "\n$BUILD\n"

  if [[ ${ERR_COUNT} > 0 ]]; then 
    echo "adding bundle failed -- bundle specifies a non-existent replacement"
    echo "re-attempting by using the previous catalog image as the index"
    
    # grab the latest catalog image tag to use as an arg to --from-index
    CATALOG_LATEST_TAG=$(skopeo list-tags docker://${BASE_IMAGE_PATH} | jq -r '.Tags[-1]')
    ${opm_local_executable} index add \
      --bundles ${bundle_image} \
      --tag ${image_tag} \
      --container-tool ${CONTAINER_ENGINE_SHORT} \
      --from-index "${BASE_IMAGE_PATH}:${CATALOG_LATEST_TAG}"
  fi
}

[[ $# -eq 2 ]] || usage

REGISTRY_IMAGE_URI=$1
BASE_IMAGE_PATH=$2

if image_exists_in_repo "${REGISTRY_IMAGE_URI}"; then
  echo "Custom catalog image for the latest operator version already exists in the registry"
  echo "Nothing to do here"
else
  for f in ${VERSIONS_DIR}/*;
  do
    bundle_image=$( cat ${f} | jq -r .bundle_image )
    build_catalog_image ${bundle_image} ${REGISTRY_IMAGE_URI} ${BASE_IMAGE_PATH}
    if [[ ${?} == 0 ]]; then
      echo "pushing image"
      cd ${REPO_ROOT}
      make docker-push-catalog
    else
      echo "building from index failed"
      exit 1
    fi
  done
fi

