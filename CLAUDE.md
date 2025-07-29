# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is the OpenShift Boilerplate repository, which provides standardized development infrastructure and tooling to be used across repositories in an organization. The principle is to **copy** standardized artifacts from this repository into consuming repositories (rather than pulling them dynamically), allowing consumers to update on demand with explicit curation of changes.

## Architecture

The repository is organized into several key areas:

### Conventions Structure
- **`boilerplate/openshift/`** - Contains OpenShift-specific conventions
  - `golang-osd-operator/` - Standards for Go-based OSD operators (most common)
  - `golang-codecov/` - Code coverage tooling
  - `golang-lint/` - Linting configuration
  - `golang-osd-e2e/` - End-to-end testing framework
  - `osd-container-image/` - Container image standards
  - `custom-catalog-osd-operator/` - Custom catalog building

### Core Infrastructure
- **`boilerplate/_lib/`** - Shared utilities and scripts used by conventions
- **`boilerplate/update`** - Main update script that consumers use to pull in changes
- **`subscribers.yaml`** - Registry of consuming repositories
- **`test/`** - Test framework for validating boilerplate functionality
- **`pipelines/`** - Konflux CI/CD pipeline definitions

### Key Files
- Each convention includes:
  - `standard.mk` - Standard Makefile targets and variables
  - `project.mk` - Project-specific configuration template
  - `update` script - Pre/post processing during updates
  - `README.md` - Convention documentation

## Common Development Tasks

### Testing
```bash
# Run all tests (must be on clean git repo)
make test

# Run tests in container environment  
make container-pr-check

# Run specific test case
make test CASE_GLOB="pattern"

# Check repository is clean
make isclean
```

### Development Workflow
```bash
# Build container image from local checkout
make build-image-deep

# Generate subscriber reports
make subscriber-report

# Standard CI checks
make pr-check
```

### Working with Conventions

When modifying or creating conventions:

1. **Structure**: Each convention lives in `boilerplate/openshift/{convention-name}/`
2. **Files**: Include `standard.mk`, `README.md`, and optionally an `update` script
3. **Update Script**: Must accept `PRE` or `POST` arguments for pre/post file copy processing
4. **Variables**: The update framework exports `REPO_ROOT`, `REPO_NAME`, `CONVENTION_ROOT`, `LATEST_IMAGE_TAG`

### Container Engine Support
The repository supports both Docker and Podman. The `CONTAINER_ENGINE` variable is automatically detected but can be overridden.

### Release Process
For changes to the build image (`config/Dockerfile`):
1. Create semver tag: `image-v{X}.{Y}.{Z}`
2. Update Konflux `ReleasePlanAdmission` resource
3. Create `Release` resource in Konflux
4. Update Prow mirroring configuration

## Environment Variables

Key environment variables for testing:
- `BOILERPLATE_GIT_REPO` - Override git repo location for local testing
- `BOILERPLATE_GIT_CLONE` - Override clone command (useful for local development)
- `ALLOW_DIRTY_CHECKOUT` - Allow operations on dirty git checkout
- `CASE_GLOB` - Pattern for test case selection

## Integration Points

This repository integrates with:
- **Prow** - CI/CD platform for OpenShift
- **Konflux** - Build and release pipeline platform  
- **GitHub** - Source control and issue tracking
- **Subscriber repositories** - Consuming projects that use boilerplate conventions

The subscriber system allows automated updates to be proposed across multiple consuming repositories simultaneously using the `subscriber propose update` command.