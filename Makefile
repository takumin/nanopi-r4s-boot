BUILD_BASE_DIR              ?= /tmp/nanopi-r4s-boot
AARCH64_LINUX_CROSS_COMPILE ?= aarch64-linux-gnu-
ARM_NONE_EABI_CROSS_COMPILE ?= arm-none-eabi-
MICRO_SD_DEV_ID             ?= usb-Generic_STORAGE_DEVICE_000000000821-0:0

.PHONY: default
default: atf u-boot

.PHONY: atf
atf:
	@$(MAKE) -C $@ -j $(shell nproc) \
		CROSS_COMPILE=$(AARCH64_LINUX_CROSS_COMPILE) \
		BUILD_BASE=$(BUILD_BASE_DIR)/atf \
		PLAT=rk3399 \
		ARCH=aarch64 \
		DEBUG=0 \
		bl31

.PHONY: u-boot
u-boot: atf
	@$(MAKE) -C $@ -j $(shell nproc) \
		BL31=$(BUILD_BASE_DIR)/atf/rk3399/release/bl31/bl31.elf \
		CROSS_COMPILE=$(AARCH64_LINUX_CROSS_COMPILE) \
		O=$(BUILD_BASE_DIR)/u-boot \
		nanopi-r4s-rk3399_defconfig
	@sed -i -E 's/^CONFIG_BOOTDELAY=.*/CONFIG_BOOTDELAY=0/' $(BUILD_BASE_DIR)/u-boot/.config
	@echo "CONFIG_MISC=y" >> $(BUILD_BASE_DIR)/u-boot/.config
	@echo "CONFIG_SPL_MISC=y" >> $(BUILD_BASE_DIR)/u-boot/.config
	@echo "CONFIG_TPL_MISC=y" >> $(BUILD_BASE_DIR)/u-boot/.config
	@echo "CONFIG_MISC_INIT_R=y" >> $(BUILD_BASE_DIR)/u-boot/.config
	@echo "CONFIG_ROCKCHIP_EFUSE=y" >> $(BUILD_BASE_DIR)/u-boot/.config
	@$(MAKE) -C $@ -j $(shell nproc) \
		BL31=$(BUILD_BASE_DIR)/atf/rk3399/release/bl31/bl31.elf \
		CROSS_COMPILE=$(AARCH64_LINUX_CROSS_COMPILE) \
		O=$(BUILD_BASE_DIR)/u-boot \
		olddefconfig
	@$(MAKE) -C $@ -j $(shell nproc) \
		BL31=$(BUILD_BASE_DIR)/atf/rk3399/release/bl31/bl31.elf \
		CROSS_COMPILE=$(AARCH64_LINUX_CROSS_COMPILE) \
		O=$(BUILD_BASE_DIR)/u-boot

.PHONY: flash
flash: u-boot
	@sudo dd if=/dev/zero of=/dev/disk/by-id/$(MICRO_SD_DEV_ID) bs=1M count=16
	@sudo sync
	@sudo sgdisk -Z /dev/disk/by-id/$(MICRO_SD_DEV_ID)
	@sudo sync
	@sudo dd if=$(BUILD_BASE_DIR)/u-boot/u-boot-rockchip.bin of=/dev/disk/by-id/$(MICRO_SD_DEV_ID) seek=64
	@sudo sync

.PHONY: clean
clean:
	@rm -fr $(BUILD_BASE_DIR)
