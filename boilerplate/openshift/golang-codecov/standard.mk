GOOS?=$(shell go env GOOS)
GOARCH?=$(shell go env GOARCH)

unexport GOFLAGS
GOFLAGS_MOD ?=

# Optionally use alternate GOCACHE location if default is not writeable
CACHE_WRITEABLE := $(shell test -w "${HOME}/.cache" && echo yes || echo no)
ifeq ($(CACHE_WRITEABLE),no)
tmpDir := $(shell mktemp -d)
GOENV+=GOCACHE=${tmpDir}
$(info Using custom GOCACHE of ${tmpDir})
endif

GOENV+=GOOS=${GOOS} GOARCH=${GOARCH} CGO_ENABLED=0 GOFLAGS=${GOFLAGS_MOD}

CODECOV_CONVENTION_DIR := boilerplate/openshift/golang-codecov

ifeq ($(origin TESTTARGETS), undefined)
TESTTARGETS := $(shell ${GOENV} go list -e ./... | grep -E -v "/(vendor)/")
endif
# ex, -v
TESTOPTS :=

# coverage: Code coverage analysis and reporting.
.PHONY: coverage
coverage:
	${CODECOV_CONVENTION_DIR}/codecov.sh

.PHONY: go-test
go-test:
	${GOENV} go test $(TESTOPTS) $(TESTTARGETS)
