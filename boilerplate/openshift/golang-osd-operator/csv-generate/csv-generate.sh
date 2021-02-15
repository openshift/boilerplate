#!/bin/bash -x

source `dirname $0`/common.sh

usage() { echo "Usage: $0 -o operator_name -c saas-repository-channel -H operator_commit_hash -n operator_commit_number -i operator_image -g {hack|common} [-d]" 1>&2; exit 1; }

# TODO : Add support of long-options 
while getopts "c:dg:H:i:n:o:" option; do
    case "${option}" in
        c)
            operator_channel=${OPTARG}
            ;;
        d)
            diff_generate=true
            ;;
        g)
            if [ "${OPTARG}" = "hack" ] || [ "${OPTARG}" = "common" ] ; then
                generate_script=${OPTARG}
            else
                # TODO : Case to be tested
                echo "Incorrect value for '-g'. Expecting 'hack' or 'common'. Got ${OPTARG}"
            fi
            ;;
        H)
            operator_commit_hash=${OPTARG}
            ;;
        i)
            operator_image=${OPTARG}
            ;;
        n)
            operator_commit_number=${OPTARG}
            ;;
        o)
            operator_name=${OPTARG}
            ;;
        *)
            usage
    esac
done

# Checking parameters
check_mandatory_params operator_channel operator_image operator_name operator_commit_hash operator_commit_number generate_script

# If no override, using the gitlab repo
if [ -z "$GIT_PATH" ] ; then 
    GIT_PATH="https://app:@gitlab.cee.redhat.com/service/saas-${operator_name}-bundle.git"
fi

# Calculate previous version
SAAS_OPERATOR_DIR="saas-${operator_name}-bundle"
BUNDLE_DIR="$SAAS_OPERATOR_DIR/${operator_name}/"

