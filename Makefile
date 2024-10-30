ALLOW_DIRTY_CHECKOUT?=false
SKIP_IMAGE_TAG_CHECK?=false
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
	@config/tag-check.sh

.PHONY: test
test: export GO_COMPLIANCE_INFO = 0
test: isclean ## Runs tests under the /case directory
	test/driver $(CASE_GLOB)

.PHONY: pr-check
pr-check: test tag-check ## This is the target run by prow

.PHONY: subscriber-report
subscriber-report: ## Discover onboarding and prow status of subscribed consumers
	./boilerplate/_lib/subscriber report onboarding
	@# TODO: Add:
	@#            ./boilerplate/_lib/subscriber report pr
	@# - Requires gh CLI
	@# - Requires gh auth
	@echo
	./boilerplate/_lib/subscriber report release ALL

.PHONY: build-image-deep
build-image-deep: ## Builds the image from scratch, like appsre does. May require ALLOW_DIRTY_CHECKOUT=true if testing
	cd config; $(CONTAINER_ENGINE) build -t $(IMG):latest -f Dockerfile .

.PHONY: build-image-shallow
build-image-shallow: ## Builds the image starting from a recent release, like prow does. May require ALLOW_DIRTY_CHECKOUT=true if testing
	cd config; $(CONTAINER_ENGINE) build -t $(IMG):latest .

.DEFAULT_GOAL := help
.PHONY: help
help: ## Show this help screen.
	@echo 'Usage: make <OPTIONS> ... <TARGETS>'
	@echo ''
	@echo 'Available targets are:'
	@echo ''
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
