TARGET_CC ?= /usr/bin/
KMAKE_CC := ARCH=x86_64 CROSS_COMPILE=$(TARGET_CC)
BUILD_DEP += build-x86_64
PACK_DEP += pack-x86_64

build-x86_64:
	$(KMAKE) bzImage

pack-x86_64:
	cp $(KERNEL_SRC_DIR)/arch/x86_64/boot/bzImage $(RELEASE_DIR)/
	cd $(RELEASE_DIR) && cp bzImage bzImage-$(KVERSION)
	cd $(RELEASE_DIR) && cp bzImage vmlinuz-$(KVERSION)
