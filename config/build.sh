#!/usr/bin/env bash

# This script builds on build_image-v1.0.0.sh

set -x
set -euo pipefail

# We no longer support operator-sdk < 0.16. Remove binaries to save
# space.
rm -f /usr/local/bin/operator-sdk-v0.15.1-x86_64-linux-gnu

exit 0
