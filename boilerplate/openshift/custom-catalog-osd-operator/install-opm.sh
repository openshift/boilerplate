#!/usr/bin/env bash

# global envs
OPM_VERSION="v1.15.2"
GOOS=$(go env GOOS)
REPO_ROOT=$(git rev-parse --show-toplevel)

# install opm binary if it does not exist
if ! which opm >/dev/null 2>&1; then
  echo "installing opm-binary as it is not installed already"
  mkdir -p .opm/bin
  cd .opm/bin
  opm="opm-${OPM_VERSION}-$GOOS-amd64"
  opm_download_url="https://github.com/operator-framework/operator-registry/releases/download/${OPM_VERSION}/${GOOS}-amd64-opm"
  curl -sfL "${opm_download_url}" -o "$opm"
  chmod +x "$opm"
  ln -fs "$opm" opm
  echo "installed in ${REPO_ROOT}/.opm/bin/opm"
else
  echo "Nothing to do, opm already installed"
fi