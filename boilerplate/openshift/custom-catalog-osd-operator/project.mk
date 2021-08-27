# Project specific values
REPO_NAME?=$(shell git config --get remote.origin.url | sed 's,.*/,,; s/\.git$///')

IMAGE_REGISTRY?=quay.io
IMAGE_REPOSITORY?=app-sre
IMAGE_NAME?=$(REPO_NAME)

VERSION_MAJOR?=0
VERSION_MINOR?=1

REGISTRY_USER?=$(QUAY_USER)
REGISTRY_TOKEN?=$(QUAY_TOKEN)
