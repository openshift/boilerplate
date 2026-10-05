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

Pass the desired architectures through `build-platforms` and enable the image
index, for example:

```yaml
spec:
  params:
    - name: build-platforms
      value:
        - linux/amd64
        - linux/arm64
    - name: build-image-index
      value: 'true'
```

`build-platform` defaults to `linux/amd64` and selects the platform used by
post-build tasks that inspect the built image.
