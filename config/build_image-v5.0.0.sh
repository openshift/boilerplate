#!/usr/bin/env bash

# This script comprises everything up to and including the boilerplate
# backing image at version image-v4.0.0. It is used when performing a
# full build in the appsre pipeline, but is bypassed during presubmit CI
# in prow to make testing faster there. As such, there is a (very small)
# possibility of those behaving slightly differently.

# Compatible with Operator-SDK v1.25.0+ which first supported Go 1.19
# https://github.com/operator-framework/operator-sdk/releases/tag/v1.25.0

set -x
set -euo pipefail

tmpd=$(mktemp -d)
pushd $tmpd

# OCP's release images explicitly set -mod=vendor
export GOFLAGS=-mod=mod

###########
# kustomize
###########
KUSTOMIZE_VERSION="v5.4.1"
go install sigs.k8s.io/kustomize/kustomize/${KUSTOMIZE_VERSION%%.*}@${KUSTOMIZE_VERSION}

################
# controller-gen
################
CONTROLLER_GEN_VERSION="v0.15.0"
go install sigs.k8s.io/controller-tools/cmd/controller-gen@${CONTROLLER_GEN_VERSION}

#############
# openapi-gen
#############
OPENAPI_GEN_VERSION="v0.29.1"
go install k8s.io/code-generator/cmd/openapi-gen@${OPENAPI_GEN_VERSION}

#########
# ENVTEST
#########
# Latest is only compatible with Go 1.22
# https://github.com/kubernetes-sigs/controller-runtime/issues/2744
ENVTEST_VERSION="release-0.18"
go install sigs.k8s.io/controller-runtime/tools/setup-envtest@${ENVTEST_VERSION}

##############
# govulncheck
##############
GOVULNCHECK_VERSION="v1.1.2"
go install golang.org/x/vuln/cmd/govulncheck@${GOVULNCHECK_VERSION}

#########
# mockgen
#########
MOCKGEN_VERSION="v0.4.0"
go install go.uber.org/mock/mockgen@${MOCKGEN_VERSION}

####
# yq
####
YQ_VERSION="v4.44.2"
go install github.com/mikefarah/yq/v4@${YQ_VERSION}

# HACK: `go get` creates lots of things under GOPATH that are not group
# accessible, even if umask is set properly. This causes failures of
# subsequent go tool usage (e.g. resolving packages) by a non-root user,
# which is what consumes this image in CI.
# Here we make group permissions match user permissions, since the CI
# non-root user's gid is 0.
dir=$(go env GOPATH)
for bit in r x w; do
    find $dir -perm -u+${bit} -a ! -perm -g+${bit} -exec chmod g+${bit} '{}' +
done

###############
# golangci-lint
###############
GOCILINT_VERSION="1.59.1"
GOCILINT_SHA256SUM="c30696f1292cff8778a495400745f0f9c0406a3f38d8bb12cef48d599f6c7791"
GOCILINT_LOCATION=https://github.com/golangci/golangci-lint/releases/download/v${GOCILINT_VERSION}/golangci-lint-${GOCILINT_VERSION}-linux-amd64.tar.gz

curl -L -o golangci-lint.tar.gz $GOCILINT_LOCATION
echo ${GOCILINT_SHA256SUM} golangci-lint.tar.gz | sha256sum -c
tar xzf golangci-lint.tar.gz golangci-lint-${GOCILINT_VERSION}-linux-amd64/golangci-lint
mv golangci-lint-${GOCILINT_VERSION}-linux-amd64/golangci-lint /usr/local/bin
rm -f golangci-lint.tar.gz

####
# gh
####
GH_VERSION="2.51.0"
GH_SHA256SUM="d7725fb2a643ca024edf5b4e2f2cca0431a404bbc2e251086ffca2b25e37be11"
GH_LOCATION=https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_amd64.tar.gz

curl -L -o gh.tar.gz $GH_LOCATION
echo ${GH_SHA256SUM} gh.tar.gz | sha256sum -c
tar xzf gh.tar.gz gh_${GH_VERSION}_linux_amd64/bin/gh
mv gh_${GH_VERSION}_linux_amd64/bin/gh /usr/local/bin
rm -f gh.tar.gz

#####
# dnf
#####
# autoremove removes ssh (which it presumably wouldn't if we were able
# to install git from a repository, because git has a dep on ssh.)
# Do we care to restrict this to a particular version?
dnf -y install openssh-clients jq skopeo python3-pyyaml
dnf clean all
dnf -y autoremove
rm -rf /var/cache/dnf

popd
rm -fr $tmpd
