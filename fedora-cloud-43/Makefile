#!/usr/bin/env make -f

_TOPDIR := $(realpath $(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
_SELF   := $(abspath $(lastword $(MAKEFILE_LIST)))
_IMAGE  := $(shell basename $(_TOPDIR))
REFS    += $(_SELF)

SHOW_ENV_VARS += \
	FIRMWARE \
	GUEST_OS_TYPE \
	FEDORA_VERSION \
	FEDORA_VERSION_FULL \
	FEDORA_REV \
	BOX_VERSION \
	FEDORA_IMAGES_URL \
	KVM_IMG_URL \
	KVM_IMG \
	VMDK_IMG

include $(_TOPDIR)/../Makefile

OS      ?= $(error OS not defined)
OSARCH  ?= $(error OSARCH not defined)
WORKDIR ?= $(error WORKDIR not defined)

_WORKDIR := $(WORKDIR)/$(_IMAGE)

ifeq ($(OSARCH),x86_64)
KVM_PATH := kvm
GUEST_OS_TYPE := fedora-64
FIRMWARE ?= bios
ISO_ARCH := $(OSARCH)
else
KVM_PATH := kvm-arm64
GUEST_OS_TYPE := arm-fedora-64
FIRMWARE ?= efi
ISO_ARCH := aarch64
endif

SRC_VMDIR ?= $(_WORKDIR)/packer-src.vmwarevm
DST_VMDIR ?= $(_WORKDIR)/packer-dst
BOX_VMDIR ?= $(_WORKDIR)/box
DESTDIR ?= $(_WORKDIR)/output

FEDORA_VERSION := 43
FEDORA_VERSION_FULL := $(FEDORA_VERSION)-1.6
FEDORA_REV ?= $(shell date +"%Y%m%d").1

BOX_VERSION := $(FEDORA_VERSION_FULL)-$(FEDORA_REV)

### https://download.fedoraproject.org/pub/fedora/linux/releases/43/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-43-1.6.x86_64.qcow2

FEDORA_IMAGES_URL := https://download.fedoraproject.org/pub/fedora/linux/releases/$(FEDORA_VERSION)/Cloud/$(ISO_ARCH)/images

KVM_IMG_URL := $(FEDORA_IMAGES_URL)/Fedora-Cloud-Base-Generic-$(FEDORA_VERSION_FULL).$(ISO_ARCH).qcow2
KVM_SHASUM_URL := $(FEDORA_IMAGES_URL)/Fedora-Cloud-$(FEDORA_VERSION_FULL)-$(ISO_ARCH)-CHECKSUM
KVM_IMG := $(shell basename $(KVM_IMG_URL))
VMDK_IMG := $(subst qcow2,vmdk,$(KVM_IMG))

VMWARE_DISKMANAGER ?= /Applications/VMware\ Fusion.app/Contents/Library/vmware-vdiskmanager

$(_WORKDIR):
	mkdir -p "$@"

$(_WORKDIR)/$(KVM_IMG): | $(_WORKDIR)
	cd $(_WORKDIR) && \
	curl -fL --progress-bar $(KVM_SHASUM_URL) | grep -- "$(KVM_IMG)" >CHECKSUM && \
	curl -fLO --progress-bar $(KVM_IMG_URL) && \
	sha256sum -c CHECKSUM

fetch: $(_WORKDIR)/$(KVM_IMG) ## Fetch Fedora Cloud 43 original KVM/qcow2 image(s)

$(_WORKDIR)/$(VMDK_IMG): $(_WORKDIR)/$(KVM_IMG)
	cd $(_WORKDIR) && \
	qemu-img convert -f qcow2 -O vmdk -p $(KVM_IMG) $(VMDK_IMG)

convert: $(_WORKDIR)/$(VMDK_IMG) ## Convert KVM/qcow2 image(s) to VMDK

$(SRC_VMDIR):
	mkdir -p $(SRC_VMDIR)

$(SRC_VMDIR)/seed.iso: | $(SRC_VMDIR)
	hdiutil makehybrid -o $@ -hfs -joliet -iso -default-volume-name cidata $(TOPDIR)/http/fedora/

$(SRC_VMDIR)/$(_IMAGE).vmx: $(_TOPDIR)/$(_IMAGE).vmx.in $(SRC_VMDIR)/seed.iso | $(SRC_VMDIR)
	sed \
		-e "s,%%VMDK_NAME%%,$(VMDK_IMG),g" \
		-e "s,%%VERSION%%,$(FEDORA_VERSION),g" \
		-e "s,%%SEED_ISO_PATH%%,$(SRC_VMDIR)/seed.iso,g" \
		-e "s,%%GUEST_OS_TYPE%%,$(GUEST_OS_TYPE),g" \
		-e "s,%%FIRMWARE%%,$(FIRMWARE),g" \
	< $(_TOPDIR)/$(_IMAGE).vmx.in > $@

$(SRC_VMDIR)/$(VMDK_IMG): $(_WORKDIR)/$(VMDK_IMG) | $(SRC_VMDIR)
	cd $(SRC_VMDIR) && \
	ln -s ../$(VMDK_IMG) $(VMDK_IMG)

srcvm: $(SRC_VMDIR)/$(_IMAGE).vmx $(SRC_VMDIR)/$(VMDK_IMG) ## Prepare build VM

$(DST_VMDIR):
	mkdir -p $(DST_VMDIR)

$(DST_VMDIR)/$(_IMAGE).pkr.hcl: $(_TOPDIR)/$(_IMAGE).pkr.hcl.in | $(DST_VMDIR)
	sed \
		-e "s,%%VMX_PATH%%,$(SRC_VMDIR)/$(_IMAGE).vmx,g" \
		-e "s,%%VM_NAME%%,$(_IMAGE),g" \
	< $(_TOPDIR)/$(_IMAGE).pkr.hcl.in > $@

$(DST_VMDIR)/$(_IMAGE).bootstrap.sh: $(_TOPDIR)/$(_IMAGE).bootstrap.sh | $(DST_VMDIR)
	cp $(_TOPDIR)/$(_IMAGE).bootstrap.sh $@

$(DST_VMDIR)/cloud.cfg: $(_TOPDIR)/cloud.cfg | $(DST_VMDIR)
	cp $(_TOPDIR)/cloud.cfg $@

dstvm: $(DST_VMDIR)/$(_IMAGE).pkr.hcl $(DST_VMDIR)/$(_IMAGE).bootstrap.sh $(DST_VMDIR)/cloud.cfg ## Prepare packer sources

$(DST_VMDIR)/output-buildvm/$(_IMAGE).vmx: | srcvm dstvm
	echo "building..." && \
	export PACKER_LOG=1 && \
	cd $(DST_VMDIR) && \
	packer build $(PACKER_ARGS) .
	for vmdk in $$(find $(DST_VMDIR)/output-buildvm/ -type f -name "*.vmdk"); do \
		echo "Skipping defragmentation and shrinking for $${vmdk} as it should have been done in packer" ; \
		continue ; \
		echo "Defragmenting $${vmdk}..." ; \
		$(VMWARE_DISKMANAGER) -d $${vmdk} ; \
		echo "Shrinking $${vmdk}..." ; \
		$(VMWARE_DISKMANAGER) -k $${vmdk} ; \
	done

build: $(DST_VMDIR)/output-buildvm/$(_IMAGE).vmx ## Run packer build

$(BOX_VMDIR):
	mkdir -p $(BOX_VMDIR)

$(BOX_VMDIR)/$(_IMAGE).vmx: | $(DST_VMDIR)/output-buildvm/$(_IMAGE).vmx $(BOX_VMDIR)
	for vmdk in $$(find $(DST_VMDIR)/output-buildvm/ -type f -name "*.vmdk"); do \
		vmdk_bn=$$(basename $${vmdk}) ; \
		cd $(BOX_VMDIR) && ln ../packer-dst/output-buildvm/$${vmdk_bn} $${vmdk_bn} ; \
	done
	cat $(DST_VMDIR)/output-buildvm/$(_IMAGE).vmx | egrep -v -- \
		"^displayname|^ethernet0.pcislotnumber|^extendedconfigfile|^nvme0.subnqnuuid|^nvram|^numa|^sata0:1|^remotedisplay.vnc|^uuid.bios|^uuid.location|^vc.uuid|^vmci0.id|^vmotion|^vmxstats.filename" \
	> $@

$(BOX_VMDIR)/metadata.json: $(_TOPDIR)/metadata.json.in | $(BOX_VMDIR)
	sed -e "s,%%ARCH%%,$(ARCH),g" < $(_TOPDIR)/metadata.json.in > $@

boxvm: $(BOX_VMDIR)/$(_IMAGE).vmx $(BOX_VMDIR)/metadata.json ## Prepare vagrant box VM

$(DESTDIR):
	mkdir -p $@

$(DESTDIR)/$(_IMAGE)-v$(BOX_VERSION)-$(ARCH).box: $(BOX_VMDIR)/$(_IMAGE).vmx $(BOX_VMDIR)/metadata.json | $(DESTDIR)
	cd $(BOX_VMDIR) && tar -czvf $@ *

$(DESTDIR)/metadata.json: $(_TOPDIR)/metadata-box.json.in | $(DESTDIR)
	sed \
		-e "s,%%ARCH%%,$(ARCH),g" \
		-e "s,%%VERSION%%,$(BOX_VERSION),g" \
	< $(_TOPDIR)/metadata-box.json.in > $@

$(DESTDIR)/SHA256SUMS: $(DESTDIR)/$(_IMAGE)-v$(BOX_VERSION)-$(ARCH).box
	cd $(DESTDIR) && sha256sum $(_IMAGE)-v$(BOX_VERSION)-$(ARCH).box | tee $@

box: $(DESTDIR)/$(_IMAGE)-v$(BOX_VERSION)-$(ARCH).box $(DESTDIR)/metadata.json $(DESTDIR)/SHA256SUMS ## Create vagrant box

.PHONY: preclean
preclean:
	rm -rf $(SRC_VMDIR) $(DST_VMDIR) $(DESTDIR) $(BOX_VMDIR)
	rm -f $(_WORKDIR)/$(VMDK_IMG)
