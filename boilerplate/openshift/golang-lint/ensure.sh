#!/usr/bin/env bash
set -x
set -eo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel)
source $REPO_ROOT/boilerplate/_lib/common.sh

GOLANGCI_LINT_VERSION="2.0.2"
DEPENDENCY=${1:-}
GOOS=$(go env GOOS)

case "${DEPENDENCY}" in

golangci-lint)
    GOPATH=$(go env GOPATH)
    if which golangci-lint ; then
        exit
    else
        mkdir -p "${GOPATH}/bin"
        if ! echo "${PATH}" | grep -q "${GOPATH}/bin"; then
            echo "${GOPATH}/bin not in $PATH"
            exit 1
        fi
        DOWNLOAD_URL="https://github.com/golangci/golangci-lint/releases/download/v${GOLANGCI_LINT_VERSION}/golangci-lint-${GOLANGCI_LINT_VERSION}-${GOOS}-amd64.tar.gz"
        curl -sfL "${DOWNLOAD_URL}" | tar -C "${GOPATH}/bin" -zx --strip-components=1 "golangci-lint-${GOLANGCI_LINT_VERSION}-${GOOS}-amd64/golangci-lint"
    fi
    ;;

*)
    echo "Unknown dependency: ${DEPENDENCY}"
    exit 1
    ;;
esac
