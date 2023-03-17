# Project specific values
OPERATOR_NAME=$(sed -n 's/.*OperatorName .*"\([^"]*\)".*/\1/p' config/config.go)
OPERATOR_NAMESPACE=$(sed -n 's/.*OperatorNamespace .*"\([^"]*\)".*/\1/p' config/config.go)

#Test Specific values
TEST_IMAGE?='quay.io/openshift/origin-tools:latest'
