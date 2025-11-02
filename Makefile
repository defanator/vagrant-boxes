#!/usr/bin/env make -f

TOPDIR  := $(realpath $(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
SELF    := $(abspath $(lastword $(MAKEFILE_LIST)))
REFS    += $(SELF)
WORKDIR ?= $(TOPDIR)/work
OS      := $(shell uname -s | tr '[:upper:]' '[:lower:]')
OSARCH  := $(shell uname -m)

ifeq ($(OSARCH),x86_64)
ARCH := amd64
else
ARCH := $(OSARCH)
endif

_reverse = $(if $(1),$(call _reverse,$(wordlist 2,$(words $(1)),$(1)))) $(firstword $(1))

.PHONY: help
help: ## Show help message (list targets)
	@printf "\nTargets:\n"
	@for ref in $(call _reverse,$(REFS)); do \
		awk 'BEGIN {FS = ":.*##"} /^[$$()% 0-9a-zA-Z_-]+:.*?##/ {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}' $${ref} ; \
	done

SHOW_ENV_VARS_BASE := \
	TOPDIR \
	SELF \
	OS \
	OSARCH \
	ARCH

BASE_ENV = \
	OS="$(OS)" \
	OSARCH="$(OSARCH)" \
	WORKDIR="$(WORKDIR)"

show-var-%:
	@{ \
	escaped_v="$(subst ",\",$($*))" ; \
	if [ -n "$$escaped_v" ]; then v="$$escaped_v"; else v="(undefined)"; fi; \
	printf "%-21s %s\n" "$*" "$$v"; \
	}

.PHONY: show-env
show-env: $(addprefix show-var-, $(SHOW_ENV_VARS_BASE)) $(addprefix show-var-, $(SHOW_ENV_VARS)) ## Show environment details

$(WORKDIR):
	mkdir -p $@

.PHONY: clean
clean: ## Clean building environment
	rm -rf $(WORKDIR)

# templated targets

help-%:
	$(BASE_ENV) $(MAKE) -f $(TOPDIR)/$*/Makefile help

show-env-%:
	$(BASE_ENV) $(MAKE) -f $(TOPDIR)/$*/Makefile show-env

fetch-%:
	$(BASE_ENV) $(MAKE) -f $(TOPDIR)/$*/Makefile fetch

convert-%:
	$(BASE_ENV) $(MAKE) -f $(TOPDIR)/$*/Makefile convert

build-%:
	$(BASE_ENV) $(MAKE) -f $(TOPDIR)/$*/Makefile build

box-%:
	$(BASE_ENV) $(MAKE) -f $(TOPDIR)/$*/Makefile box
