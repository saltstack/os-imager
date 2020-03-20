# Minimal makefile for running packer lint

OS  =
OS_REV  =
SALT_BRANCH = master
PACKERDIR  = AWS
REGION  = us-west-2
TEMPLATE = $(PACKERDIR)/$(OS)/$(OS).json
VAR_FILE = $(PACKERDIR)/$(OS)/$(OS)-$(OS_REV)-$(REGION).json

.PHONY: help
help:
	@echo ''
	@echo '  Targets:'
	@echo '    build, validate'
	@echo ''
	@echo '  Usage:'
	@echo '    make <target> OS=<SOME OS> OS_REV=<SOME OS REVISION>'

check-paths:
	$(warning Makefile support was dropped for invoke, please 'pip install invoke'.)

.PHONY: validate
validate: check-paths
	$(warning Please run 'inv build-aws --distro $(OS) --distro-version $(OS_REV) --validate' instead.)
	@exit 1

.PHONY: build
build: check-paths
	$(error Please run 'inv build-aws --distro $(OS) --distro-version $(OS_REV) --salt-branch=$(SALT_BRANCH)' instead.)
	@exit 1

.PHONY: build-staging
build-staging: check-paths
	$(error Please run 'inv build-aws --distro $(OS) --distro-version $(OS_REV) --salt-branch=$(SALT_BRANCH) --staging' instead.)
	@exit 1
