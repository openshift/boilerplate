ALLOW_DIRTY_CHECKOUT?=false
IMG?=boilerplate
CONTAINER_ENGINE?=$(shell command -v podman 2>/dev/null || echo "docker")
CHECKOUT=$(shell pwd)

# Tests rely on this starting off unset. (And if it is set, it's usually
# not for the reasons we care about.)
unexport REPO_NAME

.PHONY: isclean
isclean: ## Validate the local checkout is clean. Use ALLOW_DIRTY_CHECKOUT=true to nullify
	@(test "$(ALLOW_DIRTY_CHECKOUT)" != "false" || test 0 -eq $$(git status --porcelain | wc -l)) || (echo "Local git checkout is not clean, commit changes and try again." >&2 && exit 1)

.PHONY: test
test: export GO_COMPLIANCE_INFO = 0
test: ## Runs tests under the /case directory
	test/driver $(CASE_GLOB)

.PHONY: pr-check
pr-check: test

.PHONY: container-pr-check
container-pr-check: build-image-deep # Builds the boilerplate image from your local checkout, mounts boilerplate, then runs 'make pr-check' as it would run in Konflux.
	$(CONTAINER_ENGINE) run --rm -it -v ${CHECKOUT}:/boilerplate:Z localhost/boilerplate:latest cd boilerplate && make pr-check

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
	$(CONTAINER_ENGINE) build -t $(IMG):latest -f config/Dockerfile .

.DEFAULT_GOAL := help
.PHONY: help
help: ## Show this help screen.
	@echo 'Usage: make <OPTIONS> ... <TARGETS>'
	@echo ''
	@echo 'Available targets are:'
	@echo ''
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
