#!/bin/bash
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

##############
# operator-sdk
##############
# Install all the versions we support. ensure.sh is set up to find the
# one it needs.
declare -A OSDK_VERSION_HASHES
OSDK_VERSION_HASHES=(
    ['v0.15.1']="5c8c06bd8a0c47f359aa56f85fe4e3ee2066d4e51b60b75e131dec601b7b3cd6"
    ['v0.16.0']="3df782f341749f7962ab0fcfedd2961c18b21ad34ff7acd194b49a152f59abcb"
    ['v0.17.0']="f801a4a061c175fdb4875fbb021d4f8cae9c57cc1c00829ab2de4edf733e1963"
    ['v0.17.1']="9f6538beb15272d193e9e0d03678ef0f8aa3afd2f719a491fcc83abbb5cd28cf"
    ['v0.17.2']="4335d231c0733653ccab4e05623501a93367a459100d577cae1f2ed497b33708"
    ['v0.18.2']="40d35ea77b7b0cb5d2f88b97bb8c5b0684af4a54b9d7056790ecaa5e4a70a0d4"
)

for OPERATOR_SDK_VERSION in "${!OSDK_VERSION_HASHES[@]}"; do
    OPERATOR_SDK_SHA256SUM="${OSDK_VERSION_HASHES[$OPERATOR_SDK_VERSION]}"
    OPERATOR_SDK_BINARY=operator-sdk-${OPERATOR_SDK_VERSION}-x86_64-linux-gnu
    OPERATOR_SDK_LOCATION=https://github.com/operator-framework/operator-sdk/releases/download/${OPERATOR_SDK_VERSION}/$OPERATOR_SDK_BINARY
    curl -L -o $OPERATOR_SDK_BINARY $OPERATOR_SDK_LOCATION
    echo ${OPERATOR_SDK_SHA256SUM} $OPERATOR_SDK_BINARY | sha256sum -c
    chmod ugo+x $OPERATOR_SDK_BINARY
    mv $OPERATOR_SDK_BINARY /usr/local/bin
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
