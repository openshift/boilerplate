ALLOW_DIRTY_CHECKOUT?=false
IMG?=boilerplate
CONTAINER_ENGINE?=$(shell command -v podman 2>/dev/null || echo "docker")

# Tests rely on this starting off unset. (And if it is set, it's usually
# not for the reasons we care about.)
unexport REPO_NAME

.PHONY: isclean
isclean:
	@(test "$(ALLOW_DIRTY_CHECKOUT)" != "false" || test 0 -eq $$(git status --porcelain | wc -l)) || (echo "Local git checkout is not clean, commit changes and try again." >&2 && exit 1)

.PHONY: tag-check
tag-check:
	config/tag-check.sh

.PHONY: test
test: isclean tag-check
	test/driver $(CASE_GLOB)

.PHONY: pr-check
pr-check: test

.PHONY: docker-build
docker-build:
	cd config; $(CONTAINER_ENGINE) build -t $(IMG):latest .

.PHONY: docker-push
docker-push:
	config/push.sh quay.io app-sre $(IMG)

.PHONY: build-push
build-push: docker-build docker-push
