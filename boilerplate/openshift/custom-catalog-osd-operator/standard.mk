# Validate variables in project.mk exist
ifndef IMAGE_REGISTRY
$(error IMAGE_REGISTRY is not set; check project.mk file)
endif
ifndef IMAGE_REPOSITORY
$(error IMAGE_REPOSITORY is not set; check project.mk file)
endif
ifndef IMAGE_NAME
$(error IMAGE_NAME is not set; check project.mk file)
endif

# Accommodate docker or podman
CONTAINER_ENGINE=$(shell command -v podman 2>/dev/null || command -v docker 2>/dev/null)

# Generate version and tag information from inputs
COMMIT_NUMBER=$(shell git rev-list `git rev-list --parents HEAD | egrep "^[a-f0-9]{40}$$"`..HEAD --count)
CURRENT_COMMIT=$(shell git rev-parse --short=7 HEAD)

REGISTRY_IMAGE=$(IMAGE_REGISTRY)/$(IMAGE_REPOSITORY)/$(IMAGE_NAME)
REGISTRY_IMAGE_URI=$(REGISTRY_IMAGE):$(CURRENT_COMMIT)
REGISTRY_IMAGE_URI_LATEST=$(REGISTRY_IMAGE):latest

CONTAINER_ENGINE_CONFIG_DIR = .docker

# TODO: Figure out how to discover this dynamically
CONVENTION_DIR := boilerplate/openshift/custom-catalog-osd-operator

# Set the default goal in a way that works for older & newer versions of `make`:
# Older versions (<=3.8.0) will pay attention to the `default` target.
# Newer versions pay attention to .DEFAULT_GOAL, where uunsetting it makes the next defined target the default:
# https://www.gnu.org/software/make/manual/make.html#index-_002eDEFAULT_005fGOAL-_0028define-default-goal_0029
.DEFAULT_GOAL :=
.PHONY: default
default: go-check go-test go-build

.PHONY: docker-push-catalog
docker-push-catalog: docker-login
	${CONTAINER_ENGINE} --config=${CONTAINER_ENGINE_CONFIG_DIR} push ${REGISTRY_IMAGE_URI}
	${CONTAINER_ENGINE} tag ${REGISTRY_IMAGE_URI} ${REGISTRY_IMAGE_URI_LATEST}
	${CONTAINER_ENGINE} --config=${CONTAINER_ENGINE_CONFIG_DIR} push ${REGISTRY_IMAGE_URI_LATEST}

# TODO: Get rid of push. It's not used.
.PHONY: push
push: docker-push

.PHONY: docker-login
docker-login:
	@test "${REGISTRY_USER}" != "" && test "${REGISTRY_TOKEN}" != "" || (echo "REGISTRY_USER and REGISTRY_TOKEN must be defined" && exit 1)
	mkdir -p ${CONTAINER_ENGINE_CONFIG_DIR}
	@${CONTAINER_ENGINE} --config=${CONTAINER_ENGINE_CONFIG_DIR} login -u="${REGISTRY_USER}" -p="${REGISTRY_TOKEN}" quay.io

.PHONY: docker-login-rh-registry
 docker-login-rh-registry:
	@test "${REGISTRY_RH_IO_USER}" != "" && test "${REGISTRY_RH_IO_TOKEN}" != "" || (echo "REGISTRY_RH_IO_USER and REGISTRY_RH_IO_TOKEN must be defined" && exit 1)
	mkdir -p ${CONTAINER_ENGINE_CONFIG_DIR}
	@${CONTAINER_ENGINE} --config=${CONTAINER_ENGINE_CONFIG_DIR} login -u="${REGISTRY_RH_IO_USER}" -p="${REGISTRY_RH_IO_TOKEN}" registry.redhat.io

#########################
# Targets used by app-interface
#########################

# build-push: Construct, tag, and push the official operator and
# registry container images.
# TODO: Boilerplate this script.
.PHONY: build-push
build-push:  docker-login-rh-registry docker-login
	${CONVENTION_DIR}/app-sre-build-deploy.sh ${REGISTRY_IMAGE_URI}

.PHONY: update-versions
update-versions:
	${CONVENTION_DIR}/current-version-getter.sh

.PHONY: update-versions-push
update-versions-push:
	${CONVENTION_DIR}/current-version-getter.sh -p
