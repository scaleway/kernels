CONFIG_DIR := $(shell pwd)
BUILD_DIR ?= $(CONFIG_DIR)/build
RELEASE_DIR ?= $(CONFIG_DIR)/release
CONCURRENCY ?= $(shell nproc)
PLATFORM_ARCH := $(shell uname -i)
TARGET_ARCH ?= $(PLATFORM_ARCH)
KMAKE := $(MAKE) -C $(KERNEL_SRC_DIR) -j$(CONCURRENCY)

CONFIG_DEP :=
BUILD_DEP :=
PACK_DEP :=

-include make.d/$(TARGET_ARCH).mk

ifneq ($(PLATFORM_ARCH), $(TARGET_ARCH))
KMAKE += $(KMAKE_CC)
endif

KVERSION= $(shell $(KMAKE) --no-print-directory kernelversion)

usage:
	@echo "make linux TARGET_ARCH=... KERNEL_SRC_DIR=... [BUILD_DIR=...] [RELEASE_DIR=...] [CONCURRENCY=...]"

clean:
	$(KMAKE) mrproper
	mv $(BUILD_DIR) $(BUILD_DIR).old
	mv $(RELEASE_DIR) $(RELEASE_DIR).old

$(BUILD_DIR) $(RELEASE_DIR):
	mkdir $@

patch:
	if [ -f patches/patch.sh ]; then bash -xe patches/patch.sh $(KERNEL_SRC_DIR); fi

kconfiglib:
	mkdir $(KERNEL_SRC_DIR)/Kconfiglib
	curl -L https://github.com/ulfalizer/Kconfiglib/tarball/master | tar -C $(KERNEL_SRC_DIR)/Kconfiglib -xz --strip-components=1
	cd $(KERNEL_SRC_DIR) && patch -p1 <Kconfiglib/makefile.patch

config: kconfiglib $(CONFIG_DEP)
	cp configs/$(TARGET_ARCH).config $(KERNEL_SRC_DIR)/.config

build: $(BUILD_DIR) $(BUILD_DEP)
	$(KMAKE) modules
	$(KMAKE) headers_install INSTALL_HDR_PATH=$(BUILD_DIR)
	$(KMAKE) modules_install INSTALL_MOD_STRIP=1 INSTALL_MOD_PATH=$(BUILD_DIR)
	find $(BUILD_DIR) -type l -delete

pack: $(RELEASE_DIR) $(PACK_DEP)
	@echo $(KVERSION) >$(RELEASE_DIR)/version
	cd $(BUILD_DIR) && tar -cf $(RELEASE_DIR)/include.tar include/*
	cp -r $(BUILD_DIR)/lib/modules $(RELEASE_DIR)/modules
	cd $(RELEASE_DIR) && tar -cf modules.tar modules
	cd $(KERNEL_SRC_DIR) && cp System.map Module.symvers modules.* include/config/kernel.release $(RELEASE_DIR)/
	cp $(KERNEL_SRC_DIR)/.config $(RELEASE_DIR)/config-$(KVERSION)
	tar -C $(RELEASE_DIR) -cJf linux-mainline-$(VERSION).tar.xz

linux: patch config build pack
