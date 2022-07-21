#!/usr/bin/env bash

set -e

# global envs
OPM_VERSION="v1.23.2"
GOOS=$(go env GOOS)
REPO_ROOT=$(git rev-parse --show-toplevel)
OPM_LOCAL_EXECUTABLE_DIR=${REPO_ROOT}/.opm/bin
OPM_LOCAL_EXECUTABLE=${OPM_LOCAL_EXECUTABLE_DIR}/opm

# install opm binary if it does not exist. We force install to a specific opm version for
# consistency in case a newer version behaves differently
if ! [[ -x ${OPM_LOCAL_EXECUTABLE} ]]; then
  echo "installing opm-binary as it is not installed already"
  mkdir -p ${OPM_LOCAL_EXECUTABLE_DIR}
  cd ${OPM_LOCAL_EXECUTABLE_DIR}
  opm="opm-${OPM_VERSION}-$GOOS-amd64"
  opm_download_url="https://github.com/operator-framework/operator-registry/releases/download/${OPM_VERSION}/${GOOS}-amd64-opm"
  curl -sfL "${opm_download_url}" -o "$opm"
  chmod +x "$opm"
  ln -fs "$opm" opm
  echo "installed in ${OPM_LOCAL_EXECUTABLE}"
else
  echo "Nothing to do, opm already installed in ${OPM_LOCAL_EXECUTABLE_DIR}"
fi
