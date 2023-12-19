#!/bin/bash
COLOR_RED="\033[0;1;31;40m"
COLOR_GREEN="\033[0;1;32;40m"
COLOR_YELLOW="\033[0;1;33;40m"
COLOR_ORIGIN="\033[0m"
ECHO="echo -e"
BUILD_CONFIG=./.config

XBOOT_CONFIG_ROOT=./boot/xboot/configs
UBOOT_CONFIG_ROOT=./boot/uboot/configs
KERNEL_ARM_CONFIG_ROOT=./linux/kernel/arch/arm/configs

UBOOT_CONFIG=
KERNEL_CONFIG=
BOOT_FROM=
XBOOT_CONFIG=

ARCH=arm

# bootdev=emmc
# bootdev=spi_nand
# bootdev=spi_nor
# bootdev=nor
# bootdev=tftp
# bootdev=usb
# bootdev=para_nand

bootdev_lookup()
{
	dev=$1
	if [ "$1" = "spi_nor" ]; then
		dev=nor
	elif [ "$1" = "nor" ]; then
		dev=romter
	elif [ "$1" = "spi_nand" ]; then
		dev=nand
	elif [ "$1" = "tftp" ]; then
		dev=romter
	elif [ "$1" = "para_nand" ]; then
		dev=pnand
	fi
	echo $dev
}

chip_lookup()
{
	chip=$1
	if [ "$1" = "1" ]; then
		chip=c
	elif [ "$1" = "2" ]; then
		chip=p
	fi
	echo $chip
}

xboot_defconfig_combine()
{
	# $1 => project
	# $2 => bootdev
	# $3 => c/p
	# $4 => board
	# $5 => zmem

	pid=$1
	chip=$3
	dev=$(bootdev_lookup $2)
	board=$4
	xzmem=$5
	defconfig=

	if [ "$board" = "zebu" ]; then
		if [ "$xzmem" = "1" ]; then
			defconfig=${pid}_${chip}_zmem_defconfig
		else
			defconfig=${pid}_${chip}_zebu_defconfig
		fi
	else
		defconfig=${pid}_${dev}_${chip}_defconfig
	fi
	echo $defconfig
}

uboot_defconfig_combine()
{
	# $1 => project
	# $2 => bootdev
	# $3 => c/p
	# $4 => board
	# $5 => zmem

	pid=$1
	dev=$(bootdev_lookup $2)
	chip=$3
	board=$4
	uzmem=$5
	defconfig=

	if [ "$board" = "zebu" ]; then
		if [ "$uzmem" = "1" ]; then
			defconfig=${pid}_${chip}_zmem_defconfig
		else
			defconfig=${pid}_${chip}_zebu_defconfig
		fi
	else
		defconfig=${pid}_${dev}_${chip}_defconfig
	fi

	echo $defconfig
}

linux_defconfig_combine()
{
	# $1 => project
	# $2 => bootdev
	# $3 => c/p
	# $4 => board

	pid=$1
	dev=$(bootdev_lookup $2)
	chip=$3
	board=$4
	defconfig=

	if [ "$4" = "zebu" ]; then
		defconfig=${pid}_${chip}_${board}_defconfig
	else
		defconfig=${pid}_${dev}_${chip}_${board}_defconfig
	fi

	echo $defconfig
}

set_uboot_config()
{
	echo "UBOOT_CONFIG=${UBOOT_CONFIG}" >> $BUILD_CONFIG
}

set_kernel_config()
{
	echo "KERNEL_CONFIG=${KERNEL_CONFIG}" >> $BUILD_CONFIG
}

set_bootfrom_config()
{
	if [ "$BOOT_FROM" = "" ]; then
		BOOT_FROM=$1
	fi
	echo "BOOT_FROM="$BOOT_FROM >> $BUILD_CONFIG
}

set_xboot_config()
{
	echo "XBOOT_CONFIG="$XBOOT_CONFIG >> $BUILD_CONFIG
}

