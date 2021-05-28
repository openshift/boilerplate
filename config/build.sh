#!/usr/bin/env bash

# This script builds on build_image-v2.0.0.sh

set -x
set -euo pipefail

####
# gh
####
GH_VERSION=1.10.3
GH_SHA256SUM="257c5bf641d85606337bc91c6507066a21ba6c849be50231b768fe2fd07517ea"
GH_LOCATION=https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_amd64.tar.gz

curl -L -o /tmp/gh.tgz $GH_LOCATION
echo ${GH_SHA256SUM} /tmp/gh.tgz | sha256sum -c
tar -xvzf /tmp/gh.tgz gh_${GH_VERSION}_linux_amd64/bin/gh
mv gh_${GH_VERSION}_linux_amd64/bin/gh /usr/local/bin

exit 0
