BUILD_BASE_DIR              ?= /tmp/nanopi-r4s-boot
BUILDER_IMAGE_NAME          ?= takumi/nanopi-r4s-uboot-builder
AARCH64_LINUX_CROSS_COMPILE ?= aarch64-linux-gnu-
ARM_NONE_EABI_CROSS_COMPILE ?= arm-none-eabi-
MICRO_SD_DEV_ID             ?= usb-TS-RDF5_SD_Transcend_000000000037-0:0
PREBOOT_COMMAND             ?= \
	setenv autoload no; \
	dhcp; \
	if env exists serverip; then \
		setenv ncip \$$serverip; \
		setenv stdin nc; \
		setenv stdout nc; \
		setenv stderr nc; \
	fi; \
	version; \
	if env exists ntpserverip; then sntp; fi; \
	if test ! env exists pxeuuid; then uuid pxeuuid; fi; \
	setenv board rk3399-nanopi-r4s; \
	setenv board_name rk3399-nanopi-r4s; \
	setenv boot_targets "mmc0 pxe dhcp";

.PHONY: default
default: build

.PHONY: docker
docker:
	@docker build -t $(BUILDER_IMAGE_NAME):latest .

.PHONY: build
build:
	@docker run --rm -i -t -v $(CURDIR):/build -v $(BUILD_BASE_DIR):$(BUILD_BASE_DIR) $(BUILDER_IMAGE_NAME):latest make image

.PHONY: atf
atf: $(BUILD_BASE_DIR)/atf/rk3399/release/bl31/bl31.elf
$(BUILD_BASE_DIR)/atf/rk3399/release/bl31/bl31.elf:
	@$(MAKE) -C atf -j $(shell nproc) \
		CROSS_COMPILE=$(AARCH64_LINUX_CROSS_COMPILE) \
		BUILD_BASE=$(BUILD_BASE_DIR)/atf \
		PLAT=rk3399 \
		ARCH=aarch64 \
		DEBUG=0 \
		bl31

.PHONY: defconfig
defconfig: $(BUILD_BASE_DIR)/u-boot/.config
$(BUILD_BASE_DIR)/u-boot/.config:
	@$(MAKE) -C u-boot -j $(shell nproc) \
		BL31=$(BUILD_BASE_DIR)/atf/rk3399/release/bl31/bl31.elf \
		CROSS_COMPILE=$(AARCH64_LINUX_CROSS_COMPILE) \
		O=$(BUILD_BASE_DIR)/u-boot \
		nanopi-r4s-rk3399_defconfig
	@sed -i -E 's/^CONFIG_BOOTDELAY=.*/CONFIG_BOOTDELAY=3/' $(BUILD_BASE_DIR)/u-boot/.config
	################################################################################
	# Enabled TCP
	################################################################################
	@echo "CONFIG_PROT_TCP=y" >> $(BUILD_BASE_DIR)/u-boot/.config
	@echo "CONFIG_PROT_TCP_SACK=y" >> $(BUILD_BASE_DIR)/u-boot/.config
	################################################################################
	# Enabled IPv6
	################################################################################
	@echo "CONFIG_IPV6=y" >> $(BUILD_BASE_DIR)/u-boot/.config
	@echo "CONFIG_IPV6_ROUTER_DISCOVERY=y" >> $(BUILD_BASE_DIR)/u-boot/.config
	################################################################################
	# Maintenance Commands
	################################################################################
	@echo "CONFIG_CMD_DNS=y" >> $(BUILD_BASE_DIR)/u-boot/.config
	@echo "CONFIG_CMD_WGET=y" >> $(BUILD_BASE_DIR)/u-boot/.config
	################################################################################
	# BOOTP/DHCP - Set pxeuuid with preboot command
	################################################################################
	@echo "CONFIG_CMD_UUID=y" >> $(BUILD_BASE_DIR)/u-boot/.config
	################################################################################
	# BOOTP/DHCP - Enabled SNTP
	################################################################################
	@echo "CONFIG_BOOTP_NTPSERVER=y" >> $(BUILD_BASE_DIR)/u-boot/.config
	@echo "CONFIG_CMD_SNTP=y" >> $(BUILD_BASE_DIR)/u-boot/.config
	################################################################################
	# BOOTP/DHCP - Prefer Server IP
	################################################################################
	@echo "CONFIG_BOOTP_PREFER_SERVERIP=y" >> $(BUILD_BASE_DIR)/u-boot/.config
	################################################################################
	# BOOTP/DHCP - Request pxelinux.configfile (DHCP Option 209)
	################################################################################
	@echo "CONFIG_BOOTP_PXE_DHCP_OPTION=y" >> $(BUILD_BASE_DIR)/u-boot/.config
	################################################################################
	# Boot Retry
	################################################################################
	@echo "CONFIG_BOOT_RETRY=y" >> $(BUILD_BASE_DIR)/u-boot/.config
	@echo "CONFIG_BOOT_RETRY_TIME=30" >> $(BUILD_BASE_DIR)/u-boot/.config
	@echo "CONFIG_RESET_TO_RETRY=y" >> $(BUILD_BASE_DIR)/u-boot/.config
	################################################################################
	# Network Console
	################################################################################
	@echo "CONFIG_NETCONSOLE=y" >> $(BUILD_BASE_DIR)/u-boot/.config
	################################################################################
	# Pre Boot Command
	################################################################################
	@echo "CONFIG_USE_PREBOOT=y" >> $(BUILD_BASE_DIR)/u-boot/.config
	@echo "CONFIG_PREBOOT=\"$(strip $(PREBOOT_COMMAND))\"" >> $(BUILD_BASE_DIR)/u-boot/.config
	@$(MAKE) -C u-boot -j $(shell nproc) \
		BL31=$(BUILD_BASE_DIR)/atf/rk3399/release/bl31/bl31.elf \
		CROSS_COMPILE=$(AARCH64_LINUX_CROSS_COMPILE) \
		O=$(BUILD_BASE_DIR)/u-boot \
		olddefconfig

