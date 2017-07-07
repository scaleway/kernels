TARGET_CC_PREFIX ?= /usr/bin/arm-linux-gnueabihf-
CONFIG_DEP += config-arm
BUILD_DEP += build-arm
PACK_DEP += pack-arm

config-arm:
	cp $(CONFIG_DIR)/dts/scaleway-c1.dts $(KERNEL_SRC_DIR)/arch/arm/boot/dts
	sed -i -r '/always\s+:=/i dtb-y += scaleway-c1.dtb' $(KERNEL_SRC_DIR)/arch/arm/boot/dts/Makefile

build-arm:
	$(KMAKE) LOADADDR=0x8000 uImage
	$(KMAKE) dtbs

pack-arm:
	cp $(KERNEL_SRC_DIR)/arch/arm/boot/uImage $(RELEASE_DIR)/
	cd $(RELEASE_DIR) && cp uImage uImage-$(KVERSION)
	cp $(KERNEL_SRC_DIR)/arch/arm/boot/zImage $(RELEASE_DIR)/
	cd $(RELEASE_DIR) && cp zImage zImage-$(KVERSION)
	cp $(KERNEL_SRC_DIR)/arch/arm/boot/Image $(RELEASE_DIR)/
	cd $(RELEASE_DIR) && cp Image Image-$(KVERSION)
	cp $(KERNEL_SRC_DIR)/arch/arm/boot/dts/scaleway-c1.dtb $(RELEASE_DIR)/
	cd $(RELEASE_DIR) && cp uImage vmlinuz-$(KVERSION)
