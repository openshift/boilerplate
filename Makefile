ALLOW_DIRTY_CHECKOUT?=false

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

# Use as:
#     eval $(make clone-this)
# Then you can go to a consuming repo (in the same shell) and run
# `make update-boilerplate` to test your local changes.
.PHONY: clone-this
clone-this:
	@echo export BOILERPLATE_GIT_REPO=$(shell realpath .)
