# Centralized Multi-Platform Docker Build Pipeline

This directory contains a multi-platform variant of the centralized
`docker-build-oci-ta` pipeline.

## What it does

The pipeline builds each platform listed in `build-platforms` with
`buildah-remote-oci-ta`, then combines the platform-specific image references
into an OCI image index. Existing image checks run against the index, and the
pipeline can optionally create a source image.

The Konflux multi-platform controller must be deployed and configured for the
requested platforms: [multi-platform controller](https://github.com/konflux-ci/multi-platform-controller).

## How to use

Reference this pipeline from a `PipelineRun` with the Git resolver:

```yaml
spec:
  pipelineRef:
    resolver: git
    params:
      - name: url
        value: https://github.com/openshift/boilerplate
      - name: revision
        value: master
      - name: pathInRepo
        value: pipelines/docker-build-multi-platform-oci-ta/pipeline.yaml
```

By default, the pipeline builds `linux/amd64` and `linux/arm64` and creates an
OCI image index. A `PipelineRun` can omit both parameters. Override
`build-platforms` when targeting a different set of architectures or
`build-image-index` when an index is not needed.

For an AMD64-only build, override the platform list:

```yaml
spec:
  params:
    - name: build-platforms
      value:
        - linux/amd64
```

`build-platform` defaults to `linux/amd64` and selects the platform used by
post-build tasks that inspect the built image.
