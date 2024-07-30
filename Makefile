
TOPDIR = $(abspath .)
SHELL := sh
include ./build/Makefile.tls
include ./build/color.mak
sinclude ./.config
sinclude ./.hwconfig
sinclude ./crossgcc/toolchain.config

export TOOLCHAIN_AARCH32_PATH TOOLCHAIN_AARCH32_PREFIX
export TOOLCHAIN_AARCH64_PATH TOOLCHAIN_AARCH64_PREFIX
CROSS_ARM64_COMPILE = $(TOOLCHAIN_AARCH64_PATH)/bin/$(TOOLCHAIN_AARCH64_PREFIX)-
CROSS_ARM64_XBOOT_COMPILE = $(TOOLCHAIN_AARCH32_PATH)/bin/$(TOOLCHAIN_AARCH32_PREFIX)-

NEED_ISP ?= 0
ZEBU_RUN ?= 0
BOOT_FROM ?= EMMC
IS_ASSIGN_DTB ?= 0
BOOT_CHIP ?= C_CHIP
CHIP ?= SP7350
ZMEM ?= 0
SECURE ?= 0
ENCRYPTION ?= 0
SB_FLAG = `expr $(SECURE) + $(ENCRYPTION) \* 2 `

BOOT_KERNEL_FROM_TFTP ?= 0
TFTP_SERVER_IP ?=
TFTP_SERVER_PATH ?=
BOARD_MAC_ADDR ?=
USER_NAME ?=

CONFIG_ROOT = ./.config
HW_CONFIG_ROOT = ./.hwconfig
ISP_SHELL = isp.sh
NOR_ISP_SHELL = nor_isp.sh
PART_SHELL = part.sh
SDCARD_BOOT_SHELL = sdcard_boot.sh

BUILD_PATH = build
XBOOT_PATH = boot/xboot
UBOOT_PATH = boot/uboot
LINUX_PATH = linux/kernel
ROOTFS_PATH = linux/rootfs
FIRMWARE_PATH = firmware/arduino_core_sunplus
IPACK_PATH = ipack
OUT_PATH = out
SECURE_TOOL_PATH = $(TOPDIR)/$(BUILD_PATH)/tools/secure_sp7350/secure
FREERTOS_PATH = $(IPACK_PATH)
FIP_PATH = boot/trusted-firmware-a
KERNELRELEASE = $(shell cat $(LINUX_PATH)/include/config/kernel.release 2> /dev/null)

XBOOT_BIN = xboot.img
UBOOT_BIN = u-boot.img
FIP_BIN = fip.img
KERNEL_BIN = uImage
DTB = dtb
VMLINUX = vmlinux
ROOTFS_DIR = $(ROOTFS_PATH)/initramfs/disk
BUILDROOT_DIR = $(ROOTFS_PATH)/initramfs/buildroot
ROOTFS_IMG = rootfs.img
FREERTOS_IMG = freertos.img

CROSS_COMPILE_FOR_XBOOT =$(CROSS_ARM64_XBOOT_COMPILE)
CROSS_COMPILE_FOR_LINUX =$(CROSS_ARM64_COMPILE)
KERNEL_ARM64_BIN = Image.gz

CROSS_COMPILE_FOR_ROOTFS =$(CROSS_COMPILE_FOR_LINUX)

ARCH_XBOOT = arm
ARCH_UBOOT = $(ARCH_XBOOT)

XBOOT_LPDDR4_MAX = $$((192 * 1024))

SDCARD_BOOT_MODE = 3

# xboot uses name field of u-boot header to differeciate between C-chip boot image
# and P-chip boot image. If name field has prefix "uboot_B", it boots from P chip.
img_name = "uboot_pentagram_board"

ifeq ($(BOOT_FROM),SPINOR)
	SPINOR = 1
else
	SPINOR = 0
endif

ifeq ($(BOOT_FROM),NOR_JFFS2)
	NOR_JFFS2 = 1
else
	NOR_JFFS2 = 0
endif

# 0: uImage, 1: qk_boot image (uncompressed)
USE_QK_BOOT=0

SPI_BIN = spi_all.bin
DOWN_TOOL = down_32M.exe
SECURE_PATH ?=

OVERLAYFS ?= 0

.PHONY: all buildroot xboot uboot kenel rom clean distclean config init check rootfs info firmware freertos toolchain
.PHONY: dtb spirom isp tool_isp kconfig uconfig xconfig bconfig

# rootfs image is created by :
# make initramfs -> re-create initial disk/
# make kernel    -> install kernel modules to disk/lib/modules/
# make rootfs    -> create rootfs image from disk/
# or use buildroot to create 

all: check
	@$(MAKE) buildroot
	@$(MAKE) xboot
	@$(MAKE) dtb
	@$(MAKE) uboot
	@$(MAKE) fip
	@$(MAKE) firmware
	@if [ "$(BOOT_FROM)" = "SPINOR" ]; then \
		$(MAKE) rootfs ; \
	fi
	@$(MAKE) kernel
	@if [ "$(BOOT_FROM)" != "SPINOR" ]; then \
		$(MAKE) rootfs ; \
	fi
	@$(MAKE) rom

