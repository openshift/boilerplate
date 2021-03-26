# CSV generation and catalog image management

## Scope

The `csv-generate` teagets are covering the historical artifact build for operators to get deployed by OLM : 
- Generate the CSV (based on python script)
- Generate the catalog image embeding the newly build CSV
- Push the generated artifacts to `saas-bundle` gitlab repository (2 branches : `staging` and `production`)
- Push the catalog images to the registry 


## Defined targets


## Migration guide

For existing operator, you can use the `make build-publish-version` target which will generate and push all artifacts for both `staging` and `production`.
By default, it will continue using the `hack/generate-operator-bundle.py` from your project.
If you want to use the boilerplate version, you only need to override the Makefile variable (through a `project.mk` for example): 

```
DEFAULT_CSV_GENRATOR=common
```

Supported values are either `common` or `hack`.

### Specificities for the `common` CSV Generator
For the common generator, the management of the versioning has been removed from the generation script and is now managed through Makefile variables. 
Format of operators versioning is `X.Y.<commit_count>-<commit_sha>`. 
The X and Y digit can be overriden the same way as `DEFAULT_CSV_GENRATOR`.

```
VERSION_MAJOR=2
VERSION_MINOR=1
```

### CSV compare 

To ease the migration to the common script, a dedicated target has been implemented in order to allow to easily compare the currently generated CSV (expected to be generated with the `hack` scipt) with the common script CSV. 
It requires to be generated in that order to allow custom-versioning of the CSV (as the version calculation is made internally for the historical `hack` script). 

In case of successful comparison, output should be something similar to : 

```
No diff found between 'common' script output and 'hack' script
```

### Migration guide for 'common' CSV generator

For the migration, symlink may more convenient than `mv` or `cp` of the files (allowing to keep a single source but both `hack` and `common` generator working properly).

1. The CSV template (located in `config/templates`) should be called `csv-template.yaml ` 
2. The CRDs to be embedded in the CSV should be placed in `deploy/crds` repository
3. The roles to be embedded in the CSV should be placed in `deploy/roles` repository