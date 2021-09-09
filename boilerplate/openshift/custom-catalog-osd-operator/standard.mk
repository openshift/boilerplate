# Project specific values
REPO_NAME?=$(shell git config --get remote.origin.url | sed 's,.*/,,; s/\.git$///')

IMAGE_REGISTRY?=quay.io
IMAGE_REPOSITORY?=app-sre
IMAGE_NAME?=$(REPO_NAME)

REGISTRY_USER?=$(QUAY_USER)
REGISTRY_TOKEN?=$(QUAY_TOKEN)


# Accommodate docker or podman
CONTAINER_ENGINE=$(shell command -v podman 2>/dev/null || command -v docker 2>/dev/null)

# Generate version and tag information from inputs
CURRENT_COMMIT=$(shell git rev-parse --short=7 HEAD)

REGISTRY_IMAGE=$(IMAGE_REGISTRY)/$(IMAGE_REPOSITORY)/$(IMAGE_NAME)
REGISTRY_IMAGE_URI=$(REGISTRY_IMAGE):$(CURRENT_COMMIT)

CONTAINER_ENGINE_CONFIG_DIR = .docker

# TODO: Figure out how to discover this dynamically
CONVENTION_DIR := boilerplate/openshift/custom-catalog-osd-operator

.PHONY: docker-push-catalog
docker-push-catalog: docker-login ## push custom catalog image to quay.io
	${CONTAINER_ENGINE} --config=${CONTAINER_ENGINE_CONFIG_DIR} push ${REGISTRY_IMAGE_URI}

.PHONY: docker-login
docker-login: ## docker login to quay.io
	@test "${REGISTRY_USER}" != "" && test "${REGISTRY_TOKEN}" != "" || (echo "REGISTRY_USER and REGISTRY_TOKEN must be defined" && exit 1)
	mkdir -p ${CONTAINER_ENGINE_CONFIG_DIR}
	@${CONTAINER_ENGINE} --config=${CONTAINER_ENGINE_CONFIG_DIR} login -u="${REGISTRY_USER}" -p="${REGISTRY_TOKEN}" quay.io


.PHONY: docker-login-rh-registry
 docker-login-rh-registry: ## docker login to registry.redhat.io
	@test "${REGISTRY_RH_IO_USER}" != "" && test "${REGISTRY_RH_IO_TOKEN}" != "" || (echo "REGISTRY_RH_IO_USER and REGISTRY_RH_IO_TOKEN must be defined" && exit 1)
	mkdir -p ${CONTAINER_ENGINE_CONFIG_DIR}
	@${CONTAINER_ENGINE} --config=${CONTAINER_ENGINE_CONFIG_DIR} login -u="${REGISTRY_RH_IO_USER}" -p="${REGISTRY_RH_IO_TOKEN}" registry.redhat.io

.PHONY: install-opm
install-opm: ## install opm binary used to build the catalog image if it not already installed
	${CONVENTION_DIR}/install-opm.sh

#########################
# Targets used by app-interface
#########################

.PHONY: catalog-build-push
catalog-build-push:  docker-login-rh-registry docker-login install-opm ## called by app-sre automation to build a new catalog image
	${CONVENTION_DIR}/custom-catalog-build-push.sh ${REGISTRY_IMAGE_URI}

.PHONY: update-versions
update-versions: ## update the version file with the latest operator version (if available)
	${CONVENTION_DIR}/current-version-getter.sh

.PHONY: update-versions-commit
update-versions-commit: ## same as update-versions but also commit the change to the version file
	${CONVENTION_DIR}/current-version-getter.sh -p

.DEFAULT_GOAL := help
.PHONY: help
help: ## Show this help screen.
	@echo 'Usage: make <OPTIONS> ... <TARGETS>'
	@echo ''
	@echo 'Available targets are:'
	@echo ' $(MAKEFILE_LIST)'
	@grep -Eh '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk -F':.*?## ' '{printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
