ALLOW_DIRTY_CHECKOUT?=false
IMG?=boilerplate
CONTAINER_ENGINE?=$(shell command -v podman 2>/dev/null || echo "docker")

# Tests rely on this starting off unset. (And if it is set, it's usually
# not for the reasons we care about.)
unexport REPO_NAME

.PHONY: isclean
isclean: ## Validate the local checkout is clean. Use ALLOW_DIRTY_CHECKOUT=true to nullify
	@(test "$(ALLOW_DIRTY_CHECKOUT)" != "false" || test 0 -eq $$(git status --porcelain | wc -l)) || (echo "Local git checkout is not clean, commit changes and try again." >&2 && exit 1)

.PHONY: tag-check
tag-check: ## Perform a tag-check that validates a new tag has been created when changing the build image
	config/tag-check.sh

.PHONY: test
test: isclean tag-check ## Runs tests under the /case directory
	test/driver $(CASE_GLOB)

.PHONY: pr-check
pr-check: test ## This is the target ran by prow

.PHONY: docker-build
docker-build: ## Builds the image. May require ALLOW_DIRTY_CHECKOUT=true if testing
	cd config; $(CONTAINER_ENGINE) build -t $(IMG):latest .

.PHONY: docker-push
docker-push: ## Push image to app-sre in quay.io
	config/push.sh quay.io app-sre $(IMG)

.PHONY: build-push
build-push: docker-build docker-push ## Combines docker-build and docker-push

.DEFAULT_GOAL := help
.PHONY: help
help: ## Show this help screen.
	@echo 'Usage: make <OPTIONS> ... <TARGETS>'
	@echo ''
	@echo 'Available targets are:'
	@echo ''
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
