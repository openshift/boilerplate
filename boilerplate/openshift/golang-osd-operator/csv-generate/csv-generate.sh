#!/bin/bash -x

usage() { echo "Usage: $0 -o operator_name -i operator_image -c saas-repository-channel [-t]" 1>&2; exit 1; }

while getopts "c:i:o:p:n:h:t" option; do
    case "${option}" in
        c)
            operator_channel=${OPTARG}
            ;;
        i)
            operator_image=${OPTARG}
            ;;
        o)
            operator_name=${OPTARG}
            ;;
        p)
            operator_previous_version=${OPTARG}
            ;;
        n)
            operator_commit_number=${OPTARG}
            ;;
        h)
            operator_commit_hash=${OPTARG}
            ;;
        t)
            test_boilerplate_generation=true
            ;;
        *)
            usage
    esac
done

# Checking parameters
unset csv_missing_param_error

if [ -z "operator_channel" ] ; then 
    echo "Missing operator_channel parameter"
    csv_missing_param_error = true
fi

if [ -z "operator_image" ] ; then 
    echo "Missing operator_image parameter"
    csv_missing_param_error = true
fi

if [ -z "operator_name" ] ; then 
    echo "Missing operator_name parameter"
    csv_missing_param_error = true
fi

if [ -z "operator_previous_version" ] ; then 
    echo "Missing operator_previous_version parameter"
    csv_missing_param_error = true
fi

if [ -z "operator_commit_number" ] ; then 
    echo "Missing operator_commit_number parameter"
    csv_missing_param_error = true
fi

if [ ! -z "$csv_missing_param_error" ] ; then
    usage
    exit 1
fi


# Testing variable
#GIT_PATH="https://app:@gitlab.cee.redhat.com/service/saas-${operator_name}-bundle.git"
GIT_PATH="/Users/bdematte/git/fake/saas-file-generate-bundle"

# Calculate previous version
SAAS_OPERATOR_DIR="saas-${operator_name}-bundle"
BUNDLE_DIR="$SAAS_OPERATOR_DIR/${operator_name}/"

if [ "$test_boilerplate_generation" = true ] ; then
    OPERATOR_NEW_VERSION=$(ls "$BUNDLE_DIR" | sort -t . -k 3 -g | tail -n 1)
    OPERATOR_PREV_VERSION=$(ls "${BUNDLE_DIR}" | sort -t . -k 3 -g | tail -n 2 | head -n 1)
    # Generate with boilerplate generator
    ./boilerplate/openshift/golang-osd-operator/csv-generate/common-generate-operator-bundle.py -o ${operator_name} -d output-comparison -p ${OPERATOR_PREV_VERSION} -n ${operator_commit_number} -c ${operator_commit_hash} -i ${operator_image}
    echo "CSV generated with boilerplate generate-bundle script"
    # Preparing yamls for the diff by removing the creation timestamp
    yq d ${BUNDLE_DIR}/${OPERATOR_NEW_VERSION}/*.clusterserviceversion.yaml 'metadata.annotations.createdAt' > output-comparison/hack_generate.yaml
    yq d output-comparison/${OPERATOR_NEW_VERSION}/*.clusterserviceversion.yaml 'metadata.annotations.createdAt' > output-comparison/common_generate.yaml
    # Diff on the filtered files
    diff output-comparison/hack_generate.yaml output-comparison/common_generate.yaml
else
    rm -rf "$SAAS_OPERATOR_DIR"
    git clone --branch "$operator_channel" ${GIT_PATH} "$SAAS_OPERATOR_DIR"
    OPERATOR_PREV_VERSION=$(ls "$BUNDLE_DIR" | sort -t . -k 3 -g | tail -n 1)
    # CSV actual generate
    ./hack/generate-operator-bundle.py -o ${operator_name} -d ${BUNDLE_DIR} -p ${OPERATOR_PREV_VERSION} -n ${operator_commit_number} -c ${operator_commit_hash} -i ${operator_image}
    echo "CSV generated with project generate-bundle script"
fi