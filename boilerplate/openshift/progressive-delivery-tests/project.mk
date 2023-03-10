# Project specific values
OPERATOR_NAME?=$(shell sed -n '/name: REPO_NAME/,/value:/p' ./hack/olm-registry/olm-artifacts-template.yaml | sed -n 's/.*value: \(.*\)/\1/p;')
NAMESPACE?=$(shell sed -n '/kind: Namespace/,/name:/p' ./hack/olm-registry/olm-artifacts-template.yaml | sed '$d' | sed -n 's/.*name: \(.*\)/\1/p;')

# app-interface values
JOB_NAME?=$(shell echo "placeholder")
SERVICE_ACCOUNT?=$(shell echo "placeholder")

#Test Specific values
TEST_IMAGE?='quay.io/openshift/origin-tools:latest'
