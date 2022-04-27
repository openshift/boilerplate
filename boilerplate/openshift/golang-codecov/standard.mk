GOOS?=$(shell go env GOOS)
GOARCH?=$(shell go env GOARCH)

unexport GOFLAGS
GOFLAGS_MOD ?=

GOENV=GOOS=${GOOS} GOARCH=${GOARCH} CGO_ENABLED=0 GOFLAGS=${GOFLAGS_MOD}

CODECOV_CONVENTION_DIR := boilerplate/openshift/golang-codecov

ifeq ($(origin TESTTARGETS), undefined)
TESTTARGETS := $(shell ${GOENV} go list -e ./... | egrep -v "/(vendor)/")
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
