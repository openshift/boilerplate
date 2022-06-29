# Conventions for OSD operators written in Go

- [Linting and other static analysis with `golangci-lint`](#linting-and-other-static-analysis-with-golangci-lint)

| `make` target | Purpose                                                                                                             |
|---------------|-----------------------------------------------------------------------------------------------------------------    |
| `lint`        | Perform static analysis.                                                                                            |


## Linting and other static analysis with `golangci-lint`

- A `lint` `make` target, which
- ensures the proper version of `golangci-lint` is installed, and
- runs it against
- a `golangci.yml` config.
- a `GOLANGCI_OPTIONAL_CONFIG` config if it is defined and file exists

