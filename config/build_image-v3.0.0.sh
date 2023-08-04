#!/usr/bin/env bash

# This script comprises everything up to and including the boilerplate
# backing image at version image-v3.0.0. It is used when performing a
# full build in the appsre pipeline, but is bypassed during presubmit CI
# in prow to make testing faster there. As such, there is a (very small)
# possibility of those behaving slightly differently.

# Compatible with Operator-SDK v1.25.0+ which first supported Go 1.19
# https://github.com/operator-framework/operator-sdk/releases/tag/v1.25.0

set -x
set -euo pipefail

tmpd=$(mktemp -d)
pushd $tmpd

###############
# golangci-lint
###############
GOCILINT_VERSION="1.50.0"
GOCILINT_SHA256SUM="b4b329efcd913082c87d0e9606711ecb57415b5e6ddf233fde9e76c69d9b4e8b"
GOCILINT_LOCATION=https://github.com/golangci/golangci-lint/releases/download/v${GOCILINT_VERSION}/golangci-lint-${GOCILINT_VERSION}-linux-amd64.tar.gz

curl -L -o golangci-lint.tar.gz $GOCILINT_LOCATION
echo ${GOCILINT_SHA256SUM} golangci-lint.tar.gz | sha256sum -c
tar xzf golangci-lint.tar.gz golangci-lint-${GOCILINT_VERSION}-linux-amd64/golangci-lint
mv golangci-lint-${GOCILINT_VERSION}-linux-amd64/golangci-lint /usr/local/bin

###############
# Set up go env
###############
# Get rid of -mod=vendor
unset GOFLAGS
# No, really, we want to use modules
export GO111MODULE=on

# print go version for fun
go version

###########
# kustomize
###########
KUSTOMIZE_VERSION=v4.5.5
go install sigs.k8s.io/kustomize/kustomize/${KUSTOMIZE_VERSION%%.*}@${KUSTOMIZE_VERSION}

################
# controller-gen
################
# controller-gen v0.10.0 is used by operator-sdk v1.25.0
CONTROLLER_GEN_VERSION="v0.10.0"
go install sigs.k8s.io/controller-tools/cmd/controller-gen@${CONTROLLER_GEN_VERSION}

#############
# openapi-gen
#############
OPENAPI_GEN_VERSION="v0.23.0"
go install k8s.io/code-generator/cmd/openapi-gen@${OPENAPI_GEN_VERSION}

#########
# ENVTEST
#########
# We do not enforce versioning on setup-envtest
go install sigs.k8s.io/controller-runtime/tools/setup-envtest@latest

##############
# govulncheck
##############
GOVULNCHECK_VERSION=v1.0.0
go install golang.org/x/vuln/cmd/govulncheck@${GOVULNCHECK_VERSION}

#########
# mockgen
#########
MOCKGEN_VERSION=v1.6.0
go install github.com/golang/mock/mockgen@${MOCKGEN_VERSION}

############
# go-bindata
############
GO_BINDATA_VERSION=v3.1.2
go install github.com/go-bindata/go-bindata/...@${GO_BINDATA_VERSION}

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

####
# yq
####
YQ_VERSION="3.4.1"
YQ_SHA256SUM="adbc6dd027607718ac74ceac15f74115ac1f3caef68babfb73246929d4ffb23c"
YQ_LOCATION=https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64

curl -L -o yq $YQ_LOCATION
echo ${YQ_SHA256SUM} yq | sha256sum -c
chmod ugo+x yq
mv yq /usr/local/bin

####
# gh
####
GH_VERSION=2.19.0
GH_SHA256SUM="b1d062f1c0d44465e4f9f12521e93e9b3b650d3876eb157acf875347b971f4d8"
GH_LOCATION=https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_amd64.tar.gz

curl -L -o gh.tar.gz $GH_LOCATION
echo ${GH_SHA256SUM} gh.tar.gz | sha256sum -c
tar -xvzf gh.tar.gz gh_${GH_VERSION}_linux_amd64/bin/gh
mv gh_${GH_VERSION}_linux_amd64/bin/gh /usr/local/bin

##################
# python libraries
##################
python3 -m pip install PyYAML==5.3.1

#########
# cleanup
#########
yum clean all
yum -y autoremove

# autoremove removes ssh (which it presumably wouldn't if we were able
# to install git from a repository, because git has a dep on ssh.)
# Do we care to restrict this to a particular version?
yum -y install openssh-clients jq skopeo

rm -rf /var/cache/yum

popd
rm -fr $tmpd
