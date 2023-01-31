# Conventions for OSD operators written in Go

- [Conventions for OSD operators written in Go](#conventions-for-osd-operators-written-in-go)
  - [`make` targets and functions.](#make-targets-and-functions)
    - [Prow](#prow)
      - [Local Testing](#local-testing)
    - [app-sre](#app-sre)
    - [E2E Test Harness](#e2e-test-harness)
      - [Local Testing](#e2e-harness-local-testing) 
  - [Code coverage](#code-coverage)
  - [Linting and other static analysis with `golangci-lint`](#linting-and-other-static-analysis-with-golangci-lint)
  - [Checks on generated code](#checks-on-generated-code)

This convention is suitable for both cluster- and hive-deployed operators.

The following components are included:

## `make` targets and functions.

**Note:** Your repository's main `Makefile` needs to be edited to include the
"nexus makefile include":

```
include boilerplate/generated-includes.mk
```

One of the primary purposes of these `make` targets is to allow you to
standardize your prow and app-sre pipeline configurations using the
following:

### Prow

| Test name / `make` target | Purpose                                                                                                         |
| ------------------------- | --------------------------------------------------------------------------------------------------------------- |
| `validate`                | Ensure code generation has not been forgotten; and ensure generated and boilerplate code has not been modified. |
| `lint`                    | Perform static analysis.                                                                                        |
| `test`                    | "Local" unit and functional testing.                                                                            |
| `coverage`                | [Code coverage](#code-coverage) analysis and reporting.                                                         |

To standardize your prow configuration, you may run:

```shell
$ make prow-config
```

If you already have the openshift/release repository cloned locally, you
may specify its path via `$RELEASE_CLONE`:

```shell
$ make RELEASE_CLONE=/home/me/github/openshift/release prow-config
```

This will generate a delta configuring prow to:

- Build your `build/Dockerfile`.
- Run the above targets in presubmit tests.
- Run the `coverage` target in a postsubmit. This is the step that
  updates your coverage report in codecov.io.

#### Local Testing

You can run these `make` targets locally during development to test your
code changes. However, differences in platforms and environments may
lead to unpredictable results. Therefore boilerplate provides a utility
to run targets in a container environment that is designed to be as
similar as possible to CI:

```shell
$ make container-{target}
```

or

```shell
$ ./boilerplate/_lib/container-make {target}
```

### app-sre

The `build-push` target builds and pushes the operator and OLM registry images,
ready to be SaaS-deployed.
By default it is configured to be run from the app-sre jenkins pipelines.
Consult [this doc](app-sre.md) for information on local execution/testing.

### E2e Test Harness

| `make` target      | Purpose                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
|--------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `e2e-harness-generate` | Generate scaffolding for end to end test harness. Creates osde2e/ directory where tests reside. The harness has access to cloud client and addon passthrough secrets within the cluster. Add your operated related ginkgo e2e tests under the `osde2e/tests/<operator-name>_tests.go` file. See [this README](https://github.com/openshift/osde2e-example-test-harness/blob/main/README.md#locally-running-this-example) for more details on test harness. |
| `e2e-harness-build`| Compiles ginkgo tests under osde2e/tests and creates the binary to be used by docker image used by osde2e.                                                                                                                                                                                                                                                                                                                                                 |
| `e2e-image-build-push` | Builds osde2e test harness image and pushes to operator's quay repo. Image name is defaulted to <operator-image-name>-test-harness. Quay repository must be created beforehand.                                                                                                                                                                                                                                                                            |

#### E2E Harness Local Testing

Please follow [this README](https://github.com/openshift/osde2e-example-test-harness/blob/main/README.md#locally-running-this-example) to test your e2e harness with Osde2e locally

## Code coverage

- A `codecov.sh` script, referenced by the `coverage` `make` target, to
  run code coverage analysis per [this SOP](https://github.com/openshift/ops-sop/blob/93d100347746ce04ad552591136818f82043c648/services/codecov.md).

- A `.codecov.yml` configuration file for
  [codecov.io](https://docs.codecov.io/docs/codecov-yaml). Note that
  this is copied into the repository root, because that's
  [where codecov.io expects it](https://docs.codecov.io/docs/codecov-yaml#can-i-name-the-file-codecovyml).

## Linting and other static analysis with `golangci-lint`

- A `go-check` `make` target, which
- ensures the proper version of `golangci-lint` is installed, and
- runs it against
- a `golangci.yml` config.
- a `GOLANGCI_OPTIONAL_CONFIG` config if it is defined and file exists

## Checks on generated code

The convention embeds default checks to ensure generated code generation is current, committed, and unaltered.
To trigger the check, you can use `make generate-check` provided your Makefile properly includes the boilerplate-generated include `boilerplate/generated-includes.mk`.

Checks consist of:

- Checking all files are committed to ensure a safe point to revert to in case of error
- Running the `make generate` command (see below) to regenerate the needed code
- Checking if this results in any new uncommitted files in the git project or if all is clean.

`make generate` does the following:

- generate crds and deepcopy via controller-gen. This is a no-op if your
  operator has no APIs.
- `openapi-gen`. This is a no-op if your operator has no APIs.
- `go generate`. This is a no-op if you have no `//go:generate`
  directives in your code.

## FIPS (Federal Information Processing Standards)

To enable FIPS in your build there is a `make ensure-fips` target.

Add `FIPS_ENABLED=true` to your repos Makefile. Please ensure that this variable is added **before** including boilerplate Makefiles.

e.g.

```.mk
FIPS_ENABLED=true

include boilerplate/generated-includes.mk
```

`ensure-fips` will add a [fips.go](./fips.go) file in the same directory as the `main.go` file. (Please commit this file as normal)

`fips.go` will import the necessary packages to restrict all TLS configuration to FIPS-approved settings.

With `FIPS_ENABLED=true`, `ensure-fips` is always run before `make go-build`