c_chip_spi_nand_config()
{
	set_xboot_config
	set_uboot_config
	set_kernel_config
	set_bootfrom_config NAND

	NEED_ISP=1
	echo "NEED_ISP="$NEED_ISP >> $BUILD_CONFIG
}

c_chip_para_nand_config()
{
	set_xboot_config
	set_uboot_config
	set_kernel_config
	set_bootfrom_config PNAND

	NEED_ISP=1
	echo "NEED_ISP="$NEED_ISP >> $BUILD_CONFIG
}

c_chip_spi_nor_config()
{
	set_xboot_config
	set_uboot_config
	set_kernel_config
	set_bootfrom_config NOR_JFFS2
}

c_chip_emmc_config()
{
	set_xboot_config
	set_uboot_config
	set_kernel_config
	set_bootfrom_config EMMC

	NEED_ISP=1
	echo "NEED_ISP="$NEED_ISP >> $BUILD_CONFIG
}

c_chip_nor_config()
{
	set_xboot_config
	set_uboot_config
	set_kernel_config
	set_bootfrom_config SPINOR
}

c_chip_tftp_config()
{
	set_xboot_config
	set_uboot_config
	set_kernel_config

	BOOT_KERNEL_FROM_TFTP=1
	echo "Please enter TFTP server IP address: (Default is 172.18.12.62)"
	read TFTP_SERVER_IP
	if [ "${TFTP_SERVER_IP}" == "" ]; then
		TFTP_SERVER_IP=172.18.12.62
	fi
	echo "TFTP server IP address is ${TFTP_SERVER_IP}"
	echo "Please enter TFTP server path: (Default is /home/scftp)"
	read TFTP_SERVER_PATH
	if [ "${TFTP_SERVER_PATH}" == "" ]; then
		TFTP_SERVER_PATH=/home/scftp
	fi
	echo "TFTP server path is ${TFTP_SERVER_PATH}"
	echo "Please enter MAC address of target board (ex: 00:22:60:00:88:20):"
	echo "(Press Enter directly if you want to use board's default MAC address.)"
	read BOARD_MAC_ADDR
	if [ "${BOARD_MAC_ADDR}" != "" ]; then
		echo "MAC address of target board is ${BOARD_MAC_ADDR}"
	fi
	set_uboot_config
	set_kernel_config
	set_bootfrom_config TFTP

	USER_NAME=$(whoami)
	echo "Your USER_NAME is ${USER_NAME}"
	echo "BOOT_KERNEL_FROM_TFTP="${BOOT_KERNEL_FROM_TFTP} >> ${BUILD_CONFIG}
	echo "USER_NAME=_"${USER_NAME} >> ${BUILD_CONFIG}
	echo "BOARD_MAC_ADDR="${BOARD_MAC_ADDR} >> ${BUILD_CONFIG}
	echo "TFTP_SERVER_IP="${TFTP_SERVER_IP} >> ${BUILD_CONFIG}
	echo "TFTP_SERVER_PATH="${TFTP_SERVER_PATH} >> ${BUILD_CONFIG}
}

c_chip_usb_config()
{
	set_xboot_config
	set_uboot_config
	set_kernel_config
	set_bootfrom_config USB

	NEED_ISP=1
	echo "NEED_ISP="$NEED_ISP >> $BUILD_CONFIG
}

c_chip_config()
{
	case "$1" in
	"emmc")
		c_chip_emmc_config
		;;
	"sdcard")
		c_chip_emmc_config
		;;
	"spi_nand")
		c_chip_spi_nand_config
		;;
	"spi_nor")
		c_chip_spi_nor_config
		;;
	"nor")
		c_chip_nor_config
		;;
	"tftp")
		c_chip_tftp_config
		;;
	"usb")
		c_chip_usb_config
		;;
	"para_nand")
		c_chip_para_nand_config
		;;
	*)
		echo "Error: Unknown config!"
		exit 1
	esac
}

num=0
bootdev=
chip=1
runzebu=0
zmem=0
rootfs_content=BUSYBOX

