BUILD_BASE_DIR              ?= /tmp/nanopi-r4s-boot
AARCH64_LINUX_CROSS_COMPILE ?= aarch64-linux-gnu-
ARM_NONE_EABI_CROSS_COMPILE ?= arm-none-eabi-
MICRO_SD_DEV_ID             ?= usb-TS-RDF5_SD_Transcend_000000000037-0:0
PREBOOT_COMMAND             ?= \
	setenv autoload dhcp; \
	dhcp; \
	if env exists serverip; then \
		setenv ncip \$$serverip; \
		setenv stdin nc; \
		setenv stdout nc; \
		setenv stderr nc; \
	fi; \
	version; \
	if env exists ntpserverip; then sntp; fi; \
	if test ! env exists pxeuuid; then uuid pxeuuid; fi;

define APT_GET_INSTALL
	@dpkg -l | awk '{print $$2}' | sed -E '1,5d;s/:.*$$//g' | grep -q '^$(1)$$' || apt-get install --no-install-recommends -y $(1)
endef

.PHONY: default
default: atf build

.PHONY: req
req:
	$(call APT_GET_INSTALL,gcc)
	$(call APT_GET_INSTALL,gcc-arm-none-eabi)
	$(call APT_GET_INSTALL,crossbuild-essential-arm64)
	$(call APT_GET_INSTALL,bison)
	$(call APT_GET_INSTALL,flex)
	$(call APT_GET_INSTALL,device-tree-compiler)
	$(call APT_GET_INSTALL,swig)
	$(call APT_GET_INSTALL,python3-dev)
	$(call APT_GET_INSTALL,python3-pyelftools)
	$(call APT_GET_INSTALL,python3-setuptools)
	$(call APT_GET_INSTALL,libssl-dev)
	$(call APT_GET_INSTALL,libgnutls28-dev)
	$(call APT_GET_INSTALL,uuid-dev)

.PHONY: docker
docker:
	@docker build -t nanopi-r4s-uboot-builder .

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
	@echo "CONFIG_DM_RESET=y" >> $(BUILD_BASE_DIR)/u-boot/.config
	@echo "CONFIG_BOOTP_NTPSERVER=y" >> $(BUILD_BASE_DIR)/u-boot/.config
	@echo "CONFIG_BOOTP_TIMEOFFSET=y" >> $(BUILD_BASE_DIR)/u-boot/.config
	@echo "CONFIG_BOOTP_BOOTFILESIZE=y" >> $(BUILD_BASE_DIR)/u-boot/.config
	@echo "CONFIG_PROT_TCP=y" >> $(BUILD_BASE_DIR)/u-boot/.config
	@echo "CONFIG_PROT_TCP_SACK=y" >> $(BUILD_BASE_DIR)/u-boot/.config
	@echo "CONFIG_IPV6=y" >> $(BUILD_BASE_DIR)/u-boot/.config
	@echo "CONFIG_IPV6_ROUTER_DISCOVERY=y" >> $(BUILD_BASE_DIR)/u-boot/.config
	@echo "CONFIG_CMD_UUID=y" >> $(BUILD_BASE_DIR)/u-boot/.config
	@echo "CONFIG_CMD_FS_UUID=y" >> $(BUILD_BASE_DIR)/u-boot/.config
	@echo "CONFIG_CMD_SQUASHFS=y" >> $(BUILD_BASE_DIR)/u-boot/.config
	@echo "CONFIG_FS_SQUASHFS=y" >> $(BUILD_BASE_DIR)/u-boot/.config
	@echo "CONFIG_CMD_DNS=y" >> $(BUILD_BASE_DIR)/u-boot/.config
	@echo "CONFIG_CMD_SNTP=y" >> $(BUILD_BASE_DIR)/u-boot/.config
	@echo "CONFIG_CMD_WGET=y" >> $(BUILD_BASE_DIR)/u-boot/.config
	@echo "CONFIG_BOOT_RETRY=y" >> $(BUILD_BASE_DIR)/u-boot/.config
	@echo "CONFIG_BOOT_RETRY_TIME=30" >> $(BUILD_BASE_DIR)/u-boot/.config
	@echo "CONFIG_RESET_TO_RETRY=y" >> $(BUILD_BASE_DIR)/u-boot/.config
	@echo "CONFIG_NETCONSOLE=y" >> $(BUILD_BASE_DIR)/u-boot/.config
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

.PHONY: build
build: $(BUILD_BASE_DIR)/u-boot/u-boot-rockchip.bin
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
	@rm -fr $(BUILD_BASE_DIR)
