# Defaults to -mod=vendor in the boilerplate image
unexport GOFLAGS

# GOLANGCI_LINT_CACHE needs to be set to a directory which is writeable
# Relevant issue - https://github.com/golangci/golangci-lint/issues/734
GOLANGCI_LINT_CACHE ?= /tmp/golangci-cache
GOLANGCI_OPTIONAL_CONFIG ?=

LINT_CONVENTION_DIR := boilerplate/openshift/golang-lint

# lint: Perform static analysis.
.PHONY: lint
lint: 
	${LINT_CONVENTION_DIR}/ensure.sh golangci-lint
	GOLANGCI_LINT_CACHE=${GOLANGCI_LINT_CACHE} golangci-lint run -c ${LINT_CONVENTION_DIR}/golangci.yml ./...
	test "${GOLANGCI_OPTIONAL_CONFIG}" = "" || test ! -e "${GOLANGCI_OPTIONAL_CONFIG}" || GOLANGCI_LINT_CACHE="${GOLANGCI_LINT_CACHE}" golangci-lint run -c "${GOLANGCI_OPTIONAL_CONFIG}" ./...

