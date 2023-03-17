# Conventions for progressive delivery tests


## Updating the acceptance-test.yaml file

This convention is used to create the `acceptance-test.yaml` file for our project.

## Copying the file to the /hack/test directory

To update the `acceptance-test.yaml` file, we will copy over a file into the `/hack/test` directory. This file contains the acceptance test specifications that we want to use in our progressive delivery pipelines.
The file is located in the `boilerplate/openshift/golang-osd-operator-acceptance-test` directory.
Once the file is copied over, the variables in the file need to be updated to match the project's specifications defined in the config/config.go file.

## Two MR process in Gitlab

After onboarding the acceptance tests, a two-merge request (MR) process needs to happen in Gitlab to consume this new test in our progressive delivery pipelines. This file will be created in this path: [saas-test](https://gitlab.cee.redhat.com/service/app-interface/-/tree/master/data/services/osd-operators/cicd/saas/tests)

## First MR

The first MR is used to create a new file in the `saas-test` directory. The file will be named after the project's name.
Inside of each namespace, which corresponds to the hive environment, a resourceTemplate will be created. These resourceTemplates will consume the `publish` channel in the core olm-artifact templates. An initial example can be found [here](https://gitlab.cee.redhat.com/service/app-interface/-/commit/d9e74f7b89407be6d0736cba0aad06f5c87d1877)
In this MR the new Publish channel can also be created.

## Second MR

The second MR is used to update the olm-artifact template to consume the publish channel from the saas-test file. An example of this can be found [here](https://gitlab.cee.redhat.com/service/app-interface/-/commit/8a775b050621a7435bc343c3eddcc2e4ae6229a5)