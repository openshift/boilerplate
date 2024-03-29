#!/usr/bin/env bash

set -v

# Global vars
CONTAINER_ENGINE=$(command -v podman || command -v docker)
CONTAINER_ENGINE_SHORT=${CONTAINER_ENGINE##*/}
REPO_ROOT=$(git rev-parse --show-toplevel)
VERSIONS_DIR=${REPO_ROOT}/versions
SKOPEO_IMAGE="quay.io/skopeo/stable:v1.14.2"

source $REPO_ROOT/boilerplate/_lib/common.sh

function usage() {
    cat <<EOF
    Usage: $0 REGISTRY_IMAGE_URI
    REGISTRY_IMAGE_URI is the complete image URI that needs to be built
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
  echo "building catalog image..."

  # preserve logging output from command by duplicating the file descriptor
  exec 5>&1
  BUILD=$(${opm_local_executable} index add \
    --bundles ${bundle_image} \
    --tag ${image_tag} \
    --container-tool ${CONTAINER_ENGINE_SHORT} 2>&1 | tee /dev/fd/5; exit ${PIPESTATUS[0]})
  RC=$?
  ERR_COUNT=$(echo "$BUILD" | grep -c 'replaces nonexistent bundle')
    
  if [[ ${RC} > 0 ]] && [[ ${ERR_COUNT} == 0 ]]; then
    echo "adding bundle failed"
    exit 1
  fi
  
  if [[ ${ERR_COUNT} > 0 ]]; then
    echo "adding bundle failed -- bundle specifies a non-existent replacement"
    echo "re-attempting by using the previous catalog image as the index"
    
    # grab the latest catalog image tag using skopeo in a container as the os level one is too old
    # this value is needed as an arg to --from-index
    CATALOG_LATEST_TAG=$(jq -r '.Tags[-1]' < <(${CONTAINER_ENGINE} run ${SKOPEO_IMAGE} -- skopeo list-tags docker://${BASE_IMAGE_PATH}))
    if [[ ${?} > 0 ]]; then 
      echo "skopeo failed to fetch the latest image tag"
      echo "error: $CATALOG_LATEST_TAG"
      exit 1
    fi

    ${opm_local_executable} index add \
      --bundles ${bundle_image} \
      --tag ${image_tag} \
      --container-tool ${CONTAINER_ENGINE_SHORT} \
      --from-index "${BASE_IMAGE_PATH}:${CATALOG_LATEST_TAG}"

    if [[ ${?} > 0 ]]; then
      echo "building from index failed"
      exit 1
    fi
  fi
}

[[ $# -eq 1 ]] || usage

REGISTRY_IMAGE_URI=$1
BASE_IMAGE_PATH=${REGISTRY_IMAGE_URI%:*}

if image_exists_in_repo "${REGISTRY_IMAGE_URI}"; then
  echo "Custom catalog image for the latest operator version already exists in the registry"
  echo "Nothing to do here"
  exit 0
else
  for f in ${VERSIONS_DIR}/*;
  do
    bundle_image=$( cat ${f} | jq -r .bundle_image )
    build_catalog_image ${bundle_image} ${REGISTRY_IMAGE_URI}
    if [[ ${?} == 0 ]]; then
      echo "pushing image"
      cd ${REPO_ROOT}
      make docker-push-catalog
    else
      echo "failed to build catalog image"
      exit 1
    fi
  done
fi
