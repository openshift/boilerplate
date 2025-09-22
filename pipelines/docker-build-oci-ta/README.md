# Centralized Docker Build Pipeline

This directory contains a centralized Tekton pipeline for building container
images with OCI trusted artifacts support.

## What it does

Builds container images using the `docker-build-oci-ta` pipeline that is
automatically applied through the `golang-osd-operator` convention to
centralize management. This allows updates to be handled in the boilerplate
repository and ensures all repositories are using the same pipeline definition.

## How it's used

Boilerplate automatically updates `.tekton/` pipeline files to reference this
centralized pipeline instead of maintaining inline pipeline specifications.

### Before (inline pipeline):
```yaml
spec:
  pipelineSpec:
    # hundreds of lines of pipeline definition...
```

### After (centralized):
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
        value: pipelines/docker-build-oci-ta/pipeline.yaml
```

### References

- https://konflux.pages.redhat.com/docs/users/patterns/centralize-pipeline-definitions.html
