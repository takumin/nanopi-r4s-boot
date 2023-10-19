BUILD_BASE_DIR              ?= /tmp/nanopi-r4s-boot
AARCH64_LINUX_CROSS_COMPILE ?= aarch64-linux-gnu-
ARM_NONE_EABI_CROSS_COMPILE ?= arm-none-eabi-
MICRO_SD_DEV_ID             ?= usb-Generic_STORAGE_DEVICE_000000000821-0:0
ENABLE_NETCONSOLE           ?= false
PREBOOT_COMMAND             ?= setenv stdout nc; setenv stdin nc; setenv stderr nc

.PHONY: default
default: atf-build u-boot-build

.PHONY: atf-build
atf-build: $(BUILD_BASE_DIR)/atf/rk3399/release/bl31/bl31.elf
$(BUILD_BASE_DIR)/atf/rk3399/release/bl31/bl31.elf:
	@$(MAKE) -C atf -j $(shell nproc) \
		CROSS_COMPILE=$(AARCH64_LINUX_CROSS_COMPILE) \
		BUILD_BASE=$(BUILD_BASE_DIR)/atf \
		PLAT=rk3399 \
		ARCH=aarch64 \
		DEBUG=0 \
		bl31

.PHONY: u-boot-defconfig
u-boot-defconfig: $(BUILD_BASE_DIR)/u-boot/.config
$(BUILD_BASE_DIR)/u-boot/.config:
	@$(MAKE) -C u-boot -j $(shell nproc) \
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
	@echo "CONFIG_BOOTP_NTPSERVER=y" >> $(BUILD_BASE_DIR)/u-boot/.config
	@echo "CONFIG_BOOTP_TIMEOFFSET=y" >> $(BUILD_BASE_DIR)/u-boot/.config
	@echo "CONFIG_CMD_SNTP=y" >> $(BUILD_BASE_DIR)/u-boot/.config
	@echo "CONFIG_BOOT_RETRY=y" >> $(BUILD_BASE_DIR)/u-boot/.config
	@echo "CONFIG_BOOT_RETRY_TIME=15" >> $(BUILD_BASE_DIR)/u-boot/.config
	@echo "CONFIG_RESET_TO_RETRY=y" >> $(BUILD_BASE_DIR)/u-boot/.config
ifeq ($(ENABLE_NETCONSOLE),true)
	@echo "CONFIG_NETCONSOLE=y" >> $(BUILD_BASE_DIR)/u-boot/.config
	@echo "CONFIG_USE_PREBOOT=y" >> $(BUILD_BASE_DIR)/u-boot/.config
	@echo "CONFIG_PREBOOT=\"$(strip $(PREBOOT_COMMAND))\"" >> $(BUILD_BASE_DIR)/u-boot/.config
endif
	@$(MAKE) -C u-boot -j $(shell nproc) \
		BL31=$(BUILD_BASE_DIR)/atf/rk3399/release/bl31/bl31.elf \
		CROSS_COMPILE=$(AARCH64_LINUX_CROSS_COMPILE) \
		O=$(BUILD_BASE_DIR)/u-boot \
		olddefconfig

.PHONY: u-boot-menuconfig
u-boot-menuconfig: $(BUILD_BASE_DIR)/u-boot/.config
	@$(MAKE) -C u-boot -j $(shell nproc) \
		BL31=$(BUILD_BASE_DIR)/atf/rk3399/release/bl31/bl31.elf \
		CROSS_COMPILE=$(AARCH64_LINUX_CROSS_COMPILE) \
		O=$(BUILD_BASE_DIR)/u-boot \
		menuconfig

.PHONY: u-boot-build
u-boot-build: $(BUILD_BASE_DIR)/u-boot/u-boot-rockchip.bin
$(BUILD_BASE_DIR)/u-boot/u-boot-rockchip.bin: $(BUILD_BASE_DIR)/u-boot/.config $(BUILD_BASE_DIR)/atf/rk3399/release/bl31/bl31.elf
	@$(MAKE) -C u-boot -j $(shell nproc) \
		BL31=$(BUILD_BASE_DIR)/atf/rk3399/release/bl31/bl31.elf \
		CROSS_COMPILE=$(AARCH64_LINUX_CROSS_COMPILE) \
		O=$(BUILD_BASE_DIR)/u-boot

.PHONY: flash
flash: $(BUILD_BASE_DIR)/u-boot/u-boot-rockchip.bin
	@sudo dd if=/dev/zero of=/dev/disk/by-id/$(MICRO_SD_DEV_ID) bs=1M count=16 seek=64 conv=notrunc
	@sudo sync
	@sudo partprobe
	@sudo sgdisk -Z /dev/disk/by-id/$(MICRO_SD_DEV_ID)
	@sudo sgdisk -o /dev/disk/by-id/$(MICRO_SD_DEV_ID)
	@sudo sgdisk -a 1 -n 1:64:32768 -c 1:UBoot /dev/disk/by-id/$(MICRO_SD_DEV_ID)
	@sudo sgdisk -v /dev/disk/by-id/$(MICRO_SD_DEV_ID)
	@sudo sync
	@sudo partprobe
	@sudo dd if=$(BUILD_BASE_DIR)/u-boot/u-boot-rockchip.bin of=/dev/disk/by-id/$(MICRO_SD_DEV_ID) seek=64 conv=notrunc
	@sudo sync

.PHONY: clean
clean:
	@rm -fr $(BUILD_BASE_DIR)