list_config()
{
	sel=1
	if [ "$board" = "1" ]; then
		$ECHO $COLOR_YELLOW"[1] eMMC"$COLOR_ORIGIN
		$ECHO $COLOR_YELLOW"[2] SPI-NAND"$COLOR_ORIGIN
		$ECHO $COLOR_YELLOW"[3] SPI-NOR (jffs2)"$COLOR_ORIGIN
		$ECHO $COLOR_YELLOW"[4] NOR/Romter (initramfs)"$COLOR_ORIGIN
		$ECHO $COLOR_YELLOW"[5] SD Card"$COLOR_ORIGIN
		$ECHO $COLOR_YELLOW"[6] TFTP server"$COLOR_ORIGIN
		$ECHO $COLOR_YELLOW"[8] 8-bit NAND"$COLOR_ORIGIN
		read sel
	elif [ "$board" = "2" ]; then
		$ECHO $COLOR_YELLOW"[1] eMMC"$COLOR_ORIGIN
		$ECHO $COLOR_YELLOW"[2] SD Card"$COLOR_ORIGIN
		read sel
		if [ "$sel" == "2" ]; then
			sel=5
		fi
	fi

	if [ "$board" = "1" -o "$board" = "2" ]; then
		case "$sel" in
		"1")
			bootdev=emmc
			;;
		"2")
			bootdev=spi_nand
			;;
		"3")
			bootdev=spi_nor
			;;
		"4")
			bootdev=nor
			;;
		"5")
			bootdev=sdcard
			BOOT_FROM=SDCARD
			;;
		"6")
			bootdev=tftp
			;;
		"7")
			bootdev=usb
			;;
		"8")
			bootdev=para_nand
			;;
		*)
			echo "Error: Unknown config!"
			exit 1
		esac

		if [ "$bootdev" = "nor" -o "$bootdev" = "spi_nor" ]; then
			$ECHO $COLOR_GREEN"Select SPI-NOR size:"$COLOR_ORIGIN
			$ECHO $COLOR_YELLOW"[1] 16 MiB"$COLOR_ORIGIN
			$ECHO $COLOR_YELLOW"[2] 32 MiB"$COLOR_ORIGIN
			$ECHO $COLOR_YELLOW"[3] 64 MiB"$COLOR_ORIGIN
			read sel
			case "$sel" in
			"1")
				echo "FLASH_SIZE=16" >> $BUILD_CONFIG
				;;
			"2")
				echo "FLASH_SIZE=32" >> $BUILD_CONFIG
				;;
			"3")
				echo "FLASH_SIZE=64" >> $BUILD_CONFIG
				;;
			*)
				echo "Error: Unknown config!"
				exit 1
			esac
		fi

		if [ "$bootdev" = "emmc" ]; then
			$ECHO $COLOR_GREEN"Select eMMC size:"$COLOR_ORIGIN
			$ECHO $COLOR_YELLOW"[1] 1 GiB"$COLOR_ORIGIN
			$ECHO $COLOR_YELLOW"[2] 2 GiB"$COLOR_ORIGIN
			$ECHO $COLOR_YELLOW"[3] 4 GiB"$COLOR_ORIGIN
			$ECHO $COLOR_YELLOW"[4] 8 GiB"$COLOR_ORIGIN
			$ECHO $COLOR_YELLOW"[5] 16 GiB"$COLOR_ORIGIN
			$ECHO $COLOR_YELLOW"[6] 32 GiB"$COLOR_ORIGIN
			read sel
			case "$sel" in
			"1")
				echo "FLASH_SIZE=1024" >> $BUILD_CONFIG
				;;
			"2")
				echo "FLASH_SIZE=2048" >> $BUILD_CONFIG
				;;
			"3")
				echo "FLASH_SIZE=4096" >> $BUILD_CONFIG
				;;
			"4")
				echo "FLASH_SIZE=8192" >> $BUILD_CONFIG
				;;
			"5")
				echo "FLASH_SIZE=16384" >> $BUILD_CONFIG
				;;
			"6")
				echo "FLASH_SIZE=32768" >> $BUILD_CONFIG
				;;
			*)
				echo "Error: Unknown config!"
				exit 1
			esac
		fi

		echo "PNAND_FLASH=0" >> $BUILD_CONFIG
		if [ "$bootdev" = "spi_nand" ]; then
			$ECHO $COLOR_GREEN"Select NAND size:"$COLOR_ORIGIN
			$ECHO $COLOR_YELLOW"[1] 128 MiB"$COLOR_ORIGIN
			$ECHO $COLOR_YELLOW"[2] 256 MiB"$COLOR_ORIGIN
			$ECHO $COLOR_YELLOW"[3] 512 MiB"$COLOR_ORIGIN
			$ECHO $COLOR_YELLOW"[4] 1 GiB"$COLOR_ORIGIN
			$ECHO $COLOR_YELLOW"[5] 2 GiB"$COLOR_ORIGIN
			read sel
			case "$sel" in
			"1")
				echo "FLASH_SIZE=128" >> $BUILD_CONFIG
				;;
			"2")
				echo "FLASH_SIZE=256" >> $BUILD_CONFIG
				;;
			"3")
				echo "FLASH_SIZE=512" >> $BUILD_CONFIG
				;;
			"4")
				echo "FLASH_SIZE=1024" >> $BUILD_CONFIG
				;;
			"5")
				echo "FLASH_SIZE=2048" >> $BUILD_CONFIG
				;;
			*)
				echo "Error: Unknown config!"
				exit 1
			esac

			$ECHO $COLOR_GREEN"Select NAND page size:"$COLOR_ORIGIN
			$ECHO $COLOR_YELLOW"[1] 2 KiB"$COLOR_ORIGIN
			$ECHO $COLOR_YELLOW"[2] 4 KiB"$COLOR_ORIGIN
			read sel
			case "$sel" in
			"1")
				NAND_PAGE_SIZE=2
				echo "NAND_PAGE_SIZE=2" >> $BUILD_CONFIG
				;;
			"2")
				NAND_PAGE_SIZE=4
				echo "NAND_PAGE_SIZE=4" >> $BUILD_CONFIG
				;;
			*)
				echo "Error: Unknown config!"
				exit 1
			esac

			$ECHO $COLOR_GREEN"Select NAND page count per block:"$COLOR_ORIGIN
			BLOCK_SIZE=$(($NAND_PAGE_SIZE*64))
			$ECHO $COLOR_YELLOW"[1] 64 (block size = $BLOCK_SIZE KiB)"$COLOR_ORIGIN
			BLOCK_SIZE=$(($NAND_PAGE_SIZE*128))
			$ECHO $COLOR_YELLOW"[2] 128 (block size = $BLOCK_SIZE KiB)"$COLOR_ORIGIN
			read sel
			case "$sel" in
			"1")
				echo "NAND_PAGE_CNT=64" >> $BUILD_CONFIG
				;;
			"2")
				echo "NAND_PAGE_CNT=128" >> $BUILD_CONFIG
				;;
			*)
				echo "Error: Unknown config!"
				exit 1
			esac
		elif [ "$bootdev" = "para_nand" ]; then
			$ECHO $COLOR_GREEN"Select NAND size:"$COLOR_ORIGIN
			$ECHO $COLOR_YELLOW"[1] 128 MiB"$COLOR_ORIGIN
			$ECHO $COLOR_YELLOW"[2] 256 MiB"$COLOR_ORIGIN
			$ECHO $COLOR_YELLOW"[3] 512 MiB"$COLOR_ORIGIN
			$ECHO $COLOR_YELLOW"[4] 1 GiB"$COLOR_ORIGIN
			$ECHO $COLOR_YELLOW"[5] 2 GiB"$COLOR_ORIGIN
			$ECHO $COLOR_YELLOW"[6] 4 GiB"$COLOR_ORIGIN
			read sel
			case "$sel" in
			"1")
				echo "FLASH_SIZE=128" >> $BUILD_CONFIG
				;;
			"2")
				echo "FLASH_SIZE=256" >> $BUILD_CONFIG
				;;
			"3")
				echo "FLASH_SIZE=512" >> $BUILD_CONFIG
				;;
			"4")
				echo "FLASH_SIZE=1024" >> $BUILD_CONFIG
				;;
			"5")
				echo "FLASH_SIZE=2048" >> $BUILD_CONFIG
				;;
			"6")
				echo "FLASH_SIZE=4096" >> $BUILD_CONFIG
				;;
			*)
				echo "Error: Unknown config!"
				exit 1
			esac

			$ECHO $COLOR_GREEN"Select NAND page size:"$COLOR_ORIGIN
			$ECHO $COLOR_YELLOW"[1] 2 KiB"$COLOR_ORIGIN
			$ECHO $COLOR_YELLOW"[2] 4 KiB"$COLOR_ORIGIN
			$ECHO $COLOR_YELLOW"[3] 8 KiB"$COLOR_ORIGIN
			read sel
			case "$sel" in
			"1")
				NAND_PAGE_SIZE=2
				echo "NAND_PAGE_SIZE=2" >> $BUILD_CONFIG
				;;
			"2")
				NAND_PAGE_SIZE=4
				echo "NAND_PAGE_SIZE=4" >> $BUILD_CONFIG
				;;
			"3")
				NAND_PAGE_SIZE=8
				echo "NAND_PAGE_SIZE=8" >> $BUILD_CONFIG
				;;
			*)
				echo "Error: Unknown config!"
				exit 1
			esac

			$ECHO $COLOR_GREEN"Select NAND page count per block:"$COLOR_ORIGIN
			BLOCK_SIZE=$(($NAND_PAGE_SIZE*64))
			$ECHO $COLOR_YELLOW"[1] 64 (block size = $BLOCK_SIZE KiB)"$COLOR_ORIGIN
			BLOCK_SIZE=$(($NAND_PAGE_SIZE*128))
			$ECHO $COLOR_YELLOW"[2] 128 (block size = $BLOCK_SIZE KiB)"$COLOR_ORIGIN
			read sel
			case "$sel" in
			"1")
				echo "NAND_PAGE_CNT=64" >> $BUILD_CONFIG
				;;
			"2")
				echo "NAND_PAGE_CNT=128" >> $BUILD_CONFIG
				;;
			*)
				echo "Error: Unknown config!"
				exit 1
			esac
		fi

		if [ "$bootdev" = "emmc" -o "$bootdev" = "usb" -o "$bootdev" = "sdcard"  ]; then
			$ECHO $COLOR_GREEN"Select rootfs:"$COLOR_ORIGIN
			$ECHO $COLOR_YELLOW"[1] BusyBox 1.31.1"$COLOR_ORIGIN
			$ECHO $COLOR_YELLOW"[2] Ubuntu Server 20.04"$COLOR_ORIGIN
			$ECHO $COLOR_YELLOW"[3] Yocto"$COLOR_ORIGIN
			read sel
			case "$sel" in
			"2")
				rootfs_content=ubuntu-server-20.04
				;;
			"3")
				rootfs_content=YOCTO
				;;
			*)
				sel=1
			esac
		fi
	elif [ "$board" = "9" ]; then
		zmem=1
		runzebu=1
		bootdev=nor
		echo "ZMEM=1" >> $BUILD_CONFIG
	else
		echo "Error: Unknown config!"
		exit 1
	fi
}

