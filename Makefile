#!/usr/bin/env make -f

TOPDIR := $(realpath $(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
SELF := $(abspath $(lastword $(MAKEFILE_LIST)))

OS := $(shell uname -s | tr '[:upper:]' '[:lower:]')
OSARCH := $(shell uname -m)

ifeq ($(OSARCH),x86_64)
ARCH := amd64
KVM_PATH := kvm
GUEST_OS_TYPE := other5xlinux-64
else
ARCH := $(OSARCH)
KVM_PATH := kvm-arm64
GUEST_OS_TYPE := arm-other5xlinux-64
endif

WORKDIR ?= $(TOPDIR)/work
SRC_VMDIR ?= $(WORKDIR)/packer-src.vmwarevm
DST_VMDIR ?= $(WORKDIR)/packer-dst
BOX_VMDIR ?= $(WORKDIR)/box
DESTDIR ?= $(WORKDIR)/output

AL2_IMAGES_LATEST_URL := https://cdn.amazonlinux.com/os-images/latest/
AL2_IMAGES_LATEST_VER_URL := $(shell curl -fsi $(AL2_IMAGES_LATEST_URL) | grep -i -- "^location" | cut -d ' ' -f 2)
AL2_IMAGES_LATEST_VER_URL_STRIPPED := $(patsubst %/,%,$(AL2_IMAGES_LATEST_VER_URL))
AL2_VERSION := $(shell basename $(AL2_IMAGES_LATEST_VER_URL_STRIPPED))
AL2_REV ?= 1

KVM_ARM64_IMG_URL := $(AL2_IMAGES_LATEST_VER_URL_STRIPPED)/$(KVM_PATH)/amzn2-kvm-$(AL2_VERSION)-$(OSARCH).xfs.gpt.qcow2
KVM_ARM64_SHASUM_URL := $(AL2_IMAGES_LATEST_VER_URL_STRIPPED)/$(KVM_PATH)/SHA256SUMS
KVM_ARM64_IMG := $(shell basename $(KVM_ARM64_IMG_URL))
VMDK_ARM64_IMG := $(subst qcow2,vmdk,$(KVM_ARM64_IMG))

VMWARE_DISKMANAGER ?= /Applications/VMware\ Fusion.app/Contents/Library/vmware-vdiskmanager

.PHONY: help
help: ## Show help message (list targets)
	@awk 'BEGIN {FS = ":.*##"; printf "\nTargets:\n"} /^[$$()% 0-9a-zA-Z_-]+:.*?##/ {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}' $(SELF)

SHOW_ENV_VARS = \
	OS \
	OSARCH \
	ARCH \
	GUEST_OS_TYPE \
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

$(SRC_VMDIR):
	mkdir -p $(SRC_VMDIR)

$(SRC_VMDIR)/seed.iso: | $(SRC_VMDIR)
	hdiutil makehybrid -o $@ -hfs -joliet -iso -default-volume-name cidata http/amazon/

$(SRC_VMDIR)/amazonlinux-2.vmx: amazonlinux-2.vmx.in $(SRC_VMDIR)/seed.iso | $(SRC_VMDIR)
	sed \
		-e "s,%%VMDK_NAME%%,$(VMDK_ARM64_IMG),g" \
		-e "s,%%VERSION%%,$(AL2_VERSION),g" \
		-e "s,%%SEED_ISO_PATH%%,$(SRC_VMDIR)/seed.iso,g" \
		-e "s,%%GUEST_OS_TYPE%%,$(GUEST_OS_TYPE),g" \
	< amazonlinux-2.vmx.in > $@

$(SRC_VMDIR)/$(VMDK_ARM64_IMG): $(WORKDIR)/$(VMDK_ARM64_IMG) | $(SRC_VMDIR)
	cd $(SRC_VMDIR) && \
	ln -s ../$(VMDK_ARM64_IMG) $(VMDK_ARM64_IMG)

srcvm: $(SRC_VMDIR)/amazonlinux-2.vmx $(SRC_VMDIR)/$(VMDK_ARM64_IMG) ## Prepare build VM

$(DST_VMDIR):
	mkdir -p $(DST_VMDIR)

$(DST_VMDIR)/amazonlinux-2.pkr.hcl: amazonlinux-2.pkr.hcl.in | $(DST_VMDIR)
	sed \
		-e "s,%%VMX_PATH%%,$(SRC_VMDIR)/amazonlinux-2.vmx,g" \
		-e "s,%%VM_NAME%%,amazonlinux-2,g" \
	< amazonlinux-2.pkr.hcl.in > $@

dstvm: $(DST_VMDIR)/amazonlinux-2.pkr.hcl ## Prepare packer sources

$(DST_VMDIR)/output-buildvm/amazonlinux-2.vmx: | srcvm dstvm
	echo "building..." && \
	export PACKER_LOG=1 && \
	cd $(DST_VMDIR) && \
	packer build .
	for vmdk in $$(find $(DST_VMDIR)/output-buildvm/ -type f -name "*.vmdk"); do \
		echo "Defragmenting $${vmdk}..." ; \
		$(VMWARE_DISKMANAGER) -d $${vmdk} ; \
		echo "Shrinking $${vmdk}..." ; \
		$(VMWARE_DISKMANAGER) -k $${vmdk} ; \
	done

build: $(DST_VMDIR)/output-buildvm/amazonlinux-2.vmx ## Run packer build

$(BOX_VMDIR):
	mkdir -p $(BOX_VMDIR)

$(BOX_VMDIR)/amazonlinux-2.vmx: | $(DST_VMDIR)/output-buildvm/amazonlinux-2.vmx $(BOX_VMDIR)
	for vmdk in $$(find $(DST_VMDIR)/output-buildvm/ -type f -name "*.vmdk"); do \
		vmdk_bn=$$(basename $${vmdk}) ; \
		cd $(BOX_VMDIR) && ln -h ../packer-dst/output-buildvm/$${vmdk_bn} $${vmdk_bn} ; \
	done
	cat $(DST_VMDIR)/output-buildvm/amazonlinux-2.vmx | egrep -v -- \
		"^displayname|^extendedconfigfile|^nvme0.subnqnuuid|^nvram|^numa|^sata0:1|^remotedisplay.vnc|^uuid.bios|^uuid.location|^vc.uuid|^vmci0.id|^vmotion|^vmxstats.filename" \
	> $@

$(BOX_VMDIR)/metadata.json: metadata.json.in | $(BOX_VMDIR)
	sed -e "s,%%ARCH%%,$(ARCH),g" < metadata.json.in > $@

boxvm: $(BOX_VMDIR)/amazonlinux-2.vmx $(BOX_VMDIR)/metadata.json ## Prepare vagrant box VM

$(DESTDIR):
	mkdir -p $@

$(DESTDIR)/amazonlinux-2.box: $(BOX_VMDIR)/amazonlinux-2.vmx $(BOX_VMDIR)/metadata.json | $(DESTDIR)
	cd $(BOX_VMDIR) && tar -czvf $@ *

$(DESTDIR)/metadata.json: metadata-box.json.in | $(DESTDIR)
	sed \
		-e "s,%%ARCH%%,$(ARCH),g" \
		-e "s,%%VERSION%%,$(AL2_VERSION)-$(AL2_REV),g" \
	< metadata-box.json.in > $@

box: $(DESTDIR)/amazonlinux-2.box $(DESTDIR)/metadata.json ## Create vagrant box

.PHONY: preclean
preclean:
	rm -rf $(SRC_VMDIR) $(DST_VMDIR) $(DESTDIR)
	rm -f $(WORKDIR)/$(VMDK_ARM64_IMG)

.PHONY: clean
clean: ## Clean building environment
	rm -rf $(WORKDIR)
