# golang-osd-operator-precheck

Generates operator pre-check tests that validate operator readiness before e2e tests run.

## What it does

The convention copies a pre-check implementation file and generates a Ginkgo `BeforeSuite` hook into the operator's `test/e2e/` directory. Before any tests execute, it:

1. **Version matching** (if `OPERATOR_EXPECTED_VERSION` env var is set):
   - Checks PKO (ClusterPackage) first, falls back to OLM (CSV)
   - Validates the deployed version matches the expected version
2. **Health checks** (always):
   - Verifies the operator namespace exists
   - Verifies all deployments in the namespace have all replicas available

Polls every 5 seconds with a 10-minute timeout. If the operator is not ready after 10 minutes, the `BeforeSuite` fails and **all tests in the suite are skipped**.

All pre-check code is self-contained — no external library imports beyond standard Kubernetes client libraries that operators already depend on.

## Prerequisites

This convention requires `openshift/golang-osd-e2e` to also be subscribed (it provides the test runner and build targets).

## Subscribing

Add to `boilerplate/update.cfg`:

```
openshift/golang-osd-operator
openshift/golang-osd-e2e
openshift/golang-osd-operator-precheck
```

Run `make boilerplate-update`, then `GOFLAGS="-tags=osde2e" go mod tidy` to pull in any missing dependencies (`operator-framework/api`, `package-operator.run/apis`).

## Generated files

| File | Description |
|------|-------------|
| `test/e2e/operator_precheck.go` | Pre-check implementation (always overwritten) |
| `test/e2e/{operator}_precheck_test.go` | BeforeSuite wrapper with operator name and namespace (always overwritten) |

## Environment variables

| Variable | Description |
|----------|-------------|
| `OPERATOR_EXPECTED_VERSION` | Expected operator version tag (e.g., `v0.1.459-g3fa5c0d`). If unset or `latest`, version matching is skipped and only health checks run. |
| `KUBECONFIG` | Path to kubeconfig for local testing. When running inside a cluster pod (no KUBECONFIG set), in-cluster config is used automatically. |

## Important: BeforeSuite constraint

This convention generates a `ginkgo.BeforeSuite(...)` in the `{operator}_precheck_test.go` file. Ginkgo allows **only one `BeforeSuite` per test package**. If two files in the same package both declare a `BeforeSuite`, the test binary will panic at runtime.

This means **your operator's e2e tests must not define their own `BeforeSuite`**. If you need setup logic that runs before tests, use one of these alternatives instead:

- `ginkgo.BeforeAll(func() { ... })` inside a `ginkgo.Describe` or `ginkgo.Ordered` block — runs once before the specs in that block
- `ginkgo.BeforeEach(func() { ... })` inside a `ginkgo.Describe` block — runs before each spec

If you need additional setup logic that applies to the entire suite (e.g., initializing a shared cluster client), you can add it directly to the generated `{operator}_precheck_test.go`'s `BeforeSuite` — but note that this file is **overwritten on every `make boilerplate-update`**. For persistent additions, open a PR against the boilerplate convention to extend the shared `BeforeSuite` so all operators benefit.

The update script checks for existing `BeforeSuite` declarations and will print a warning if a conflict is detected.