$ECHO $COLOR_GREEN"Select boards:"$COLOR_ORIGIN
$ECHO $COLOR_YELLOW"[1] SP7350 Ev Board"$COLOR_ORIGIN
$ECHO $COLOR_YELLOW"[2] eCV5546 XINK Board"$COLOR_ORIGIN
#$ECHO $COLOR_YELLOW"[9] SP7350 Zebu (ZMem)"$COLOR_ORIGIN
read board

if [ "$board" = "1" -o "$board" = "9" ]; then
	ARCH=arm64
	echo "CHIP=SP7350" > $BUILD_CONFIG
	echo "LINUX_DTB=sunplus/sp7350-ev" >> $BUILD_CONFIG
elif [ "$board" = "2" ]; then
	ARCH=arm64
	echo "CHIP=SP7350" > $BUILD_CONFIG
	echo "LINUX_DTB=sunplus/ecv5546-xink" >> $BUILD_CONFIG
else
	echo "Error: Unknown board!"
	exit 1
fi

$ECHO $COLOR_GREEN"Select boot devices:"$COLOR_ORIGIN
num=2
echo "CROSS_COMPILE="$1 >> $BUILD_CONFIG
echo "ROOTFS_CONFIG=v7" >> $BUILD_CONFIG
echo "BOOT_CHIP=C_CHIP" >> $BUILD_CONFIG