if [ "$diff_generate" = true ] ; then
    # For diff usecase, BUNDLE_DIR should already exist as first CSV is already built
    if [ ! -d ${BUNDLE_DIR} ] ; then
        echo "You need to generate CSV with your legacy script before trying to run the diff option"
        exit 1 
    fi
    
    OPERATOR_NEW_VERSION=$(basename `find "${BUNDLE_DIR}" -maxdepth 1 -type d | sort -t . -k 3 -V | tail -n 1 `)
    OPERATOR_PREV_VERSION=$(basename `find "${BUNDLE_DIR}" -maxdepth 1 -type d | sort -t . -k 3 -V | tail -n 2 | head -n 1 `)
    OUTPUT_DIR="output-comparison"
    
    # For diff usecase, checking there is already a generated CSV
    if [ ! -f ${BUNDLE_DIR}/${OPERATOR_NEW_VERSION}/*.clusterserviceversion.yaml ] ; then
        echo "You need to generate CSV with your legacy script before trying to run the diff option"
        exit 1 
    fi
else
    rm -rf "$SAAS_OPERATOR_DIR"
    git clone --branch "$operator_channel" ${GIT_PATH} "$SAAS_OPERATOR_DIR"
    
    # remove any versions more recent than deployed hash
    if [[ "$operator_channel" == "production" ]]; then
        if [ -z "$DEPLOYED_HASH" ] ; then
            DEPLOYED_HASH=$(
                curl -s "https://gitlab.cee.redhat.com/service/app-interface/raw/master/data/services/osd-operators/cicd/saas/saas-${_OPERATOR_NAME}.yaml" | \
                    docker run --rm -i quay.io/app-sre/yq yq r - "resourceTemplates[*].targets(namespace.\$ref==/services/osd-operators/namespaces/hivep01ue1/${_OPERATOR_NAME}.yml).ref"
            )
        fi
    
        delete=false
        # Sort based on commit number
        for version in $(ls $BUNDLE_DIR | sort -t . -k 3 -g); do
            # skip if not directory
            [ -d "$BUNDLE_DIR/$version" ] || continue
    
            if [[ "$delete" == false ]]; then
                short_hash=$(echo "$version" | cut -d- -f2)
    
                if [[ "$DEPLOYED_HASH" == "${short_hash}"* ]]; then
                    delete=true
                fi
            else
                rm -rf "${BUNDLE_DIR:?BUNDLE_DIR var not set}/$version"
            fi
        done
    fi

    # TODO : Clean handling of major version (should be variable from consumer repo and default to 0.1 is undefined)
    OUTPUT_DIR=${BUNDLE_DIR}
    OPERATOR_NEW_VERSION="${VERSION_BASE}.${operator_commit_number}-${operator_commit_hash}"
    OPERATOR_PREV_VERSION=`find "${BUNDLE_DIR}" -maxdepth 1 -type d | sort -t . -k 3 -V | tail -n 1  | grep -v 'file-generate/$'`
    if [ ! -z ${OPERATOR_PREV_VERSION} ] ; then
        OPERATOR_PREV_VERSION=`basename ${OPERATOR_PREV_VERSION}`
    fi
fi

if [[ "$generate_script" = "common" ]] ; then
    if [ -z "${OPERATOR_PREV_VERSION}" ] ; then
        PREVIOUS_VERSION_OPTION=""
    else
        PREVIOUS_VERSION_OPTION="-p ${OPERATOR_PREV_VERSION}"
    fi
    
    HERE=${0%/*}
    echo "$HERE/common-generate-operator-bundle.py -o ${operator_name} -d ${OUTPUT_DIR} ${PREVIOUS_VERSION_OPTION} -V ${OPERATOR_NEW_VERSION} -i ${operator_image}"
    
    $HERE/common-generate-operator-bundle.py -o ${operator_name} -d ${OUTPUT_DIR} ${PREVIOUS_VERSION_OPTION} -V ${OPERATOR_NEW_VERSION} -i ${operator_image}
elif [[ "$generate_script" = "hack" ]] ; then
    if [ -z "$OPERATOR_PREV_VERSION" ] ; then 
        OPERATOR_PREV_VERSION="no-version"
        DELETE_REPLACE=true
    fi
    
    ./hack/generate-operator-bundle.py ${OUTPUT_DIR} ${OPERATOR_PREV_VERSION} ${operator_commit_number} ${operator_commit_hash} ${operator_image}
    
    if [ ! -z "${DELETE_REPLACE}" ] ; then
        yq d -i output-comparison/${OPERATOR_NEW_VERSION}/*.clusterserviceversion.yaml 'spec.replaces'
    fi
fi

if [ "$diff_generate" = true ] ; then
    # TODO : Current hack script does not allow to generate the CSV for the comparison (it will generate a different version that the common one because there is 1 extra version in the history)
    if [[ "$generate_script" = "hack" ]] ; then
        echo "Generating with the common script and after, generating with the hack script is not supported yet. For comparison, please first generate with hack script, and then build/compare with the common script"
        exit 1
    # Preparing yamls for the diff by removing the creation timestamp
    elif [ -f ${BUNDLE_DIR}/${OPERATOR_NEW_VERSION}/*.clusterserviceversion.yaml ] ; then
        yq d ${BUNDLE_DIR}/${OPERATOR_NEW_VERSION}/*.clusterserviceversion.yaml 'metadata.annotations.createdAt' > output-comparison/hack_generate.yaml
        yq d output-comparison/${OPERATOR_NEW_VERSION}/*.clusterserviceversion.yaml 'metadata.annotations.createdAt' > output-comparison/common_generate.yaml
        # Diff on the filtered files
        diff output-comparison/hack_generate.yaml output-comparison/common_generate.yaml
        
        if [ $? -ne 0 ] ; then
            echo "Both (common and hack) scripts returned different content." && exit 1
        else
            echo "No diff found between 'common' script output and 'hack' script"
        fi
    fi
fi

