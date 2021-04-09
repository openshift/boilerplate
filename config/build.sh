#!/bin/bash
set -x
set -euo pipefail

yum install -y skopeo

rm -rf /var/cache/yum
