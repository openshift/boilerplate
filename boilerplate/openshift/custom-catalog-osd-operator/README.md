# Conventions for mirroring operatorhub operators using custom catalog source

- [Overview](#overview)
  - [make targets](#make-targets)
    - [app-sre](#app-sre)
      - [`update-versions-push`](#update-versions-push)
      - [`build-push`](#build-push)
  - [Summary of scripts](#summary-of-scripts)
    - [`current-version-getter.sh`](#current-version-gettersh)
    - [`app-sre-build-deploy.sh`](#app-sre-build-deploysh)
  - [Workflow](#workflow)

## Overview
`custom-catalog-osd-operator` is a convention which contains the required scripts to mirror upstream operatorhub catalog sources to be able to control the version of the operators easily in a fleet of openshift clusters.

### make targets
#### app-sre
This convention relies on app-sre jenkins pipelines to run the build and version update jobs. It contains two make targets to perform each of the functions

##### `update-versions-commit`
Updates the version file in `${REPO_ROOT}/versions` with the latest operator version available in operatorhub. Invokes `current-version-getter.sh`. You can use the make target `update-versions` if you want to test the version update without committing the changes.

##### `catalog-build-push`
Builds the mirrored catalog source image using [opm](https://github.com/operator-framework/operator-registry#building-an-index-of-operators-using-opm) and pushes to quay. This image is used to deploy the custom catalog source. The operator's subscription points to this catalog source to install the operator using Operator Lifecycle Manager (OLM). Invokes `app-sre-build-deploy.sh`

### Summary of scripts
This section briefly describes the two scripts present in this boilerplate convention:

#### `current-version-getter.sh`
* This script queries the [Pyxis API](https://pyxis.engineering.redhat.com/v1/ui/) to compare the latest version available in the given channel upstream and the operator version recorded in the version file.
* If it finds a newer version, it updates the version file with the latest version and respective bundle image URI.
* Invoked using `make update-versions` or `make update-versions-commit`.
#### `app-sre-build-deploy.sh`
* This script is invoked by app-interface after a merge into the master branch. Invoked by `make catalog-build-push`
* It builds the custom catalog image by reading information from the file under the `versions` dir

### Workflow
* The app-interface job runs every week and calls `make update-versions` which should update the version files if a new version is available.
* If a new version is available, the job should commit to master which should trigger the automated build job (`make catalog-build-push`). This should build and push the newer version of the catalog image to quay.io, ready to be used by OSD clusters.
* Depending on app-interface configuration, SREP can choose to either automatically update the operator versions fleet wide as a result of the new version available or manually promote the new version using the same method used to promote SREP maintained operators.
