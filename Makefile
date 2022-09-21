BUILD_BASE_DIR              ?= /tmp/nanopi-r4s-boot
AARCH64_LINUX_CROSS_COMPILE ?= aarch64-linux-gnu-
ARM_NONE_EABI_CROSS_COMPILE ?= arm-none-eabi-

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
	@file $(BUILD_BASE_DIR)/atf/rk3399/release/bl31/bl31.elf

.PHONY: u-boot
u-boot: atf
	@$(MAKE) -C $@ -j $(shell nproc) \
		CROSS_COMPILE=$(AARCH64_LINUX_CROSS_COMPILE) \
		O=$(BUILD_BASE_DIR)/u-boot \
		nanopi-r4s-rk3399_defconfig
	@cp $(BUILD_BASE_DIR)/atf/rk3399/release/bl31/bl31.elf $(BUILD_BASE_DIR)/u-boot
	@$(MAKE) -C $@ -j $(shell nproc) \
		CROSS_COMPILE=$(AARCH64_LINUX_CROSS_COMPILE) \
		O=$(BUILD_BASE_DIR)/u-boot

.PHONY: clean
clean:
	@rm -fr $(BUILD_BASE_DIR)
