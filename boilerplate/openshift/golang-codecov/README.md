# Conventions for code coverage for our Golang projects

- [Code coverage](#code-coverage)

### Prow

| `make` target | Purpose                                                                                                             |
|---------------|-----------------------------------------------------------------------------------------------------------------    |
| `test`        | "Local" unit and functional testing.                                                                                |
| `coverage`    | [Code coverage](#code-coverage) analysis and reporting.                                                             |


## Code coverage
- A `codecov.sh` script, referenced by the `coverage` `make` target, to
run code coverage analysis per [this SOP](https://github.com/openshift/ops-sop/blob/8e48d0c1e8d9f2f5a19b1e18cdf5f08f658eb184/services/codecov.md).

- A `.codecov.yml` configuration file for
  [codecov.io](https://docs.codecov.io/docs/codecov-yaml). Note that
  this is copied into the repository root, because that's
  [where codecov.io expects it](https://docs.codecov.io/docs/codecov-yaml#can-i-name-the-file-codecovyml).