list_config

################################################################################
##
## use product name, bootdev, chip, board to combine into a deconfig file name
## so, the defconfig file name must follow named rule like
##
## non-zebu:
##     xboot, uboot:
##         ${pid}_${bootdev}_${chip}_defconfig              --> sp7350_emmc_c_defconfig
##	   linux:
##         ${pid}_${bootdev}_${chip}_${sel_board}_defconfig --> sp7350_emmc_c_ev_defconfig
##
## zebu:
##     xboot:
##         ${pid}_${chip}_zmem_defconfig --> sp7350_c_zmem_defconfig
##     uboot:
##         ${pid}_${chip}_zebu_defconfig --> sp7350_c_zebu_defconfig
##     linux:
##         ${pid}_${chip}_zebu_defconfig --> sp7350_c_zebu_defconfig

set_config_directly=0

if [ "$board" = "1" -o "$board" = "2" -o "$board" = "9" ]; then
	## board = SP7350
	$ECHO $COLOR_GREEN"Select secure modes:"$COLOR_ORIGIN
	$ECHO $COLOR_YELLOW"[1] No secure (default)"$COLOR_ORIGIN
	$ECHO $COLOR_YELLOW"[2] Enable digital signature"$COLOR_ORIGIN
	$ECHO $COLOR_YELLOW"[3] Enable digital signature & Encryption"$COLOR_ORIGIN
	read secure

	if [ "$secure" = "2" ]; then
		echo "SECURE=1" >> $BUILD_CONFIG
	elif [ "$secure" = "3" ]; then
		echo "SECURE=1" >> $BUILD_CONFIG
		echo "ENCRYPTION=1" >> $BUILD_CONFIG
	fi

	sel_chip=$(chip_lookup $chip)
	sel_board=ev
	if [ "$board" = "9" ]; then
		sel_board=zebu
	fi
	set_config_directly=1
	chip_name="sp7350"

	if [ "$board" = "2" ]; then
		sel_board=xink
		chip_name="ecv5546"
	fi
fi
set -x
if [ "$set_config_directly" = "1" ]; then
	xboot_bootdev=$bootdev
	if [ "$bootdev" = "sdcard" -o "$bootdev" = "usb" ]; then
		xboot_bootdev="emmc"
	fi
	XBOOT_CONFIG=$(xboot_defconfig_combine $chip_name $xboot_bootdev $sel_chip $sel_board $zmem)
	UBOOT_CONFIG=$(uboot_defconfig_combine $chip_name $bootdev $sel_chip $sel_board $zmem)
	KERNEL_CONFIG=$(linux_defconfig_combine $chip_name $bootdev $sel_chip $sel_board)
fi

echo "ROOTFS_CONTENT=${rootfs_content}" >> $BUILD_CONFIG

################################################################################

if [ "$runzebu" = "1" ]; then
	echo "ZEBU_RUN=1" >> $BUILD_CONFIG
fi

echo "ARCH=$ARCH" >> $BUILD_CONFIG

echo "bootdev "$bootdev

c_chip_config $bootdev
