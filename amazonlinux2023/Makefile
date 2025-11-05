#!/usr/bin/env make -f

_TOPDIR := $(realpath $(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
_SELF := $(abspath $(lastword $(MAKEFILE_LIST)))
REFS += $(_SELF)

SHOW_ENV_VARS += \
	FIRMWARE \
	GUEST_OS_TYPE \
	AL2023_IMAGES_LATEST_URL \
	AL2023_IMAGES_LATEST_VER_URL \
	AL2023_VERSION \
	KVM_IMG \
	VMDK_IMG

include $(_TOPDIR)/../Makefile

OS      ?= $(error OS not defined)
OSARCH  ?= $(error OSARCH not defined)
WORKDIR ?= $(error WORKDIR not defined)

ifeq ($(OSARCH),x86_64)
KVM_PATH := kvm
GUEST_OS_TYPE := other6xlinux-64
FIRMWARE ?= bios
else
KVM_PATH := kvm-arm64
GUEST_OS_TYPE := arm-other6xlinux-64
FIRMWARE ?= efi
endif

SRC_VMDIR ?= $(WORKDIR)/packer-src.vmwarevm
DST_VMDIR ?= $(WORKDIR)/packer-dst
BOX_VMDIR ?= $(WORKDIR)/box
DESTDIR ?= $(WORKDIR)/output

AL2023_IMAGES_LATEST_URL := https://cdn.amazonlinux.com/al2023/os-images/latest/
AL2023_IMAGES_LATEST_VER_URL := $(shell curl -fsi $(AL2023_IMAGES_LATEST_URL) | grep -i -- "^location" | cut -d ' ' -f 2)
AL2023_IMAGES_LATEST_VER_URL_STRIPPED := $(patsubst %/,%,$(AL2023_IMAGES_LATEST_VER_URL))
AL2023_VERSION := $(shell basename $(AL2023_IMAGES_LATEST_VER_URL_STRIPPED))
AL2023_REV ?= 1

KVM_IMG_URL := $(AL2023_IMAGES_LATEST_VER_URL_STRIPPED)/$(KVM_PATH)/al2023-kvm-$(AL2023_VERSION)-kernel-6.1-$(OSARCH).xfs.gpt.qcow2
KVM_SHASUM_URL := $(AL2023_IMAGES_LATEST_VER_URL_STRIPPED)/$(KVM_PATH)/SHA256SUMS
KVM_IMG := $(shell basename $(KVM_IMG_URL))
VMDK_IMG := $(subst qcow2,vmdk,$(KVM_IMG))

VMWARE_DISKMANAGER ?= /Applications/VMware\ Fusion.app/Contents/Library/vmware-vdiskmanager


$(WORKDIR)/$(KVM_IMG): | $(WORKDIR)
	cd $(WORKDIR) && \
	curl -fLO --progress-bar $(KVM_SHASUM_URL) && \
	curl -fLO --progress-bar $(KVM_IMG_URL) && \
	sha256sum -c SHA256SUMS

fetch: $(WORKDIR)/$(KVM_IMG) ## Fetch Amazon Linux 2 original KVM/qcow2 image(s)

$(WORKDIR)/$(VMDK_IMG): $(WORKDIR)/$(KVM_IMG)
	cd $(WORKDIR) && \
	qemu-img convert -f qcow2 -O vmdk -p $(KVM_IMG) $(VMDK_IMG)

convert: $(WORKDIR)/$(VMDK_IMG) ## Convert KVM/qcow2 image(s) to VMDK

$(SRC_VMDIR):
	mkdir -p $(SRC_VMDIR)

$(SRC_VMDIR)/seed.iso: | $(SRC_VMDIR)
	hdiutil makehybrid -o $@ -hfs -joliet -iso -default-volume-name cidata http/amazon/

$(SRC_VMDIR)/amazonlinux-2023.vmx: $(_TOPDIR)/amazonlinux-2023.vmx.in $(SRC_VMDIR)/seed.iso | $(SRC_VMDIR)
	sed \
		-e "s,%%VMDK_NAME%%,$(VMDK_IMG),g" \
		-e "s,%%VERSION%%,$(AL2023_VERSION),g" \
		-e "s,%%SEED_ISO_PATH%%,$(SRC_VMDIR)/seed.iso,g" \
		-e "s,%%GUEST_OS_TYPE%%,$(GUEST_OS_TYPE),g" \
		-e "s,%%FIRMWARE%%,$(FIRMWARE),g" \
	< $(_TOPDIR)/amazonlinux-2023.vmx.in > $@

$(SRC_VMDIR)/$(VMDK_IMG): $(WORKDIR)/$(VMDK_IMG) | $(SRC_VMDIR)
	cd $(SRC_VMDIR) && \
	ln -s ../$(VMDK_IMG) $(VMDK_IMG)

srcvm: $(SRC_VMDIR)/amazonlinux-2023.vmx $(SRC_VMDIR)/$(VMDK_IMG) ## Prepare build VM

$(DST_VMDIR):
	mkdir -p $(DST_VMDIR)

$(DST_VMDIR)/amazonlinux-2023.pkr.hcl: $(_TOPDIR)/amazonlinux-2023.pkr.hcl.in | $(DST_VMDIR)
	sed \
		-e "s,%%VMX_PATH%%,$(SRC_VMDIR)/amazonlinux-2023.vmx,g" \
		-e "s,%%VM_NAME%%,amazonlinux-2023,g" \
	< $(_TOPDIR)/amazonlinux-2023.pkr.hcl.in > $@

dstvm: $(DST_VMDIR)/amazonlinux-2023.pkr.hcl ## Prepare packer sources

$(DST_VMDIR)/output-buildvm/amazonlinux-2023.vmx: | srcvm dstvm
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

build: $(DST_VMDIR)/output-buildvm/amazonlinux-2023.vmx ## Run packer build

$(BOX_VMDIR):
	mkdir -p $(BOX_VMDIR)

$(BOX_VMDIR)/amazonlinux-2023.vmx: | $(DST_VMDIR)/output-buildvm/amazonlinux-2023.vmx $(BOX_VMDIR)
	for vmdk in $$(find $(DST_VMDIR)/output-buildvm/ -type f -name "*.vmdk"); do \
		vmdk_bn=$$(basename $${vmdk}) ; \
		cd $(BOX_VMDIR) && ln -h ../packer-dst/output-buildvm/$${vmdk_bn} $${vmdk_bn} ; \
	done
	cat $(DST_VMDIR)/output-buildvm/amazonlinux-2023.vmx | egrep -v -- \
		"^displayname|^extendedconfigfile|^nvme0.subnqnuuid|^nvram|^numa|^sata0:1|^remotedisplay.vnc|^uuid.bios|^uuid.location|^vc.uuid|^vmci0.id|^vmotion|^vmxstats.filename" \
	> $@

$(BOX_VMDIR)/metadata.json: $(_TOPDIR)/metadata.json.in | $(BOX_VMDIR)
	sed -e "s,%%ARCH%%,$(ARCH),g" < $(_TOPDIR)/metadata.json.in > $@

boxvm: $(BOX_VMDIR)/amazonlinux-2023.vmx $(BOX_VMDIR)/metadata.json ## Prepare vagrant box VM

$(DESTDIR):
	mkdir -p $@

$(DESTDIR)/amazonlinux-2023.box: $(BOX_VMDIR)/amazonlinux-2023.vmx $(BOX_VMDIR)/metadata.json | $(DESTDIR)
	cd $(BOX_VMDIR) && tar -czvf $@ *

$(DESTDIR)/metadata.json: $(_TOPDIR)/metadata-box.json.in | $(DESTDIR)
	sed \
		-e "s,%%ARCH%%,$(ARCH),g" \
		-e "s,%%VERSION%%,$(AL2023_VERSION)-$(AL2023_REV),g" \
	< $(_TOPDIR)/metadata-box.json.in > $@

box: $(DESTDIR)/amazonlinux-2023.box $(DESTDIR)/metadata.json ## Create vagrant box

.PHONY: preclean
preclean:
	rm -rf $(SRC_VMDIR) $(DST_VMDIR) $(DESTDIR) $(BOX_VMDIR)
	rm -f $(WORKDIR)/$(VMDK_IMG)