firmware:
	@$(ECHO) "[arduino] make $(CHIP) firmware" ;
	@$(MAKE) -C $(FIRMWARE_PATH) CHIP=$(CHIP) ;
	@$(CHMOD) -x $(FIRMWARE_PATH)/bin/firmware ;
	@$(CP) $(FIRMWARE_PATH)/bin/firmware linux/rootfs/initramfs/disk/lib/firmware ;

#xboot build
xboot: check
	@$(MAKE) ARCH=$(ARCH_XBOOT) $(MAKE_JOBS) -C $(XBOOT_PATH) CROSS=$(CROSS_COMPILE_FOR_XBOOT) SECURE=$(SECURE) ENCRYPTION=$(ENCRYPTION) all
	@$(MAKE) secure SECURE_PATH=xboot
	@$(MAKE) warmboot

#warmboot build
warmboot:
	@$(MAKE) -C $(XBOOT_PATH)/warmboot XBOOT_CROSS=$(CROSS_COMPILE_FOR_XBOOT);
	@$(CHMOD) -x $(XBOOT_PATH)/warmboot/warmboot ;
	@$(CP) $(XBOOT_PATH)/warmboot/warmboot linux/rootfs/initramfs/disk/lib/firmware ;


#tfa build
fip: check
	@cd optee; ./optee_build.sh $(CHIP) $(CROSS_ARM64_COMPILE); cd .. ;
	@$(MAKE) -f $(FIP_PATH)/sp7350.mk CROSS=$(CROSS_ARM64_COMPILE) build ;
	@$(MAKE) secure SECURE_PATH=fip ;
#uboot build
uboot: check
	@if [ $(BOOT_KERNEL_FROM_TFTP) -eq 1 ]; then \
		$(MAKE) ARCH=$(ARCH_UBOOT) $(MAKE_JOBS) -C $(UBOOT_PATH) all CROSS_COMPILE=$(CROSS_COMPILE_FOR_LINUX) EXT_DTB=../../linux/kernel/dtb  \
			KCPPFLAGS="-DBOOT_KERNEL_FROM_TFTP=$(BOOT_KERNEL_FROM_TFTP) -DTFTP_SERVER_IP=$(TFTP_SERVER_IP) \
			-DBOARD_MAC_ADDR=$(BOARD_MAC_ADDR) -DOVERLAYFS=$(OVERLAYFS) -DUSER_NAME=$(USER_NAME)"; \
	else \
		$(MAKE) ARCH=$(ARCH_UBOOT) $(MAKE_JOBS) -C $(UBOOT_PATH) all CROSS_COMPILE=$(CROSS_COMPILE_FOR_LINUX) EXT_DTB=../../linux/kernel/dtb \
			KCPPFLAGS="-DSPINOR=$(SPINOR) -DNOR_JFFS2=$(NOR_JFFS2) -DCOMPILE_WITH_SECURE=$(SECURE) -DOVERLAYFS=$(OVERLAYFS) -DNAND_PAGE_SIZE=$(NAND_PAGE_SIZE)"; \
	fi

	@dd if=$(TOPDIR)/$(UBOOT_PATH)/u-boot.bin of=$(TOPDIR)/$(UBOOT_PATH)/u-boot.bin  bs=1 skip=64 conv=notrunc 2>/dev/null ;
	@$(MAKE) secure SECURE_PATH=uboot

