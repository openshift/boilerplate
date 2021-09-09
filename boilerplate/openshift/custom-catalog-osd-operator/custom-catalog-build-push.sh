#!/usr/bin/env bash

set -ev

# Global vars
CONTAINER_ENGINE=$(command -v podman || command -v docker)
CONTAINER_ENGINE_SHORT=${CONTAINER_ENGINE##*/}
REPO_ROOT=$(git rev-parse --show-toplevel)
VERSIONS_DIR=${REPO_ROOT}/versions

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
  ${opm_local_executable} index add --bundles ${bundle_image} --tag ${image_tag} \
    --container-tool ${CONTAINER_ENGINE_SHORT}

}

[[ $# -eq 1 ]] || usage

REGISTRY_IMAGE_URI=$1

if image_exists_in_repo "${REGISTRY_IMAGE_URI}"; then
  echo "Custom catalog image for the latest operator version already exists in the registry"
  echo "Nothing to do here"
else
  for f in ${VERSIONS_DIR}/*;
  do
    bundle_image=$( cat ${f} | jq -r .bundle_image )
    build_catalog_image ${bundle_image} ${REGISTRY_IMAGE_URI}
    if [[ ${?} == 0 ]]; then
      echo "pushing image"
      cd ${REPO_ROOT}
      make docker-push-catalog
    fi
  done
fi

