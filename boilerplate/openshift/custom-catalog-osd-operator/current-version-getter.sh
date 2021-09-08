#!/usr/bin/env bash

REPO_ROOT=$(git rev-parse --show-toplevel)
OPERATOR_NAME=$(basename ${REPO_ROOT}  | sed 's/-catalog//')
CERT_DIR="${REPO_ROOT}/service-account/rhcs-request"
CERT_FILE_NAME="custom-catalog-source-index-builder"
PYXIS_ENDPOINT="https://pyxis.engineering.redhat.com"
VERSIONS_DIR="${REPO_ROOT}/versions"


# compare_versions accepts two semvers.
# Its return value indicates how they compare:
# 0: the semvers are equal
# 1: the first semver is newer
# 2: the second semver is newer
compare_versions() {
    [[ $1 == $2 ]] && return 0
    local older=$(printf "$1\n$2\n" | sort -V | head -1)
    [[ $older == $2 ]] && return 1
    return 2
}

function update_latest_version() {
  # perform the API request
  local channel_name=${1}
  local version_in_repo=${2}
  local version_file=${3}

  local available_operator_versions=$(curl -X GET --key ${CERT_DIR}/${CERT_FILE_NAME}.key --cert ${CERT_DIR}/${CERT_FILE_NAME}.crt \
    "${PYXIS_ENDPOINT}/v1/operators/bundles?page_size=100&organization=redhat-operators&filter=package==${OPERATOR_NAME};in_index_img==true;channel_name==${channel_name}" | \
    jq -r "[.data[] | {bundle_image: .bundle_path, operator_version: .version, channel_name: .channel_name, operator_name: .package }]" )

    jq -c '.[]' <<< ${available_operator_versions} | while read i; do
      local upstream_operator_version=$( jq -r .operator_version <<< "${i}" )
      
      compare_versions ${upstream_operator_version} ${version_in_repo}
      if [[ $? == 1 ]]; then
        echo "Found newer version upstream: ${upstream_operator_version}"
        echo ${i} |jq > ${version_file}
        # This will make sure we end up with the latest available version
        version_in_repo=${upstream_operator_version}
      fi
    done
}

function create_cert_dir_files() {
  mkdir -p ${CERT_DIR}
  if [[ -z "${PYXIS_CERT}" || -z "${PYXIS_KEY}" ]]; then
    echo "Red hat certificates required for Pyxis API not found. Please set PYXIS_CERT & PYXIS_KEY with appropriate values and try again"
    exit 1
  fi
  # Write cert files to disk for API calls
  echo "${PYXIS_CERT}" > ${CERT_DIR}/${CERT_FILE_NAME}.crt
  echo "${PYXIS_KEY}" > ${CERT_DIR}/${CERT_FILE_NAME}.key

  # Remove the cert files from the disk if being written from env variables
  trap "rm -fr ${CERT_DIR}" EXIT
}

function channel_exists_in_repo() {
  local upstream_channel=${1}
  for  f in ${VERSIONS_DIR}/* 
  do
    channel_name=$( cat ${f} | jq -r '.channel_name' )
    if [[ ${channel_name} == ${upstream_channel} ]]; then
      # found
      return 0
    fi
  done
  # Not Found
  return 1
}

function update_version_files() {
  # For each major channel version, figure out the latest operator version
  for  f in ${VERSIONS_DIR}/* 
  do
    channel_name=$( cat ${f} | jq -r '.channel_name' )
    version=$(cat ${f} | jq -r '.operator_version')
    update_latest_version ${channel_name} ${version} ${f}
  done
}

function commit_version_file_changes() {
  local latest_operator_version=''
  local version_file=''
  if [[ -n $(git diff --name-only ${VERSIONS_DIR}) ]]; then
    if [[ $(git diff --name-only ${VERSIONS_DIR}| wc -l) != '1' ]]; then
      echo "More than one version file change detected, aborting"
      exit 1
    fi
    version_file=$( git diff --name-only ${VERSIONS_DIR})
    latest_operator_version=$(cat ${version_file} | jq -r '.operator_version')

    # prepare for app-sre jenkins push
    git add ${version_file}
    git commit -m "Moving to the newer operator version: ${latest_operator_version}"
  else
    echo "no updates to version file, nothing to do."
  fi
}

function create_missing_version_files() {
  # If a version file for a channel doesnt exist, create it

  available_operator_versions=$(curl -X GET --key ${CERT_DIR}/${CERT_FILE_NAME}.key --cert ${CERT_DIR}/${CERT_FILE_NAME}.crt \
      "${PYXIS_ENDPOINT}/v1/operators/bundles?page_size=100&organization=redhat-operators&filter=package==${OPERATOR_NAME};in_index_img==true" | \
      jq -r "[.data[] | {bundle_image: .bundle_path, operator_version: .version, channel_name: .channel_name, operator_name: .package }]" )

  jq -c '.[]' <<< ${available_operator_versions} | while read i; do
    upstream_channel=$( jq -r .channel_name <<< "${i}" )
    if ! channel_exists_in_repo ${upstream_channel}; then
      # write file to repo, as the channle doesnt exist in versions dir
      operator_name=$( jq -r .operator_name <<< "$i" )
      echo "Missing channel found creating version file for ${upstream_channel}"
      echo ${i} | jq > ${VERSIONS_DIR}/${operator_name}.${upstream_channel}.json
    fi
  done
}

function print_usage() {
  echo "Usage: ..."
  echo " This script requires you to provide certs in a ${CERT_DIR}/${CERT_FILE_NAME}.crt/.key or set the following env variables:"
  echo "     \$PYXIS_CERT - Cert file for the Pyxis API set as environment variable"
  echo "     \$PYXIS_KEY - Cert key file set as environment variable"
  echo "  $0 [options]"
  echo "    options:"
  echo "       -g   search for new channels and create versions files for each if not present"
  echo "       -d   provide the directory where version files are stored, default is ${VERSIONS_DIR}."
  echo "       -p   git commit version file changes, if present"
}

### Main

create_missing_files_flag='false'
version_dir=''
files=''
verbose='false'
git_commit='false'

while getopts 'gpd:' flag; do
  case "${flag}" in
    g) create_missing_files_flag='true' ;;
    d) version_dir="${OPTARG}" ;;
    p) git_commit='true' ;;
    *) print_usage
       exit 1 ;;
  esac
done

# only create new version files if -g flag is set
if [[ ${create_missing_files_flag} == "true" ]]; then
  create_missing_version_files
fi

# if 'versions' directory is passed in, use that
if [[ ${version_dir} ]]; then
  VERSIONS_DIR=${version_dir}
fi

if [[ ! -f ${CERT_DIR}/${CERT_FILE_NAME}.crt || ! -f ${CERT_DIR}/${CERT_FILE_NAME}.key ]]; then
  echo "default cert directory ${CERT_DIR} not found, creating..."
  create_cert_dir_files
fi

# update version files if a new operator version is available in the given channel
update_version_files

# if -p is set, stage and commit 
if [[ ${git_commit} == "true" ]]; then
  commit_version_file_changes
fi
