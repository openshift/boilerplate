# Defaults to -mod=vendor in the boilerplate image
unexport GOFLAGS

# Optionally use alternate GOCACHE location if default is not writeable
CACHE_WRITEABLE := $(shell test -w "${HOME}/.cache" && echo yes || echo no)
ifeq ($(CACHE_WRITEABLE),no)
tmpDir := $(shell mktemp -d)
GOENV+=GOCACHE=${tmpDir}
$(info Using custom GOCACHE of ${tmpDir})
endif

# GOLANGCI_LINT_CACHE needs to be set to a directory which is writeable
# Relevant issue - https://github.com/golangci/golangci-lint/issues/734
GOLANGCI_LINT_CACHE ?= /tmp/golangci-cache
GOLANGCI_OPTIONAL_CONFIG ?=

LINT_CONVENTION_DIR := boilerplate/openshift/golang-lint

# lint: Perform static analysis.
.PHONY: lint
lint: 
	${LINT_CONVENTION_DIR}/ensure.sh golangci-lint
	${GOENV} GOLANGCI_LINT_CACHE=${GOLANGCI_LINT_CACHE} golangci-lint run -c ${LINT_CONVENTION_DIR}/golangci.yml ./...
	test "${GOLANGCI_OPTIONAL_CONFIG}" = "" || test ! -e "${GOLANGCI_OPTIONAL_CONFIG}" || ${GOENV} GOLANGCI_LINT_CACHE="${GOLANGCI_LINT_CACHE}" golangci-lint run -c "${GOLANGCI_OPTIONAL_CONFIG}" ./...

