#!/usr/bin/env make -f

TOPDIR := $(realpath $(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
SELF := $(abspath $(lastword $(MAKEFILE_LIST)))

OS := $(shell uname -s | tr '[:upper:]' '[:lower:]')

WORKDIR ?= work
VMDIR ?= $(WORKDIR)/packer-build.vmwarevm

AL2_IMAGES_LATEST_URL := https://cdn.amazonlinux.com/os-images/latest/
AL2_IMAGES_LATEST_VER_URL := $(shell curl -fsi $(AL2_IMAGES_LATEST_URL) | grep -i -- "^location" | cut -d ' ' -f 2)
AL2_IMAGES_LATEST_VER_URL_STRIPPED := $(patsubst %/,%,$(AL2_IMAGES_LATEST_VER_URL))
AL2_VERSION := $(shell basename $(AL2_IMAGES_LATEST_VER_URL_STRIPPED))

KVM_ARM64_IMG_URL := $(AL2_IMAGES_LATEST_VER_URL_STRIPPED)/kvm-arm64/amzn2-kvm-$(AL2_VERSION)-arm64.xfs.gpt.qcow2
KVM_ARM64_SHASUM_URL := $(AL2_IMAGES_LATEST_VER_URL_STRIPPED)/kvm-arm64/SHA256SUMS
KVM_ARM64_IMG := $(shell basename $(KVM_ARM64_IMG_URL))
VMDK_ARM64_IMG := $(subst qcow2,vmdk,$(KVM_ARM64_IMG))

.PHONY: help
help: ## Show help message (list targets)
	@awk 'BEGIN {FS = ":.*##"; printf "\nTargets:\n"} /^[$$()% 0-9a-zA-Z_-]+:.*?##/ {printf "  \033[36m%-19s\033[0m %s\n", $$1, $$2}' $(SELF)

SHOW_ENV_VARS = \
	OS \
	AL2_IMAGES_LATEST_URL \
	AL2_IMAGES_LATEST_VER_URL \
	AL2_VERSION \
	KVM_ARM64_IMG \
	VMDK_ARM64_IMG

show-var-%:
	@{ \
	escaped_v="$(subst ",\",$($*))" ; \
	if [ -n "$$escaped_v" ]; then v="$$escaped_v"; else v="(undefined)"; fi; \
	printf "%-21s %s\n" "$*" "$$v"; \
	}

.PHONY: show-env
show-env: $(addprefix show-var-, $(SHOW_ENV_VARS)) ## Show environment details

$(WORKDIR):
	mkdir -p $@

$(WORKDIR)/$(KVM_ARM64_IMG): | $(WORKDIR)
	cd $(WORKDIR) && \
	curl -fLO --progress-bar $(KVM_ARM64_SHASUM_URL) && \
	curl -fLO --progress-bar $(KVM_ARM64_IMG_URL) && \
	sha256sum -c SHA256SUMS

fetch: $(WORKDIR)/$(KVM_ARM64_IMG) ## Fetch Amazon Linux 2 original KVM/qcow2 image(s)

$(WORKDIR)/$(VMDK_ARM64_IMG): $(WORKDIR)/$(KVM_ARM64_IMG)
	cd $(WORKDIR) && \
	qemu-img convert -f qcow2 -O vmdk -p $(KVM_ARM64_IMG) $(VMDK_ARM64_IMG)

convert: $(WORKDIR)/$(VMDK_ARM64_IMG) ## Convert KVM/qcow2 image(s) to VMDK

$(VMDIR):
	mkdir -p $(VMDIR)

$(VMDIR)/amazonlinux-2.vmx: amazonlinux-2.vmx.in | $(VMDIR)
	sed \
		-e "s,%%VMDK_NAME%%,$(VMDK_ARM64_IMG),g" \
		-e "s,%%VERSION%%,$(AL2_VERSION),g" \
	< amazonlinux-2.vmx.in > $@

$(VMDIR)/$(VMDK_ARM64_IMG): $(WORKDIR)/$(VMDK_ARM64_IMG) | $(VMDIR)
	cd $(VMDIR) && \
	ln -s ../$(VMDK_ARM64_IMG) $(VMDK_ARM64_IMG)

vm: $(VMDIR)/amazonlinux-2.vmx $(VMDIR)/$(VMDK_ARM64_IMG) ## Prepare build VM

.PHONY: clean
clean:
	rm -rf $(WORKDIR)
