CONFIG_DIR := $(shell pwd)
BUILD_DIR ?= $(CONFIG_DIR)/build
RELEASE_DIR ?= $(CONFIG_DIR)/release
THREADS := $(shell nproc)
CONCURRENCY ?= $(THREADS)
PLATFORM_ARCH := $(shell uname -i)
TARGET_ARCH ?= $(PLATFORM_ARCH)
ARCH_UBUNTU := $(shell grep -w "$(TARGET_ARCH)" $(CONFIG_DIR)/architectures_map | cut -d':' -f2)

CONFIG_DEP :=
BUILD_DEP :=
PACK_DEP :=

-include make.d/$(TARGET_ARCH).mk

CC_PREFIX :=
ifdef USE_DISTCC
CC_PREFIX := distcc
endif

CROSS_COMPILE :=
ifneq ($(PLATFORM_ARCH), $(TARGET_ARCH))
CROSS_COMPILE := $(TARGET_CC_PREFIX)
endif
KMAKE := $(MAKE) -C $(KERNEL_SRC_DIR) -j$(CONCURRENCY) ARCH=$(TARGET_ARCH) CROSS_COMPILE=$(CROSS_COMPILE) CC='$(CC_PREFIX) $(CROSS_COMPILE)gcc'

KVERSION = $(shell $(KMAKE) --no-print-directory kernelversion)
REVISION ?= 1

KMAKE += LOCALVERSION="-ubuntu-zesty-rev$(REVISION)"

usage:
	@echo "make linux TARGET_ARCH=... KERNEL_SRC_DIR=... [BUILD_DIR=...] [RELEASE_DIR=...] [CONCURRENCY=...]"

clean:
	$(KMAKE) mrproper
	mv $(BUILD_DIR) $(BUILD_DIR).old
	mv $(RELEASE_DIR) $(RELEASE_DIR).old

$(BUILD_DIR) $(RELEASE_DIR):
	mkdir $@

patch:
	if [ -f $(CONFIG_DIR)/patches/patch.sh ]; then bash -xe $(CONFIG_DIR)/patches/patch.sh $(KERNEL_SRC_DIR); fi

kconfiglib:
	mkdir $(KERNEL_SRC_DIR)/Kconfiglib
	curl -L https://github.com/ulfalizer/Kconfiglib/tarball/master | tar -C $(KERNEL_SRC_DIR)/Kconfiglib -xz --strip-components=1
	cd $(KERNEL_SRC_DIR) && patch -p1 <Kconfiglib/makefile.patch

config: kconfiglib $(CONFIG_DEP)
	cd $(KERNEL_SRC_DIR) && debian/rules debian/control && debian/rules genconfigs
	AKD_BASE=$(KERNEL_SRC_DIR)/CONFIGS/$(ARCH_UBUNTU)-config.flavour.generic AKD_OVERLAY=$(CONFIG_DIR)/configs/$(TARGET_ARCH).config \
		AKD_OUTPUT=$(KERNEL_SRC_DIR)/.config $(KMAKE) scriptconfig ARCH=$(TARGET_ARCH) SCRIPT=$(CONFIG_DIR)/akd.py

build: $(BUILD_DIR) $(BUILD_DEP)
	$(KMAKE) modules
	$(KMAKE) headers_install INSTALL_HDR_PATH=$(BUILD_DIR)
	$(KMAKE) modules_install INSTALL_MOD_STRIP=1 INSTALL_MOD_PATH=$(BUILD_DIR)
	find $(BUILD_DIR) -type l -delete

pack: $(RELEASE_DIR) $(PACK_DEP)
	@echo $(KVERSION) >$(RELEASE_DIR)/version
	cd $(BUILD_DIR) && tar --owner=0 --group=0 -cf $(RELEASE_DIR)/include.tar include/*
	cp -r $(BUILD_DIR)/lib/modules $(RELEASE_DIR)/modules
	cd $(RELEASE_DIR) && tar --owner=0 --group=0 -cf modules.tar modules
	cd $(KERNEL_SRC_DIR) && cp System.map Module.symvers modules.* include/config/kernel.release $(RELEASE_DIR)/
	cp $(KERNEL_SRC_DIR)/.config $(RELEASE_DIR)/config
	cd $(RELEASE_DIR) && ln -sr config config-$(KVERSION)
	cd $(RELEASE_DIR) && tar --owner=0 --group=0 -c * | xz -T $(THREADS) >linux.tar.xz

linux: patch config build pack
