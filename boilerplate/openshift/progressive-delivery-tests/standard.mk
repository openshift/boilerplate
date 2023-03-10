# Validate variables in project.mk exist
ifndef OPERATOR_NAME
$(error OPERATOR_NAME is not set; only operators should consume this convention; check project.mk file)
endif
ifndef NAMESPACE
$(error NAMESPACE is not set; only operators should consume this convention; check project.mk file)
endif
ifndef JOB_NAME
$(error JOB_NAME is not set; only operators should consume this convention; check project.mk file)
endif
ifndef SERVICE_ACCOUNT
$(error SERVICE_ACCOUNT is not set; only operators should consume this convention; check project.mk file)
endif

.PHONY: build
build:
	@echo "Creating sss-acceptance-test yaml for $(OPERATOR_NAME)"
	@sh sss-acceptance-test-generate.sh