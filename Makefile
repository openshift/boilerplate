ALLOW_DIRTY_CHECKOUT?=false

.PHONY: isclean
isclean:
	@(test "$(ALLOW_DIRTY_CHECKOUT)" != "false" || test 0 -eq $$(git status --porcelain | wc -l)) || (echo "Local git checkout is not clean, commit changes and try again." >&2 && exit 1)

.PHONY: test
test: isclean
	test/driver >${ARTIFACT_DIR}/pr-check.log 2>&1

.PHONY: pr-check
pr-check: test
