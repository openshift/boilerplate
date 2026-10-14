#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
CONVENTION_DIR="${REPO_ROOT}/boilerplate/openshift/golang-osd-operator"
PRE_V1_SDK_MANAGER_DIR="${REPO_ROOT}/cmd/manager"

if [[ -d "${PRE_V1_SDK_MANAGER_DIR}" ]]; then
  MAIN_DIR="${PRE_V1_SDK_MANAGER_DIR}"
else
  MAIN_DIR="${REPO_ROOT}"
fi

FIPS_FILE="${MAIN_DIR}/fips.go"
if [[ -e "${FIPS_FILE}" ]] && ! cmp -s "${FIPS_FILE}" "${CONVENTION_DIR}/fips.go.tmplt"; then
  echo "[ERROR] ${FIPS_FILE} exists and is not the current boilerplate FIPS template; refusing to overwrite it. Review or remove it before building with FIPS_ENABLED=true." >&2
  exit 1
fi

echo "Writing FIPS startup assertion to ${FIPS_FILE}"
cp "${CONVENTION_DIR}/fips.go.tmplt" "${FIPS_FILE}"
