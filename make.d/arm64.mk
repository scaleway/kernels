TARGET_CC ?= /usr/bin/aarch64-linux-gnu-
KMAKE_CC := ARCH=arm64 CROSS_COMPILE=$(TARGET_CC)
BUILD_DEP += build-arm64
PACK_DEP += pack-arm64

build-arm64:
	$(KMAKE) Image

pack-arm64:
	cp $(KERNEL_SRC_DIR)/arch/arm64/boot/Image $(RELEASE_DIR)/
	cd $(RELEASE_DIR) && cp Image vmlinux-$(KVERSION)
