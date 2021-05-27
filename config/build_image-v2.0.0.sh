#!/usr/bin/env bash

# This script comprises everything up to and including the boilerplate
# backing image at version image-v2.0.0. It is used when performing a
# full build in the appsre pipeline, but is bypassed during presubmit CI
# in prow to make testing faster there. As such, there is a (very small)
# possibility of those behaving slightly differently.

set -x
set -euo pipefail

tmpd=$(mktemp -d)
pushd $tmpd

###############
# golangci-lint
###############
GOCILINT_VERSION="1.31.0"
GOCILINT_SHA256SUM="9a5d47b51442d68b718af4c7350f4406cdc087e2236a5b9ae52f37aebede6cb3"
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

###########
# kustomize
###########
KUSTOMIZE_VERSION=v3.8.8
go get sigs.k8s.io/kustomize/kustomize/v3@${KUSTOMIZE_VERSION}

################
# controller-gen
################
CONTROLLER_GEN_VERSION=v0.3.0
go get sigs.k8s.io/controller-tools/cmd/controller-gen@${CONTROLLER_GEN_VERSION}

#############
# openapi-gen
#############
OPENAPI_GEN_VERSION=v0.19.4
go get k8s.io/code-generator/cmd/openapi-gen@${OPENAPI_GEN_VERSION}

#########
# mockgen
#########
MOCKGEN_VERSION=v1.4.4
go get github.com/golang/mock/mockgen@${MOCKGEN_VERSION}

############
# go-bindata
############
GO_BINDATA_VERSION=v3.1.2
go get github.com/go-bindata/go-bindata/...@${GO_BINDATA_VERSION}

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

##################
# python libraries
##################
python3 -m pip install PyYAML==5.3.1

#####
# git
#####
# Per https://git-scm.com/download/linux, we have two choices for CentOS
# (which is what we're running on):
# - Build from source
# - Use a third party repository
# For security reasons, we're preferring the former.
GIT_VERSION="2.28.0"
GIT_SHASUM="02016d16dbce553699db5c9c04f6d13a3f50727c652061b7eb97a828d045e534"
GIT_DEPENDENCIES="epel-release perl-CPAN gettext-devel perl-devel openssl-devel zlib-devel curl-devel expat-devel getopt asciidoc xmlto docbook2X"
yum remove -y git*
yum -y install ${GIT_DEPENDENCIES}
yum -y groupinstall "Development Tools"
curl -L -o git.tar.gz https://github.com/git/git/archive/v${GIT_VERSION}.tar.gz
echo "${GIT_SHASUM}" git.tar.gz | sha256sum -c
tar xzf git.tar.gz
make --directory "git-${GIT_VERSION}" configure
./git-${GIT_VERSION}/configure --prefix=/usr
make --directory "git-${GIT_VERSION}" prefix=/usr/local all install
yum groupremove -y "Development Tools" && \
yum -y remove ${GIT_DEPENDENCIES}

#########
# cleanup
#########
yum clean all
yum -y autoremove

# autoremove removes ssh (which it presumably wouldn't if we were able
# to install git from a repository, because git has a dep on ssh.)
# Do we care to restrict this to a particular version?
yum -y install openssh-clients

rm -rf /var/cache/yum

popd
rm -fr $tmpd
