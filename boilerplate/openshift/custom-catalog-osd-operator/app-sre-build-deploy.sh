#!/usr/bin/env bash

set -ev

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
  local opm_local_executable

  # install opm binary if it does not exist
  if which opm; then
      opm_local_executable=$(realpath $(which opm))
  else
    mkdir -p .opm/bin
    cd .opm/bin
    opm="opm-${OPM_VERSION}-$GOOS-amd64"
    opm_download_url="https://github.com/operator-framework/operator-registry/releases/download/${OPM_VERSION}/${GOOS}-amd64-opm"
    curl -sfL "${opm_download_url}" -o "$opm"
    chmod +x "$opm"
    opm_local_executable=${REPO_ROOT}/.opm/bin/opm
    ln -fs "$opm" opm
  fi

  ${CONTAINER_ENGINE} pull ${bundle_image}
  ${opm_local_executable} index add --bundles ${bundle_image} --tag ${image_tag} \
    --container-tool ${CONTAINER_ENGINE_SHORT}

}

CONTAINER_ENGINE=$(command -v podman || command -v docker)
CONTAINER_ENGINE_SHORT=${CONTAINER_ENGINE##*/}
REPO_ROOT=$(git rev-parse --show-toplevel)
VERSIONS_DIR=${REPO_ROOT}/versions
OPM_VERSION="v1.15.2"
GOOS=$(go env GOOS)
source $REPO_ROOT/boilerplate/_lib/common.sh

[[ $# -eq 1 ]] || usage

REGISTRY_IMAGE_URI=$1

if image_exists_in_repo "${REGISTRY_IMAGE_URI}"; then
  echo "Custom catalog image for the latest operator version already exists in the reigstry"
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

