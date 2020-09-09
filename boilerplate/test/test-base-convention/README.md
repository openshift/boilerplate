# Basic test convention

The following components are included:

## `make` targets and functions.
**Note:** Your repository's main `Makefile` needs to be edited to include these libraries.

## Code coverage
- A `codecov.sh` script, referenced by the `coverage` `make` target, to
run code coverage analysis per [this SOP](https://github.com/openshift/ops-sop/blob/ff297220d1a6ac5d3199d242a1b55f0d4c433b87/services/codecov.md).

- A `.codecov.yml` configuration file for
  [codecov.io](https://docs.codecov.io/docs/codecov-yaml). Note that
  this is copied into the repository root, because that's
  [where codecov.io expects it](https://docs.codecov.io/docs/codecov-yaml#can-i-name-the-file-codecovyml).

## Linting with `gofmt`

A `golint.sh`, referenced by the `gocheck` `make` target, to use `gofmt`
with the configuration found here (currently the default).

## Testing of sub-directories

This convention contains a directory to ensure all data are properly deployed.
