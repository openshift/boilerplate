#!/usr/bin/env bash
set -eo pipefail

###
# Run operator-sdk generate commands appropriate to the version of
# operator-sdk configured in the consuming repository.
###

REPO_ROOT=$(git rev-parse --show-toplevel)

source $REPO_ROOT/boilerplate/_lib/common.sh

# There's nothing to generate if pkg/apis is empty (other than apis.go).
# And instead of succeeding gracefully, `operator-sdk generate` will
# fail if you try. So do our own check.
if ! /bin/ls -1 pkg/apis | grep -Fqv apis.go; then
    echo "No APIs! Skipping operator-sdk generate."
    exit 0
fi

# Use the controller-gen provided by boilerplate:
CONTROLLER_GEN=$(which controller-gen)

VER_CONTROLLER=$($CONTROLLER_GEN --version | awk -F 'Version: ' '{ print $2}')
case $VER_CONTROLLER in
  'v0.3.0')
      # No-op
      ;;
  *) err "Unsupported controller-gen version $VER_CONTROLLER" ;;
esac

# Generate CRDs
(cd pkg/apis; $CONTROLLER_GEN crd paths=./aws/v1alpha1 output:dir=../../deploy/crds)

# Rename CRD filenames to _crd.yaml
for CRD in $(find ./deploy/crds -name '*.yaml'); do
  if ! ls "$CRD" | grep '_crd.yaml'; then
    FILENAME=$(echo "$CRD" | awk -F '.yaml' '{ print $1 }')
    NEW="${FILENAME}_crd.yaml"
    mv "$CRD" "$NEW"
  fi
done

# Fix format to comply with operator-sdk generate crd v0.16.0
find ./deploy/crds -name '*_crd.yaml' | xargs -n1 -I{} yq d -i {} 'metadata.annotations'
find ./deploy/crds -name '*_crd.yaml' | xargs -n1 -I{} yq d -i {} 'metadata.creationTimestamp'
find ./deploy/crds -name '*_crd.yaml' | xargs -n1 -I{} yq d -i {} 'status'
find ./deploy/crds -name '*_crd.yaml' | xargs -n1 -I{} yq d -i {} 'spec.validation.openAPIV3Schema.properties.status.properties.conditions.x-kubernetes-list-map-keys'
find ./deploy/crds -name '*_crd.yaml' | xargs -n1 -I{} yq d -i {} 'spec.validation.openAPIV3Schema.properties.status.properties.conditions.x-kubernetes-list-type'
find ./deploy/crds -name '*_crd.yaml' | xargs -n1 -I{} yq d -i {} 'spec.validation.openAPIV3Schema.properties.spec.properties.awsManagedPolicies.x-kubernetes-list-type'

"$HERE"/ensure.sh operator-sdk

# Symlink to operator-sdk binary set up by `ensure.sh operator-sdk`:
OSDK=$REPO_ROOT/.operator-sdk/bin/operator-sdk

VER=$(osdk_version $OSDK)

# This explicitly lists the versions we know about. We don't support
# anything outside of that.
# NOTE: We are gluing to CRD v1beta1 for the moment. Support for v1
# needs to be considered carefully in the context of
# - Hive v3 (which doesn't support v1)
# - When OCP will remove support for v1beta1 (currently we know it's
# deprecated in 4.6, but don't know when it's actually removed).
case $VER in
  'v0.15.1'|'v0.16.0')
      # No-op: just declare support for these osdk versions.
      ;;
  'v0.17.0'|'v0.17.1'|'v0.17.2'|'v0.18.2')
      # The --crd-version flag was introduced in 0.17. v1beta1 is the
      # default until 0.18, but let's be explicit.
      _osdk_generate_crds_flags='--crd-version v1beta1'
      ;;
  *) err "Unsupported operator-sdk version $VER" ;;
esac
$OSDK generate k8s
