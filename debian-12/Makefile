#!/usr/bin/env make -f

_TOPDIR := $(realpath $(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
_SELF   := $(abspath $(lastword $(MAKEFILE_LIST)))
_IMAGE  := $(shell basename $(_TOPDIR))
REFS    += $(_SELF)

SHOW_ENV_VARS += \
	FIRMWARE \
	GUEST_OS_TYPE \
	DEBIAN12_VERSION \
	DEBIAN12_REV \
	DEBIAN12_IMAGES_URL \
	ISO_IMG_URL \
	ISO_SHASUM_URL \
	ISO_IMG \
	ISO_SHASUM \
	ISO_IMG_LOCAL_URL \
	ISO_SHASUM_LOCAL_URL

include $(_TOPDIR)/../Makefile

OS      ?= $(error OS not defined)
OSARCH  ?= $(error OSARCH not defined)
WORKDIR ?= $(error WORKDIR not defined)

_WORKDIR := $(WORKDIR)/$(_IMAGE)

ifeq ($(OSARCH),x86_64)
GUEST_OS_TYPE := debian-64
FIRMWARE ?= bios
ISO_ARCH := amd64
else ifeq ($(OSARCH),arm64)
GUEST_OS_TYPE := arm-debian-64
FIRMWARE ?= efi
ISO_ARCH := $(OSARCH)
else
$(error unknown OSARCH: $(OSARCH))
endif

DST_VMDIR ?= $(_WORKDIR)/packer-dst
BOX_VMDIR ?= $(_WORKDIR)/box
DESTDIR ?= $(_WORKDIR)/output

DEBIAN12_VERSION := 12.12.0
DEBIAN12_REV ?= $(shell date +"%Y%m%d").1

DEBIAN12_IMAGES_URL := https://cdimage.debian.org/cdimage/archive/$(DEBIAN12_VERSION)/$(ISO_ARCH)/iso-cd

ISO_IMG_URL := $(DEBIAN12_IMAGES_URL)/debian-$(DEBIAN12_VERSION)-$(ISO_ARCH)-netinst.iso
ISO_SHASUM_URL := $(DEBIAN12_IMAGES_URL)/SHA256SUMS

ISO_IMG := $(shell basename $(ISO_IMG_URL))
ISO_SHASUM := $(shell basename $(ISO_SHASUM_URL))
ISO_IMG_LOCAL_URL := file://$(_WORKDIR)/$(ISO_IMG)
ISO_SHASUM_LOCAL_URL := file://$(_WORKDIR)/$(ISO_SHASUM)

VMWARE_DISKMANAGER ?= /Applications/VMware\ Fusion.app/Contents/Library/vmware-vdiskmanager

$(_WORKDIR):
	mkdir -p "$@"

$(_WORKDIR)/$(ISO_IMG): | $(_WORKDIR)
	cd $(_WORKDIR) && \
	curl -fsSL $(ISO_SHASUM_URL) | grep -- "$(ISO_IMG)" >"$(ISO_SHASUM)" && \
	curl -fLO --progress-bar $(ISO_IMG_URL) && \
	sha256sum -c $(ISO_SHASUM)

fetch: $(_WORKDIR)/$(ISO_IMG) ## Fetch Debian 12 ISO image

srcvm:
	$(error this builder does not require srcvm)

$(DST_VMDIR):
	mkdir -p $(DST_VMDIR)

$(DST_VMDIR)/$(_IMAGE).pkr.hcl: $(_TOPDIR)/$(_IMAGE).pkr.hcl.in | $(DST_VMDIR)
	sed \
		-e "s,%%FIRMWARE%%,$(FIRMWARE),g" \
		-e "s,%%OSARCH%%,$(OSARCH),g" \
		-e "s,%%ISO_ARCH%%,$(ISO_ARCH),g" \
		-e "s,%%GUEST_OS_TYPE%%,$(GUEST_OS_TYPE),g" \
		-e "s,%%ISO_URL%%,$(ISO_IMG_LOCAL_URL),g" \
		-e "s,%%ISO_CHECKSUM%%,file:$(ISO_SHASUM_LOCAL_URL),g" \
		-e "s,%%VM_NAME%%,$(_IMAGE),g" \
		-e "s,%%HTTP_DIRECTORY%%,$(TOPDIR)/http,g" \
	< $(_TOPDIR)/$(_IMAGE).pkr.hcl.in > $@

$(DST_VMDIR)/$(_IMAGE)-$(ISO_ARCH).pkrvars.hcl: $(_IMAGE)-$(ISO_ARCH).pkrvars.hcl
	cp $(_IMAGE)-$(ISO_ARCH).pkrvars.hcl $@

$(DST_VMDIR)/debian-12.bootstrap.sh: $(_TOPDIR)/debian-12.bootstrap.sh | $(DST_VMDIR)
	cp $(_TOPDIR)/debian-12.bootstrap.sh $@

$(DST_VMDIR)/cloud.cfg: $(_TOPDIR)/cloud.cfg | $(DST_VMDIR)
	cp $(_TOPDIR)/cloud.cfg $@

dstvm: $(_WORKDIR)/$(ISO_IMG) $(DST_VMDIR)/$(_IMAGE).pkr.hcl $(DST_VMDIR)/$(_IMAGE)-$(ISO_ARCH).pkrvars.hcl $(DST_VMDIR)/debian-12.bootstrap.sh $(DST_VMDIR)/cloud.cfg ## Prepare packer sources

$(DST_VMDIR)/output-buildvm/$(_IMAGE).vmx: | dstvm
	echo "building..." && \
	export PACKER_LOG=1 && \
	cd $(DST_VMDIR) && \
	packer build $(PACKER_ARGS) --var-file=$(_IMAGE)-$(ISO_ARCH).pkrvars.hcl .
	for vmdk in $$(find $(DST_VMDIR)/output-buildvm/ -type f -name "$$(grep -- vmdk $@ | cut -d '"' -f 2)"); do \
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
		cd $(BOX_VMDIR) && ln -h ../packer-dst/output-buildvm/$${vmdk_bn} $${vmdk_bn} ; \
	done
	cat $(DST_VMDIR)/output-buildvm/$(_IMAGE).vmx | egrep -v -- \
		"^displayname|^ethernet0.pcislotnumber|^extendedconfigfile|^nvme0.subnqnuuid|^nvram|^numa|^sata0:1|^remotedisplay.vnc|^uuid.bios|^uuid.location|^vc.uuid|^vmci0.id|^vmotion|^vmxstats.filename" \
	> $@

$(BOX_VMDIR)/metadata.json: $(_TOPDIR)/metadata.json.in | $(BOX_VMDIR)
	sed -e "s,%%ARCH%%,$(ARCH),g" < $(_TOPDIR)/metadata.json.in > $@

boxvm: $(BOX_VMDIR)/$(_IMAGE).vmx $(BOX_VMDIR)/metadata.json ## Prepare vagrant box VM

$(DESTDIR):
	mkdir -p $@

$(DESTDIR)/$(_IMAGE)-v$(DEBIAN12_VERSION)-$(DEBIAN12_REV)-$(ARCH).box: $(BOX_VMDIR)/$(_IMAGE).vmx $(BOX_VMDIR)/metadata.json | $(DESTDIR)
	cd $(BOX_VMDIR) && tar -czvf $@ *

$(DESTDIR)/metadata.json: $(_TOPDIR)/metadata-box.json.in | $(DESTDIR)
	sed \
		-e "s,%%ARCH%%,$(ARCH),g" \
		-e "s,%%VERSION%%,$(DEBIAN12_VERSION)-$(DEBIAN12_REV),g" \
	< $(_TOPDIR)/metadata-box.json.in > $@

$(DESTDIR)/SHA256SUMS: $(DESTDIR)/$(_IMAGE)-v$(DEBIAN12_VERSION)-$(DEBIAN12_REV)-$(ARCH).box
	cd $(DESTDIR) && sha256sum $(_IMAGE)-v$(DEBIAN12_VERSION)-$(DEBIAN12_REV)-$(ARCH).box | tee $@

box: $(DESTDIR)/$(_IMAGE)-v$(DEBIAN12_VERSION)-$(DEBIAN12_REV)-$(ARCH).box $(DESTDIR)/metadata.json $(DESTDIR)/SHA256SUMS ## Create vagrant box

.PHONY: preclean
preclean:
	rm -rf $(DST_VMDIR) $(DESTDIR) $(BOX_VMDIR)