#kernel build
kernel: check
	@$(MAKE_ARCH) $(MAKE_JOBS) -C $(LINUX_PATH) all CROSS_COMPILE=$(CROSS_COMPILE_FOR_LINUX)
	@$(RM) -rf $(ROOTFS_DIR)/lib/modules/; 
	@$(MAKE_ARCH) $(MAKE_JOBS) -C $(LINUX_PATH) modules_install INSTALL_MOD_PATH=../../$(ROOTFS_DIR) CROSS_COMPILE=$(CROSS_COMPILE_FOR_LINUX);
	@$(RM) -f $(ROOTFS_DIR)/lib/modules/$(KERNELRELEASE)/build;
	@$(RM) -f $(ROOTFS_DIR)/lib/modules/$(KERNELRELEASE)/source;
	@if [ "$(BOOT_FROM)" != "SPINOR" ] && [ "$(BOOT_FROM)" != "NOR_JFFS2" ]; then \
		if [ -d ${ROOTFS_DIR} ] && [ -f $(LINUX_PATH)/.config ]; then \
			vip9000sdk64185=`grep CONFIG_v6_4_18_5=y $(LINUX_PATH)/.config`; \
			vip9000sdk64159=`grep CONFIG_v6_4_15_9=y $(LINUX_PATH)/.config`; \
			vip9000sdk64138=`grep CONFIG_v6_4_13_8=y $(LINUX_PATH)/.config`; \
			if [ "$$vip9000sdk64185" != "" ]; then	\
				$(ECHO) $(COLOR_YELLOW)"Copy VIP9000SDK files in rootfs for CONFIG_v6_4_18_5."$(COLOR_ORIGIN); \
				if [ -d ${ROOTFS_DIR}/lib64 ]; then \
					$(CP) -fa $(ROOTFS_PATH)/initramfs/prebuilt/vip9000sdk/6.4.18.5/drivers/* ${ROOTFS_DIR}/lib64; \
					$(MKDIR) -p ${ROOTFS_DIR}/usr/include; \
					$(CP) -faR $(ROOTFS_PATH)/initramfs/prebuilt/vip9000sdk/6.4.18.5/include/* ${ROOTFS_DIR}/usr/include; \
				else \
					$(CP) -fa $(ROOTFS_PATH)/initramfs/prebuilt/vip9000sdk/6.4.18.5/drivers/* ${ROOTFS_DIR}/usr/lib; \
					$(CP) -faR $(ROOTFS_PATH)/initramfs/prebuilt/vip9000sdk/6.4.18.5/include/* ${ROOTFS_DIR}/usr/include; \
				fi \
			elif [ "$$vip9000sdk64159" != "" ]; then \
				$(ECHO) $(COLOR_YELLOW)"Copy VIP9000SDK files in rootfs for CONFIG_v6_4_15_9."$(COLOR_ORIGIN); \
				if [ -d ${ROOTFS_DIR}/lib64 ]; then \
					$(CP) -fa $(ROOTFS_PATH)/initramfs/prebuilt/vip9000sdk/6.4.15.9/drivers/* ${ROOTFS_DIR}/lib64; \
					$(MKDIR) -p ${ROOTFS_DIR}/usr/include; \
					$(CP) -faR $(ROOTFS_PATH)/initramfs/prebuilt/vip9000sdk/6.4.15.9/include/* ${ROOTFS_DIR}/usr/include; \
				else \
					$(CP) -fa $(ROOTFS_PATH)/initramfs/prebuilt/vip9000sdk/6.4.15.9/drivers/* ${ROOTFS_DIR}/usr/lib; \
					$(CP) -faR $(ROOTFS_PATH)/initramfs/prebuilt/vip9000sdk/6.4.15.9/include/* ${ROOTFS_DIR}/usr/include; \
				fi \
			elif [ "$$vip9000sdk64138" != "" ]; then \
				$(ECHO) $(COLOR_YELLOW)"Copy VIP9000SDK files in rootfs for CONFIG_v6_4_13_8."$(COLOR_ORIGIN); \
				if [ -d ${ROOTFS_DIR}/lib64 ]; then \
					$(CP) -fa $(ROOTFS_PATH)/initramfs/prebuilt/vip9000sdk/6.4.13.8/drivers/* ${ROOTFS_DIR}/lib64; \
					$(MKDIR) -p ${ROOTFS_DIR}/usr/include; \
					$(CP) -faR $(ROOTFS_PATH)/initramfs/prebuilt/vip9000sdk/6.4.13.8/include/* ${ROOTFS_DIR}/usr/include; \
				else \
					$(CP) -fa $(ROOTFS_PATH)/initramfs/prebuilt/vip9000sdk/6.4.13.8/drivers/* ${ROOTFS_DIR}/usr/lib; \
					$(CP) -faR $(ROOTFS_PATH)/initramfs/prebuilt/vip9000sdk/6.4.13.8/include/* ${ROOTFS_DIR}/usr/include; \
				fi \
			fi \
		fi \
	fi
	@$(RM) -f $(LINUX_PATH)/arch/$(ARCH)/boot/$(KERNEL_ARM64_BIN);
	@$(MAKE_ARCH) $(MAKE_JOBS) -C $(LINUX_PATH) $(KERNEL_ARM64_BIN) V=0 CROSS_COMPILE=$(CROSS_COMPILE_FOR_LINUX);
	@$(MAKE) secure SECURE_PATH=kernel;

clean:
	@$(MAKE) -C $(FIRMWARE_PATH) CHIP=$(CHIP) $@
	@$(MAKE) ARCH=$(ARCH_XBOOT) -C $(XBOOT_PATH) CROSS=$(CROSS_COMPILE_FOR_XBOOT) $@
	@$(MAKE_ARCH) -C $(UBOOT_PATH) $@
	@$(MAKE_ARCH) -C $(LINUX_PATH) mrproper
	@$(MAKE_ARCH) -C $(ROOTFS_PATH) $@
	@$(MAKE) -C $(TOPDIR)/$(BUILD_PATH)/tools/isp $@
	@$(RM) -rf $(OUT_PATH)
	@cd optee; ./optee_clean.sh;cd ..;
	@$(MAKE) -C $(FIP_PATH) clean

distclean: clean
	@$(MAKE) -C $(IPACK_PATH) $@
	@$(MAKE) ARCH=$(ARCH_XBOOT) -C $(XBOOT_PATH) CROSS=$(CROSS_COMPILE_FOR_XBOOT) $@
	@$(MAKE_ARCH) -C $(UBOOT_PATH) $@
	@$(MAKE_ARCH) -C $(LINUX_PATH) $@
	@$(RM) -f $(CONFIG_ROOT)
	@$(RM) -f $(HW_CONFIG_ROOT)
	@$(MAKE) -C $(BUILDROOT_DIR) clean

__config: clean
	@if [ -z $(HCONFIG) ]; then \
		$(RM) -f $(HW_CONFIG_ROOT); \
	fi
	$(eval CROSS_COMPILE=$(shell cat $(CONFIG_ROOT) | grep 'CROSS_COMPILE=' | sed 's/CROSS_COMPILE=//g'))
	$(eval ARCH=$(shell cat $(CONFIG_ROOT) | grep 'ARCH=' | sed 's/ARCH=//g'))
	$(eval CHIP=$(shell cat $(CONFIG_ROOT) | grep 'CHIP=' | sed 's/CHIP=//g'))
	@$(MAKE) -C $(XBOOT_PATH) ARCH=$(ARCH_XBOOT) CROSS=$(CROSS_COMPILE_FOR_XBOOT) $(shell cat $(CONFIG_ROOT) | grep 'XBOOT_CONFIG=' | sed 's/XBOOT_CONFIG=//g')
	@$(MAKE_ARCH) -C $(UBOOT_PATH) clean
	@$(MAKE_ARCH) -C $(UBOOT_PATH) CROSS_COMPILE=$(CROSS_COMPILE_FOR_LINUX) $(shell cat $(CONFIG_ROOT) | grep 'UBOOT_CONFIG=' | sed 's/UBOOT_CONFIG=//g')
	@$(MAKE_ARCH) -C $(LINUX_PATH) mrproper
	@$(MAKE_ARCH) -C $(LINUX_PATH) CROSS_COMPILE=$(CROSS_COMPILE_FOR_LINUX) $(shell cat $(CONFIG_ROOT) | grep 'KERNEL_CONFIG=' | sed 's/KERNEL_CONFIG=//g')
	@$(MAKE_ARCH) initramfs
	@$(MKDIR) -p $(OUT_PATH)
	@$(MAKE) -C $(TOPDIR)/$(BUILD_PATH)/tools/isp clean
	@$(RM) -f $(TOPDIR)/$(OUT_PATH)/$(ISP_SHELL) $(TOPDIR)/$(OUT_PATH)/$(PART_SHELL) $(TOPDIR)/$(OUT_PATH)/$(NOR_ISP_SHELL)
	@$(LN) -s $(TOPDIR)/$(BUILD_PATH)/$(ISP_SHELL) $(TOPDIR)/$(OUT_PATH)/$(ISP_SHELL)
	@$(LN) -s $(TOPDIR)/$(BUILD_PATH)/$(NOR_ISP_SHELL) $(TOPDIR)/$(OUT_PATH)/$(NOR_ISP_SHELL)
	@$(LN) -s $(TOPDIR)/$(BUILD_PATH)/$(PART_SHELL) $(TOPDIR)/$(OUT_PATH)/$(PART_SHELL)
	@$(CP) -f $(IPACK_PATH)/bin/$(DOWN_TOOL) $(OUT_PATH)
	@$(ECHO) $(COLOR_YELLOW)"platform info :"$(COLOR_ORIGIN)
	$(eval ZMEM=$(shell cat $(CONFIG_ROOT) | grep 'ZMEM=' | sed 's/ZMEM=//g'))
	@$(MAKE) info

config: init
	@$(MAKE) __config
	@if [ -x /usr/local/bin/sunplus-config-ext ]; then \
		/usr/local/bin/sunplus-config-ext; \
	fi

hconfig:
	@./build/hconfig.sh
	$(MAKE) config HCONFIG="1"

dtb: check
	$(eval LINUX_DTB=$(shell cat $(CONFIG_ROOT) | grep 'LINUX_DTB=' | sed 's/LINUX_DTB=//g').dtb)

	@if [ $(IS_ASSIGN_DTB) -eq 1 ]; then \
		DTC_FLAGS=-Wno-graph_child_address \
		$(MAKE_ARCH) -C $(LINUX_PATH) $(HW_DTB) CROSS_COMPILE=$(CROSS_COMPILE_FOR_LINUX) W=1; \
		$(LN) -fs arch/$(ARCH)/boot/dts/$(HW_DTB) $(LINUX_PATH)/dtb; \
	else \
		DTC_FLAGS=-Wno-graph_child_address \
		$(MAKE_ARCH) -C $(LINUX_PATH) $(LINUX_DTB) CROSS_COMPILE=$(CROSS_COMPILE_FOR_LINUX) W=1; \
		if [ $$? -ne 0 ]; then \
			exit 1; \
		fi; \
		$(LN) -fs arch/$(ARCH)/boot/dts/$(LINUX_DTB) $(LINUX_PATH)/dtb; \
	fi

spirom_isp: check tool_isp
	@if [ -f $(XBOOT_PATH)/bin/$(XBOOT_BIN) ]; then \
		$(CP) -f $(XBOOT_PATH)/bin/$(XBOOT_BIN) $(OUT_PATH); \
	else \
		$(ECHO) $(COLOR_YELLOW)$(XBOOT_BIN)" doesn't exist."$(COLOR_ORIGIN); \
		exit 1; \
	fi
	@if [ -f $(UBOOT_PATH)/$(UBOOT_BIN) ]; then \
		$(CP) -f $(UBOOT_PATH)/$(UBOOT_BIN) $(OUT_PATH); \
	else \
		$(ECHO) $(COLOR_YELLOW)$(UBOOT_BIN)" doesn't exist."$(COLOR_ORIGIN); \
		exit 1; \
	fi
	@if [ -f $(FIP_PATH)/build/$(FIP_BIN) ]; then \
			$(CP) -f $(FIP_PATH)/build/$(FIP_BIN) $(OUT_PATH); \
	else \
		$(ECHO) $(COLOR_YELLOW) $(FIP_PATH)/build/$(FIP_BIN)" doesn't exist."$(COLOR_ORIGIN); \
		exit 1; \
	fi
	@cd out/; ./$(NOR_ISP_SHELL) $(CHIP) $(FLASH_SIZE)
	@$(RM) -f $(OUT_PATH)/$(XBOOT_BIN)
	@$(RM) -f $(OUT_PATH)/$(UBOOT_BIN)

spirom: check
	@if [ $(BOOT_KERNEL_FROM_TFTP) -eq 1 ]; then \
		$(MAKE_ARCH) -C $(IPACK_PATH) all ZEBU_RUN=$(ZEBU_RUN) BOOT_KERNEL_FROM_TFTP=$(BOOT_KERNEL_FROM_TFTP) \
		TFTP_SERVER_PATH=$(TFTP_SERVER_PATH) CHIP=$(CHIP) FLASH_SIZE=$(FLASH_SIZE); \
	else \
		$(MAKE_ARCH) -C $(IPACK_PATH) all ZEBU_RUN=$(ZEBU_RUN) CHIP=$(CHIP) FLASH_SIZE=$(FLASH_SIZE) NOR_JFFS2=$(NOR_JFFS2); \
	fi
	@if [ -f $(IPACK_PATH)/bin/$(SPI_BIN) -a "$(ZEBU_RUN)" = "0" ]; then \
		$(ECHO) $(COLOR_YELLOW)"Copy "$(SPI_BIN)" to out folder."$(COLOR_ORIGIN); \
		$(CP) -f $(IPACK_PATH)/bin/$(SPI_BIN) $(OUT_PATH); \
	fi

tool_isp:
	@$(MAKE) -C $(TOPDIR)/$(BUILD_PATH)/tools/isp FREERTOS=0 CHIP=$(CHIP) NAND_PAGE_SIZE=$(NAND_PAGE_SIZE)

isp: check tool_isp
	@if [ -f $(XBOOT_PATH)/bin/$(XBOOT_BIN) ]; then \
		$(CP) -f $(XBOOT_PATH)/bin/$(XBOOT_BIN) $(OUT_PATH); \
		$(ECHO) $(COLOR_YELLOW)"Copy "$(XBOOT_BIN)" to out folder."$(COLOR_ORIGIN); \
	else \
		$(ECHO) $(COLOR_YELLOW)$(XBOOT_BIN)" doesn't exist."$(COLOR_ORIGIN); \
		exit 1; \
	fi
	@if [ -f $(UBOOT_PATH)/$(UBOOT_BIN) ]; then \
		$(CP) -f $(UBOOT_PATH)/$(UBOOT_BIN) $(OUT_PATH); \
		$(ECHO) $(COLOR_YELLOW)"Copy "$(UBOOT_BIN)" to out folder."$(COLOR_ORIGIN); \
	else \
		$(ECHO) $(COLOR_YELLOW)$(UBOOT_BIN)" doesn't exist."$(COLOR_ORIGIN); \
		exit 1; \
	fi

	@if [ -f $(FIP_PATH)/build/$(FIP_BIN) ]; then \
		$(CP) -f $(FIP_PATH)/build/$(FIP_BIN) $(OUT_PATH); \
		$(ECHO) $(COLOR_YELLOW)"Copy "$(FIP_BIN)" to out folder."$(COLOR_ORIGIN); \
	else \
		$(ECHO) $(COLOR_YELLOW) $(FIP_PATH)/build/$(FIP_BIN)" doesn't exist."$(COLOR_ORIGIN); \
		exit 1; \
	fi

	@if [ -f $(LINUX_PATH)/$(VMLINUX) ]; then \
		if [ "$(USE_QK_BOOT)" = "1" ]; then \
			$(CP) -f $(LINUX_PATH)/$(VMLINUX) $(OUT_PATH); \
			$(ECHO) $(COLOR_YELLOW)"Copy "$(VMLINUX)" to out folder."$(COLOR_ORIGIN); \
			$(CROSS_COMPILE_FOR_LINUX)objcopy -O binary -S $(OUT_PATH)/$(VMLINUX) $(OUT_PATH)/$(VMLINUX).bin; \
			cd $(IPACK_PATH); \
			./add_uhdr.sh linux-`date +%Y%m%d-%H%M%S` $(TOPDIR)/$(OUT_PATH)/$(VMLINUX).bin $(TOPDIR)/$(OUT_PATH)/$(KERNEL_BIN) 0x308000 0x308000; \
			cd $(TOPDIR); \
			if [ -f $(OUT_PATH)/$(KERNEL_BIN) ]; then \
				$(ECHO) $(COLOR_YELLOW)"Add uhdr in "$(KERNEL_BIN)"."$(COLOR_ORIGIN); \
			else \
				$(ECHO) $(COLOR_YELLOW)"Gen "$(KERNEL_BIN)" fail."$(COLOR_ORIGIN); \
			fi; \
		else \
			if [ "$(ZEBU_RUN)" = "1" ]; then \
				$(CP) -vf $(LINUX_PATH)/arch/$(ARCH)/boot/Image $(LINUX_PATH)/arch/$(ARCH)/boot/$(KERNEL_BIN); \
			fi; \
			$(CP) -vf $(LINUX_PATH)/arch/$(ARCH)/boot/$(KERNEL_BIN) $(OUT_PATH); \
		fi; \
	else \
		$(ECHO) $(COLOR_YELLOW)$(VMLINUX)" doesn't exist."$(COLOR_ORIGIN); \
		exit 1; \
	fi
	@if [ -f $(LINUX_PATH)/$(DTB) ]; then \
		if [ "$(USE_QK_BOOT)" = "1" ]; then \
			$(CP) -f $(LINUX_PATH)/$(DTB) $(OUT_PATH)/$(DTB).raw ; \
			cd $(IPACK_PATH); \
			pwd && pwd && pwd; \
			./add_uhdr.sh dtb-`date +%Y%m%d-%H%M%S` ../$(OUT_PATH)/$(DTB).raw ../$(OUT_PATH)/$(DTB) 0x000000 0x000000; \
			cd .. ; \
		else \
			$(CP) -vf $(LINUX_PATH)/$(DTB) $(OUT_PATH)/$(DTB) ; \
		fi; \
		$(ECHO) $(COLOR_YELLOW)"Copy "$(DTB)" to out folder."$(COLOR_ORIGIN); \
	else \
		$(ECHO) $(COLOR_YELLOW)$(DTB)" doesn't exist."$(COLOR_ORIGIN); \
		exit 1; \
	fi
	@if [ "$(BOOT_FROM)" != "SDCARD" ] && [ "$(BOOT_FROM)" != "USB" ]; then  \
		if [ -f $(ROOTFS_PATH)/$(ROOTFS_IMG) ]; then \
			$(ECHO) $(COLOR_YELLOW)"Copy "$(ROOTFS_IMG)" to out folder."$(COLOR_ORIGIN); \
			$(CP) -vf $(ROOTFS_PATH)/$(ROOTFS_IMG) $(OUT_PATH)/ ;\
		else \
			$(ECHO) $(COLOR_YELLOW)$(ROOTFS_IMG)" doesn't exist."$(COLOR_ORIGIN); \
			exit 1; \
		fi \
	fi
	@cd out/; OVERLAYFS=$(OVERLAYFS) ./$(ISP_SHELL) $(BOOT_FROM) $(CHIP) $(FLASH_SIZE) $(NAND_PAGE_SIZE) $(NAND_PAGE_CNT)

	@if [ "$(BOOT_FROM)" = "SDCARD" ]; then  \
		$(ECHO) $(COLOR_YELLOW) "Generating image for SD card..." $(COLOR_ORIGIN); \
		cd build/tools/sdcard_boot; ./$(SDCARD_BOOT_SHELL) $(SDCARD_BOOT_MODE); \
	fi

part:
	@$(ECHO) $(COLOR_YELLOW) "Please enter the Partition NAME:" $(COLOR_ORIGIN)
	@cd out; ./$(PART_SHELL)

secure:
	@if [ "$(SECURE_PATH)" = "xboot" ]; then \
		$(ECHO) $(COLOR_YELLOW) "###xboot add sign data ####!!!" $(COLOR_ORIGIN) ;\
		if [ ! -f $(XBOOT_PATH)/bin/xboot.bin ]; then \
			exit 1; \
		fi; \
		if [ "$(SECURE)" = "1" ]; then \
			cd $(SECURE_TOOL_PATH); ./clr_out.sh ; \
			./build_inputfile_sb.sh $(TOPDIR)/$(XBOOT_PATH)/bin/xboot.bin $(SB_FLAG);\
			cp -f $(SECURE_TOOL_PATH)/out/outfile_sb.bin $(TOPDIR)/$(XBOOT_PATH)/bin/xboot.bin ; \
		fi ;\
		cd $(TOPDIR)/$(XBOOT_PATH); \
		bash ./add_xhdr.sh ./bin/xboot.bin ./bin/$(XBOOT_BIN) $(SECURE) ; \
		make size_check || exit 1; \
		mv ./bin/$(XBOOT_BIN) ./bin/$(XBOOT_BIN).orig ; \
		cat ./bin/$(XBOOT_BIN).orig ./bin/pmu_train_imem.img ./bin/pmu_train_dmem.img ./bin/2d_pmu_train_imem.img ./bin/2d_pmu_train_dmem.img ./bin/diags_imem.img ./bin/diags_dmem.img > ./bin/$(XBOOT_BIN) ; \
		sz=`du -sb ./bin/$(XBOOT_BIN) | cut -f1` ; \
		printf "$(XBOOT_BIN) (+ lpddr4 fw) size = %d (hex %x)\n" $$sz $$sz ; \
		if [ $$sz -gt $(XBOOT_LPDDR4_MAX) ]; then \
			echo "$(XBOOT_BIN) (+ lpddr4 fw) size limit is $(XBOOT_LPDDR4_MAX). Please reduce its size.\n" ; \
			exit 1; \
		fi; \
	elif [ "$(SECURE_PATH)" = "uboot" ]; then \
		$(ECHO) $(COLOR_YELLOW) "###uboot add sign data ####!!!" $(COLOR_ORIGIN) ;\
		if [ ! -f $(UBOOT_PATH)/u-boot.bin ]; then \
			exit 1; \
		fi; \
		[ "$(SECURE)" = "1" ] && make -C $(TOPDIR)/build/tools/secure_sp7350 sign IMG=$(TOPDIR)/$(UBOOT_PATH)/u-boot.bin SB=$(SB_FLAG); \
		cd $(TOPDIR) ; $(TOPDIR)/build/tools/add_uhdr.sh $(img_name) $(TOPDIR)/$(UBOOT_PATH)/u-boot.bin $(TOPDIR)/$(UBOOT_PATH)/$(UBOOT_BIN) $(ARCH) ;\
	elif [ "$(SECURE_PATH)" = "fip" ]; then \
		$(ECHO) $(COLOR_YELLOW) "###fip add sign data ####!!!" $(COLOR_ORIGIN) ;\
		if [ ! -f $(FIP_PATH)/build/fip.bin ]; then \
			exit 1; \
		fi; \
		[ "$(SECURE)" = "1" ] && make -C $(TOPDIR)/build/tools/secure_sp7350 sign IMG=$(TOPDIR)/$(FIP_PATH)/build/fip.bin SB=$(SB_FLAG); \
		cd $(TOPDIR) ; $(TOPDIR)/build/tools/add_uhdr.sh fip_image $(TOPDIR)/$(FIP_PATH)/build/fip.bin $(TOPDIR)/$(FIP_PATH)/build/$(FIP_BIN) $(ARCH) ;\
	elif [ "$(SECURE_PATH)" = "kernel" ]; then \
		$(ECHO) $(COLOR_YELLOW) "###kernel add sign data ####!!!" $(COLOR_ORIGIN);\
		if [ ! -f $(LINUX_PATH)/arch/$(ARCH)/boot/Image ]; then \
				exit 1; \
		fi; \
		[ "$(SECURE)" = "1" ] && make -C $(TOPDIR)/build/tools/secure_sp7350 sign IMG=$(TOPDIR)/$(LINUX_PATH)/arch/$(ARCH)/boot/Image.gz; \
		cd $(TOPDIR)/$(IPACK_PATH); ./add_uhdr.sh linux-`date +%Y%m%d-%H%M%S` $(TOPDIR)/$(LINUX_PATH)/arch/$(ARCH)/boot/Image.gz $(TOPDIR)/$(LINUX_PATH)/arch/$(ARCH)/boot/$(KERNEL_BIN) $(ARCH) 0 0 kernel; \
	fi

rom: check
	@if [ "$(NEED_ISP)" = '1' ]; then  \
		$(MAKE) isp; \
	else \
		$(MAKE) spirom; \
		if [ "$(ZEBU_RUN)" = "0" ]; then \
			$(MAKE) spirom_isp; \
		fi; \
	fi

mt: check
	@$(MAKE) kernel
	cp linux/application/module_test/mt2.sh $(ROOTFS_DIR)/bin
	@$(MAKE) rootfs rom

init:
	@if ! [ -f $(CROSS_COMPILE_FOR_LINUX) ]; then \
		pwd; \
		./build/dlgcc.sh; \
	fi
	@$(RM) -f $(CONFIG_ROOT)
	@./build/config.sh

check:
	@if ! [ -f $(CONFIG_ROOT) ]; then \
		$(ECHO) $(COLOR_YELLOW)"Please \"make config\" first."$(COLOR_ORIGIN); \
		exit 1; \
	fi

initramfs:
	@$(MAKE_ARCH) -C $(ROOTFS_PATH) CROSS=$(CROSS_COMPILE_FOR_ROOTFS) initramfs rootfs_cfg=$(ROOTFS_CONFIG) boot_from=$(BOOT_FROM) ROOTFS_CONTENT=$(ROOTFS_CONTENT)

rootfs:
	@$(MAKE_ARCH) -C $(ROOTFS_PATH) CROSS=$(CROSS_COMPILE_FOR_ROOTFS) rootfs OVERLAYFS=$(OVERLAYFS) rootfs_cfg=$(ROOTFS_CONFIG) boot_from=$(BOOT_FROM) ROOTFS_CONTENT=$(ROOTFS_CONTENT) \
	FLASH_SIZE=$(FLASH_SIZE) NAND_PAGE_SIZE=$(NAND_PAGE_SIZE) NAND_PAGE_CNT=$(NAND_PAGE_CNT)

bconfig:
	@if [ -f "$(BUILDROOT_DIR)/.config.old" ]; then \
		rm $(BUILDROOT_DIR)/.config.old; \
	fi
	@$(MAKE_ARCH) -C $(BUILDROOT_DIR) menuconfig
	@if ! diff $(BUILDROOT_DIR)/.config $(BUILDROOT_DIR)/.config.old; then \
		if [ -f "$(ROOTFS_DIR)/lib/os-release" ]; then \
			rm $(ROOTFS_DIR)/lib/os-release; \
		fi; \
    fi

reload_bconfig:
	lowercase_string=$(shell echo $(CHIP) | tr '[:upper:]' '[:lower:]'); \
	$(MAKE_ARCH) -C $(BUILDROOT_DIR) $${lowercase_string}_defconfig

buildroot:
	@if [ "$(ROOTFS_CONTENT)" = "BUILDROOT" ]; then \
		set -e; \
		if [ ! -f "$(ROOTFS_DIR)/lib/os-release" ]; then \
			if [ ! -f "$(BUILDROOT_DIR)/.config" ]; then \
				lowercase_string=$(shell echo $(CHIP) | tr '[:upper:]' '[:lower:]'); \
				$(MAKE_ARCH) -C $(BUILDROOT_DIR) $${lowercase_string}_defconfig; \
			fi; \
			$(MAKE_ARCH) -C $(BUILDROOT_DIR); \
			$(eval BUILD_IMAGE := $(BUILDROOT_DIR)/output/images) \
			if [ -f "$(BUILD_IMAGE)/rootfs.tar" ]; then \
				rm -rf $(ROOTFS_DIR); \
				mkdir $(ROOTFS_DIR); \
				tar xvf ${BUILD_IMAGE}/rootfs.tar -C $(ROOTFS_DIR) > /dev/null; \
				mkdir -p ${ROOTFS_DIR}/lib/firmware; \
			fi; \
		else \
			$(ECHO) $(COLOR_YELLOW)"Buildroot has been compiled."$(COLOR_ORIGIN); \
		fi; \
	fi

kconfig:
	$(MAKE_ARCH) -C $(LINUX_PATH) CROSS_COMPILE=$(CROSS_COMPILE_FOR_LINUX) menuconfig

uconfig:
	$(MAKE_ARCH) -C $(UBOOT_PATH) CROSS_COMPILE=$(CROSS_COMPILE_FOR_LINUX) menuconfig

xconfig:
	$(MAKE) ARCH=$(ARCH_XBOOT) -C $(XBOOT_PATH) CROSS=$(CROSS_COMPILE_FOR_XBOOT) menuconfig

headers:
	@KERNELRELEASE=$(shell cat $(LINUX_PATH)/include/config/kernel.release 2>/dev/null)
	@if ! [ -f $(LINUX_PATH)/.config ]; then \
		echo File \'$(LINUX_PATH)/.config\' does not exist!; \
		exit 1; \
	fi
	@if ! [ -f $(LINUX_PATH)/Module.symvers ]; then \
		echo File \'$(LINUX_PATH)/Module.symvers\' does not exist!; \
		exit 1; \
	fi
	rm -rf linux-headers-$(KERNELRELEASE)
	mkdir -p linux-headers-$(KERNELRELEASE)
	cp -f $(LINUX_PATH)/.config linux-headers-$(KERNELRELEASE)
	cp -f $(LINUX_PATH)/Module.symvers linux-headers-$(KERNELRELEASE)
	$(MAKE_ARCH) $(MAKE_JOBS) -C $(LINUX_PATH) CROSS_COMPILE=$(CROSS_COMPILE_FOR_LINUX) mrproper
	$(MAKE_ARCH) $(MAKE_JOBS) -C $(LINUX_PATH) O=../../linux-headers-$(KERNELRELEASE) CROSS_COMPILE=$(CROSS_COMPILE_FOR_LINUX) modules_prepare

info:
	@$(ECHO) "XBOOT =" $(XBOOT_CONFIG)
	@$(ECHO) "UBOOT =" $(UBOOT_CONFIG)
	@$(ECHO) "KERNEL =" $(KERNEL_CONFIG)
	@$(ECHO) "LINUX_DTB =" $(LINUX_DTB)
	@$(ECHO) "CROSS COMPILER XBOOT =" $(CROSS_COMPILE_FOR_XBOOT)
	@$(ECHO) "CROSS COMPILER LINUX =" $(CROSS_COMPILE_FOR_LINUX)
	@$(ECHO) "CROSS COMPILER ROOTFS =" $(CROSS_COMPILE_FOR_ROOTFS)
	@$(ECHO) "NEED ISP =" $(NEED_ISP)
	@$(ECHO) "ZEBU RUN =" $(ZEBU_RUN)
	@$(ECHO) "BOOT FROM =" $(BOOT_FROM)
	@if [ -n "$(FLASH_SIZE)" ]; then \
		$(ECHO) "FLASH_SIZE =" $(FLASH_SIZE)"MiB"; \
	fi
	@if [ -n "$(NAND_PAGE_SIZE)" ]; then \
		$(ECHO) "NAND_PAGE_SIZE =" $(NAND_PAGE_SIZE)"KiB"; \
		$(ECHO) "NAND_PAGE_CNT =" $(NAND_PAGE_CNT); \
	fi
	@$(ECHO) "BOOT CHIP =" $(BOOT_CHIP)
	@$(ECHO) "ARCH =" $(ARCH)
	@$(ECHO) "CHIP =" $(CHIP)
	@$(ECHO) "ZMEM =" $(ZMEM)
	@$(ECHO) "SECURE =" $(SECURE)
	@$(ECHO) "ENCRYPTION =" $(ENCRYPTION)
	@$(ECHO) "ROOTFS_CONTENT =" $(ROOTFS_CONTENT)

include ./build/qemu.mak
