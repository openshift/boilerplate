#!/bin/bash
set -euo pipefail

GOLANGCI_LINT_VERSION="1.30.0"
DEPENDENCY=${1:-}

case "${DEPENDENCY}" in
    golangci-lint)
        GOPATH=$(go env GOPATH)
        if [ ! -f "${GOPATH}/bin/golangci-lint" ]; then
            DOWNLOAD_URL="https://github.com/golangci/golangci-lint/releases/download/v${GOLANGCI_LINT_VERSION}/golangci-lint-${GOLANGCI_LINT_VERSION}-linux-amd64.tar.gz"
            curl -sfL "${DOWNLOAD_URL}" | tar -C "${GOPATH}/bin" -zx --strip-components=1 "golangci-lint-${GOLANGCI_LINT_VERSION}-linux-amd64/golangci-lint"
        fi
    ;;
    *)
        echo "Unknown dependency: ${DEPENDENCY}"
        exit 1
    ;;
esac