.PHONY: menuconfig
menuconfig: $(BUILD_BASE_DIR)/u-boot/.config
	@$(MAKE) -C u-boot -j $(shell nproc) \
		BL31=$(BUILD_BASE_DIR)/atf/rk3399/release/bl31/bl31.elf \
		CROSS_COMPILE=$(AARCH64_LINUX_CROSS_COMPILE) \
		O=$(BUILD_BASE_DIR)/u-boot \
		menuconfig

.PHONY: savedefconfig
savedefconfig: $(BUILD_BASE_DIR)/u-boot/defconfig
$(BUILD_BASE_DIR)/u-boot/defconfig: $(BUILD_BASE_DIR)/u-boot/.config
	@$(MAKE) -C u-boot -j $(shell nproc) \
		BL31=$(BUILD_BASE_DIR)/atf/rk3399/release/bl31/bl31.elf \
		CROSS_COMPILE=$(AARCH64_LINUX_CROSS_COMPILE) \
		O=$(BUILD_BASE_DIR)/u-boot \
		savedefconfig

.PHONY: diffdefconfig
diffdefconfig: $(BUILD_BASE_DIR)/u-boot/defconfig.diff
$(BUILD_BASE_DIR)/u-boot/defconfig.diff: $(BUILD_BASE_DIR)/u-boot/defconfig
	@diff -u $(CURDIR)/u-boot/configs/nanopi-r4s-rk3399_defconfig \
		$(BUILD_BASE_DIR)/u-boot/defconfig > $(BUILD_BASE_DIR)/u-boot/defconfig.diff || true

.PHONY: image
image: $(BUILD_BASE_DIR)/u-boot/u-boot-rockchip.bin
$(BUILD_BASE_DIR)/u-boot/u-boot-rockchip.bin: $(BUILD_BASE_DIR)/atf/rk3399/release/bl31/bl31.elf $(BUILD_BASE_DIR)/u-boot/.config
	@$(MAKE) -C u-boot -j $(shell nproc) \
		BL31=$(BUILD_BASE_DIR)/atf/rk3399/release/bl31/bl31.elf \
		CROSS_COMPILE=$(AARCH64_LINUX_CROSS_COMPILE) \
		O=$(BUILD_BASE_DIR)/u-boot

.PHONY: flash
flash:
	@if [ ! -e "u-boot-rockchip.bin" ]; then \
		echo "Not Found: u-boot-rockchip.bin"; \
		exit 1; \
	fi
	@if [ ! -e "/dev/disk/by-id/$(MICRO_SD_DEV_ID)" ]; then \
		echo "Not Found: /dev/disk/by-id/$(MICRO_SD_DEV_ID)"; \
		exit 1; \
	fi
	@sudo sync
	@sudo partprobe
	@sudo sync
	@sudo sgdisk -Z /dev/disk/by-id/$(MICRO_SD_DEV_ID)
	@sudo sgdisk -o /dev/disk/by-id/$(MICRO_SD_DEV_ID)
	@sudo sgdisk -a 1 -n 1:64:32768           -c 1:UBoot  /dev/disk/by-id/$(MICRO_SD_DEV_ID)
	@sudo sgdisk      -n 2::512MiB  -t 2:ef00 -c 2:ESP    /dev/disk/by-id/$(MICRO_SD_DEV_ID)
	@sudo sgdisk      -n 3::-1                -c 3:System /dev/disk/by-id/$(MICRO_SD_DEV_ID)
	@sudo sgdisk -p /dev/disk/by-id/$(MICRO_SD_DEV_ID)
	@sudo sync
	@sudo partprobe
	@sudo sync
	@sudo dd if=/dev/zero of=/dev/disk/by-id/$(MICRO_SD_DEV_ID) bs=1M count=16 seek=64 conv=notrunc
	@sudo sync
	@sudo partprobe
	@sudo sync
	@sudo dd if=u-boot-rockchip.bin of=/dev/disk/by-id/$(MICRO_SD_DEV_ID) seek=64 conv=notrunc
	@sudo sync
	@sudo partprobe
	@sudo sync
	@sudo mkfs.fat -F 32 /dev/disk/by-id/$(MICRO_SD_DEV_ID)-part2
	@sudo sync

.PHONY: clean
clean:
	@sudo rm -fr $(BUILD_BASE_DIR)
