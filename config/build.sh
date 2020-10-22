#!/bin/bash
set -x
set -euo pipefail

tmpd=$(mktemp -d)
pushd $tmpd

GOCILINT_VERSION="1.31.0"
GOCILINT_SHA256SUM="9a5d47b51442d68b718af4c7350f4406cdc087e2236a5b9ae52f37aebede6cb3"
GOCILINT_LOCATION=https://github.com/golangci/golangci-lint/releases/download/v${GOCILINT_VERSION}/golangci-lint-${GOCILINT_VERSION}-linux-amd64.tar.gz

OPERATOR_SDK_VERSION="0.16.0"
OPERATOR_SDK_SHA256SUM="3df782f341749f7962ab0fcfedd2961c18b21ad34ff7acd194b49a152f59abcb"
OPERATOR_SDK_LOCATION=https://github.com/operator-framework/operator-sdk/releases/download/v${OPERATOR_SDK_VERSION}/operator-sdk-v${OPERATOR_SDK_VERSION}-x86_64-linux-gnu

OPM_VERSION="1.13.8"
OPM_SHASUM="a48aa9d69b0be3439220e818edde4b36b3b9eceb2a058d86b4fdf0ca9dcd21c8"
OPM_LOCATION=https://github.com/operator-framework/operator-registry/releases/download/v${OPM_VERSION}/linux-amd64-opm

curl -L -o golangci-lint.tar.gz $GOCILINT_LOCATION
echo ${GOCILINT_SHA256SUM} golangci-lint.tar.gz | sha256sum -c
tar xzf golangci-lint.tar.gz golangci-lint-${GOCILINT_VERSION}-linux-amd64/golangci-lint
mv golangci-lint-${GOCILINT_VERSION}-linux-amd64/golangci-lint /usr/local/bin

curl -L -o operator-sdk $OPERATOR_SDK_LOCATION
echo ${OPERATOR_SDK_SHA256SUM} operator-sdk | sha256sum -c
chmod ugo+x operator-sdk
mv operator-sdk /usr/local/bin

curl -L -o opm $OPM_LOCATION && \
echo ${OPM_SHASUM} opm | sha256sum -c
chmod ugo+x opm
mv opm /usr/local/bin

python3 -m pip install PyYAML==5.3.1

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
yum clean all
yum -y autoremove

# autoremove removes ssh (which it presumably wouldn't if we were able
# to install git from a repository, because git has a dep on ssh.)
# Do we care to restrict this to a particular version?
yum -y install openssh-clients

rm -rf /var/cache/yum

popd
rm -fr $tmpd
