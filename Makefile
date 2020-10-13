ALLOW_DIRTY_CHECKOUT?=false
IMG?=boilerplate
IMG_TAG?=latest
QUAY_IMAGE?=quay.io/app-sre/$(IMG)
CONTAINER_ENGINE?=$(shell command -v podman 2>/dev/null || echo "docker")
GIT_HASH?=$(shell git rev-parse --short=7 HEAD)

# Tests rely on this starting off unset. (And if it is set, it's usually
# not for the reasons we care about.)
unexport REPO_NAME

.PHONY: isclean
isclean:
	@(test "$(ALLOW_DIRTY_CHECKOUT)" != "false" || test 0 -eq $$(git status --porcelain | wc -l)) || (echo "Local git checkout is not clean, commit changes and try again." >&2 && exit 1)

.PHONY: test
test: isclean
	test/driver

.PHONY: pr-check
pr-check: test

.PHONY: docker-build
docker-build:
	GIT_HASH=$(shell git rev-parse --short=7 HEAD)
	cd config; $(CONTAINER_ENGINE) build -t $(IMG):$(IMG_TAG) .	

.PHONY: docker-push
docker-push:
	skopeo copy --dest-creds "$(QUAY_USER):$(QUAY_TOKEN)" \
	    "docker-daemon:$(IMG):$(IMG_TAG)" \
	    "docker://$(QUAY_IMAGE):$(IMG_TAG)"
	skopeo copy --dest-creds "$(QUAY_USER):$(QUAY_TOKEN)" \
	    "docker-daemon:$(IMG):$(IMG_TAG)" \
	    "docker://$(QUAY_IMAGE):$(GIT_HASH)"

.PHONY: build-push
build-push: docker-build docker-push
