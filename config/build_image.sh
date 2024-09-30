#!/usr/bin/env bash

# boilerplate v5.0.1
# Go 1.22

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
YQ_SHA256SUM=e4c2570249e3993e33ffa44e592b5eee8545bd807bfbeb596c2986d86cb6c85c
YQ_LOCATION=https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64.tar.gz
curl -LO ${YQ_LOCATION}
echo ${YQ_SHA256SUM} yq_linux_amd64.tar.gz | sha256sum -c
tar xvf yq_linux_amd64.tar.gz ./yq_linux_amd64
mv yq_linux_amd64 /usr/local/bin/yq
rm -f yq_linux_amd64.tar.gz

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
GH_VERSION="2.57.0"
GH_SHA256SUM="d6b3621aa0ca383866716fc664d827a21bd1ac4a918a10c047121d8031892bf8"
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
