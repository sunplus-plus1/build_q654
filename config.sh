#!/bin/bash
COLOR_RED="\033[0;1;31m"
COLOR_GREEN="\033[0;1;32m"
COLOR_YELLOW="\033[0;1;33m"
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

	defconfig=${pid}_${dev}_${board}_defconfig
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
	defconfig=${pid}_${dev}_${board}_defconfig
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

	defconfig=${pid}_${dev}_${board}_defconfig

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
	if [ "$board" = "1" ] || [ "$board" = "13" ]; then
		$ECHO $COLOR_ORIGIN"[1] eMMC"$COLOR_ORIGIN
		$ECHO $COLOR_ORIGIN"[2] SPI-NAND"$COLOR_ORIGIN
		$ECHO $COLOR_ORIGIN"[3] SPI-NOR (jffs2)"$COLOR_ORIGIN
		$ECHO $COLOR_ORIGIN"[4] NOR/Romter (initramfs)"$COLOR_ORIGIN
		$ECHO $COLOR_ORIGIN"[5] SD Card"$COLOR_ORIGIN
		$ECHO $COLOR_ORIGIN"[6] TFTP server"$COLOR_ORIGIN
		$ECHO $COLOR_ORIGIN"[8] 8-bit NAND"$COLOR_ORIGIN
		read sel
	elif [ "$board" = "10" ]; then
		$ECHO $COLOR_ORIGIN"[1] eMMC"$COLOR_ORIGIN
		$ECHO "1"
		sel=1
	elif [ "$board" = "12" ]; then
		$ECHO $COLOR_ORIGIN"[1] eMMC"$COLOR_ORIGIN
		$ECHO "1"
		sel=1
	else
		$ECHO $COLOR_ORIGIN"[1] eMMC"$COLOR_ORIGIN
		$ECHO $COLOR_ORIGIN"[2] SD Card"$COLOR_ORIGIN
		read sel
		if [ "$sel" == "2" ]; then
			sel=5
		fi
	fi

	if [ "$board" = "1" ] || [ "$board" = "2" ] || [ "$board" = "3" ] || [ "$board" = "4" ] || [ "$board" = "5" ] || \
	   [ "$board" = "6" ] || [ "$board" = "7" ] || [ "$board" = "8" ] || [ "$board" = "9" ] || [ "$board" = "10" ] || \
	   [ "$board" = "11" ] || [ "$board" = "12" ] || [ "$board" = "13" ]; then
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
			$ECHO $COLOR_ORIGIN"[1] 16 MiB"$COLOR_ORIGIN
			$ECHO $COLOR_ORIGIN"[2] 32 MiB"$COLOR_ORIGIN
			$ECHO $COLOR_ORIGIN"[3] 64 MiB"$COLOR_ORIGIN
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
			$ECHO $COLOR_ORIGIN"[1] 1 GiB"$COLOR_ORIGIN
			$ECHO $COLOR_ORIGIN"[2] 2 GiB"$COLOR_ORIGIN
			$ECHO $COLOR_ORIGIN"[3] 4 GiB"$COLOR_ORIGIN
			$ECHO $COLOR_ORIGIN"[4] 8 GiB"$COLOR_ORIGIN
			$ECHO $COLOR_ORIGIN"[5] 16 GiB"$COLOR_ORIGIN
			$ECHO $COLOR_ORIGIN"[6] 32 GiB"$COLOR_ORIGIN
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
			$ECHO $COLOR_ORIGIN"[1] 128 MiB"$COLOR_ORIGIN
			$ECHO $COLOR_ORIGIN"[2] 256 MiB"$COLOR_ORIGIN
			$ECHO $COLOR_ORIGIN"[3] 512 MiB"$COLOR_ORIGIN
			$ECHO $COLOR_ORIGIN"[4] 1 GiB"$COLOR_ORIGIN
			$ECHO $COLOR_ORIGIN"[5] 2 GiB"$COLOR_ORIGIN
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
			$ECHO $COLOR_ORIGIN"[1] 2 KiB"$COLOR_ORIGIN
			$ECHO $COLOR_ORIGIN"[2] 4 KiB"$COLOR_ORIGIN
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
			$ECHO $COLOR_ORIGIN"[1] 64 (block size = $BLOCK_SIZE KiB)"$COLOR_ORIGIN
			BLOCK_SIZE=$(($NAND_PAGE_SIZE*128))
			$ECHO $COLOR_ORIGIN"[2] 128 (block size = $BLOCK_SIZE KiB)"$COLOR_ORIGIN
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

			$ECHO $COLOR_GREEN"Use OVERLAYFS:"$COLOR_ORIGIN
			$ECHO $COLOR_ORIGIN"[1] YES"$COLOR_ORIGIN
			$ECHO $COLOR_ORIGIN"[2] NO"$COLOR_ORIGIN
			read overlay
			case "$overlay" in
			"1")
				echo "OVERLAYFS=1" >> $BUILD_CONFIG
				;;
			*)
				;;
			esac
		elif [ "$bootdev" = "para_nand" ]; then
			$ECHO $COLOR_GREEN"Select NAND size:"$COLOR_ORIGIN
			$ECHO $COLOR_ORIGIN"[1] 128 MiB"$COLOR_ORIGIN
			$ECHO $COLOR_ORIGIN"[2] 256 MiB"$COLOR_ORIGIN
			$ECHO $COLOR_ORIGIN"[3] 512 MiB"$COLOR_ORIGIN
			$ECHO $COLOR_ORIGIN"[4] 1 GiB"$COLOR_ORIGIN
			$ECHO $COLOR_ORIGIN"[5] 2 GiB"$COLOR_ORIGIN
			$ECHO $COLOR_ORIGIN"[6] 4 GiB"$COLOR_ORIGIN
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
			$ECHO $COLOR_ORIGIN"[1] 2 KiB"$COLOR_ORIGIN
			$ECHO $COLOR_ORIGIN"[2] 4 KiB"$COLOR_ORIGIN
			$ECHO $COLOR_ORIGIN"[3] 8 KiB"$COLOR_ORIGIN
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
			$ECHO $COLOR_ORIGIN"[1] 64 (block size = $BLOCK_SIZE KiB)"$COLOR_ORIGIN
			BLOCK_SIZE=$(($NAND_PAGE_SIZE*128))
			$ECHO $COLOR_ORIGIN"[2] 128 (block size = $BLOCK_SIZE KiB)"$COLOR_ORIGIN
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
			use_ftp=0
			url_protocal=http
			zone=$(basename `cat /etc/timezone`)

			if [ "$UBUNTU_PREBUILD_URL" = "" ]; then
				if [ "$zone" = "Shanghai" ]; then
					echo "***"
					use_ftp=1
					UBUNTU_PREBUILD_URL="ftp.sunmedia.com.cn"
					ubuntu_prebuild=`wget --no-verbose --connect-timeout=3 --tries=1 -qO- ftp://${UBUNTU_PREBUILD_URL}/ubuntu_prebuild/ubuntu_prebuild.txt | cat`
				else
					echo "---"
				fi

				if [ "$ubuntu_prebuild" = "" ]; then
					use_ftp=0
					UBUNTU_PREBUILD_URL="172.18.12.63"
					ubuntu_prebuild=`wget --connect-timeout=3 --tries=1 -qO- http://${UBUNTU_PREBUILD_URL}/packages/armhf/ubuntu_prebuild.txt | cat`
				fi

				if [ "$ubuntu_prebuild" = "" ]; then
					UBUNTU_PREBUILD_URL="plus1.sunplus.com"
					url_protocal=https
					ubuntu_prebuild=`wget --connect-timeout=3 --tries=1 -qO- https://${UBUNTU_PREBUILD_URL}/packages/armhf/ubuntu_prebuild.txt | cat`
				fi
			else
				ubuntu_prebuild=`wget --connect-timeout=3 --tries=1 -qO- http://${UBUNTU_PREBUILD_URL}/packages/armhf/ubuntu_prebuild.txt | cat`
			fi

			if [ "$ubuntu_prebuild" = "" ]; then
				$ECHO $COLOR_RED"UBUNTU_PREBUILD_URL=$UBUNTU_PREBUILD_URL"$COLOR_ORIGIN
				$ECHO $COLOR_RED"get ubuntu_prebuild info failed!"$COLOR_ORIGIN
				exit 1
			fi

			menu='linux/rootfs/tools/menu.sh'
			if [ ! -f "$menu" ]; then
				echo "Error: $menu not found!"
				exit 1
			fi

			. $menu
			menu_rootfs_title_num
			if [ "$MENU_ROOTFS_NUM" == "0" ]; then
				echo "Error: Rootfs not found!"
				exit 1
			fi

			idx=1
			$ECHO ${COLOR_GREEN}"Select rootfs:"$COLOR_ORIGIN
			for n in $(seq -s ' ' $MENU_ROOTFS_NUM)
			do
				$ECHO $COLOR_ORIGIN"[$idx] $(menu_rootfs_title $n)"$COLOR_ORIGIN
				idx=$((idx + 1))
			done

			read sel
			rootfs_content=$(menu_rootfs_content $sel)
			if [ -z "$rootfs_content" ]; then
				echo "Error: Unknown config!"
				exit 1
			fi

			if [ "${rootfs_content%%:*}" = "UBUNTU" ]; then
				UBUNTU_PREBUILD_URL=$UBUNTU_PREBUILD_URL ROOTFS=$rootfs_content URL_PROTOCAL=$url_protocal USE_FTP=$use_ftp build/dlubuntu.sh
				if [ "$?" != "0" ]; then
					exit 1
				fi
			fi

			UBUNTU_PREBUILD_URL=$UBUNTU_PREBUILD_URL ROOTFS=$rootfs_content URL_PROTOCAL=$url_protocal USE_FTP=$use_ftp build/dlprebuilt.sh
			if [ "$?" != "0" ]; then
				exit 1
			fi

			if [ "$bootdev" = "emmc" ]; then
				$ECHO $COLOR_GREEN"Use OVERLAYFS:"$COLOR_ORIGIN
				$ECHO $COLOR_ORIGIN"[1] YES"$COLOR_ORIGIN
				$ECHO $COLOR_ORIGIN"[2] NO"$COLOR_ORIGIN
				read overlay
				case "$overlay" in
				"1")
					echo "OVERLAYFS=1" >> $BUILD_CONFIG
					;;
				*)
					;;
				esac
			fi
		fi
	elif [ "$board" = "19" ]; then
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
$ECHO $COLOR_ORIGIN"[1] SP7350 Ev Board"$COLOR_ORIGIN
$ECHO $COLOR_ORIGIN"[2] SP7350 IO Board"$COLOR_ORIGIN
$ECHO $COLOR_ORIGIN"[3] SP7350 MC Board"$COLOR_ORIGIN
$ECHO $COLOR_ORIGIN"[4] SP7350 EVK Board"$COLOR_ORIGIN
$ECHO $COLOR_ORIGIN"[5] SP7350 Dual Ev Board"$COLOR_ORIGIN
$ECHO $COLOR_ORIGIN"[6] SP7350 XINK V1 Board"$COLOR_ORIGIN
$ECHO $COLOR_ORIGIN"[7] SP7350 XINK Nano Board"$COLOR_ORIGIN
$ECHO $COLOR_ORIGIN"[8] SP7350 YX5001 Nano Board"$COLOR_ORIGIN
$ECHO $COLOR_ORIGIN"[9] SP7350 SR1 Board"$COLOR_ORIGIN
$ECHO $COLOR_ORIGIN"[10] SP7350 IC1 Board"$COLOR_ORIGIN
$ECHO $COLOR_ORIGIN"[11] SP7350 IT1 Board"$COLOR_ORIGIN
$ECHO $COLOR_ORIGIN"[12] SP7350 DVB Board"$COLOR_ORIGIN
$ECHO $COLOR_ORIGIN"[13] SP7350 EVS Board"$COLOR_ORIGIN
#$ECHO $COLOR_ORIGIN"[19] SP7350 Zebu (ZMem)"$COLOR_ORIGIN
read board

if [ "$board" = "1" ]; then
	ARCH=arm64
	echo "CHIP=SP7350" > $BUILD_CONFIG
	echo "BOARDNAME=ev" >> $BUILD_CONFIG
	echo "LINUX_DTB=sunplus/sp7350-ev" >> $BUILD_CONFIG
elif [ "$board" = "2" ]; then
	ARCH=arm64
	echo "CHIP=SP7350" > $BUILD_CONFIG
	echo "BOARDNAME=dm" >> $BUILD_CONFIG
	echo "LINUX_DTB=sunplus/sp7350-dm" >> $BUILD_CONFIG
elif [ "$board" = "3" ]; then
	ARCH=arm64
	echo "CHIP=SP7350" > $BUILD_CONFIG
	echo "BOARDNAME=mc" >> $BUILD_CONFIG
	echo "LINUX_DTB=sunplus/sp7350-mc" >> $BUILD_CONFIG
elif [ "$board" = "4" ]; then
	ARCH=arm64
	echo "CHIP=SP7350" > $BUILD_CONFIG
	echo "BOARDNAME=evk" >> $BUILD_CONFIG
	echo "LINUX_DTB=sunplus/sp7350-evk" >> $BUILD_CONFIG
elif [ "$board" = "5" ]; then
	ARCH=arm64
	echo "CHIP=SP7350" > $BUILD_CONFIG
	echo "BOARDNAME=dev" >> $BUILD_CONFIG
	echo "LINUX_DTB=sunplus/sp7350-dev" >> $BUILD_CONFIG
elif [ "$board" = "6" ]; then
	ARCH=arm64
	echo "CHIP=SP7350" > $BUILD_CONFIG
	echo "BOARDNAME=xink" >> $BUILD_CONFIG
	echo "LINUX_DTB=sunplus/sp7350-xink" >> $BUILD_CONFIG
elif [ "$board" = "7" ]; then
	ARCH=arm64
	echo "CHIP=SP7350" > $BUILD_CONFIG
	echo "BOARDNAME=xink_nano" >> $BUILD_CONFIG
	echo "LINUX_DTB=sunplus/sp7350-xink-nano" >> $BUILD_CONFIG
elif [ "$board" = "8" ]; then
	ARCH=arm64
	echo "CHIP=SP7350" > $BUILD_CONFIG
	echo "BOARDNAME=yx5001_nano" >> $BUILD_CONFIG
	echo "LINUX_DTB=sunplus/sp7350-yx5001-nano" >> $BUILD_CONFIG
elif [ "$board" = "9" ]; then
	ARCH=arm64
	echo "CHIP=SP7350" > $BUILD_CONFIG
	echo "BOARDNAME=sr1" >> $BUILD_CONFIG
	echo "LINUX_DTB=sunplus/sp7350-sr1" >> $BUILD_CONFIG
elif [ "$board" = "10" ]; then
	ARCH=arm64
	echo "CHIP=SP7350" > $BUILD_CONFIG
	echo "BOARDNAME=ic1" >> $BUILD_CONFIG
	echo "LINUX_DTB=sunplus/sp7350-ic1" >> $BUILD_CONFIG
elif [ "$board" = "11" ]; then
	ARCH=arm64
	echo "CHIP=SP7350" > $BUILD_CONFIG
	echo "BOARDNAME=it1" >> $BUILD_CONFIG
	echo "LINUX_DTB=sunplus/sp7350-it1" >> $BUILD_CONFIG
elif [ "$board" = "12" ]; then
	ARCH=arm64
	echo "CHIP=SP7350" > $BUILD_CONFIG
	echo "BOARDNAME=dvb" >> $BUILD_CONFIG
	echo "LINUX_DTB=sunplus/sp7350-dvb" >> $BUILD_CONFIG
elif [ "$board" = "13" ]; then
	ARCH=arm64
	echo "CHIP=SP7350" > $BUILD_CONFIG
	echo "BOARDNAME=evs" >> $BUILD_CONFIG
	echo "LINUX_DTB=sunplus/sp7350-evs" >> $BUILD_CONFIG
elif [ "$board" = "19" ]; then
	ARCH=arm64
	echo "CHIP=SP7350" > $BUILD_CONFIG
	echo "BOARDNAME=ev" >> $BUILD_CONFIG
	echo "LINUX_DTB=sunplus/sp7350-ev" >> $BUILD_CONFIG
else
	echo "Error: Unknown board!"
	exit 1
fi

if [ "$board" != "19" ]; then
$ECHO $COLOR_GREEN"Select boot devices:"$COLOR_ORIGIN
fi

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
##     ${pid}_${bootdev}_${sel_board}_defconfig --> sp7350_emmc_ev_defconfig
##
## zebu:
##     ${pid}_zebu_${sel_board}_defconfig --> sp7350_zebu_romter_defconfig

set_config_directly=0

## board = SP7350
$ECHO $COLOR_GREEN"Select boot modes:"$COLOR_ORIGIN
$ECHO $COLOR_ORIGIN"[1] Normal boot"$COLOR_ORIGIN
$ECHO $COLOR_ORIGIN"[2] Secure boot"$COLOR_ORIGIN
read secure

if [ "$secure" = "2" ]; then
	echo "SECURE=1" >> $BUILD_CONFIG
	echo "ENCRYPTION=1" >> $BUILD_CONFIG
fi

sel_chip=$(chip_lookup $chip)
set_config_directly=1

chip_name="sp7350"
if [ "$board" = "1" ]; then
	sel_board=ev
elif [ "$board" = "2" ]; then
	sel_board=dm
elif [ "$board" = "3" ]; then
	sel_board=mc
elif [ "$board" = "4" ]; then
	sel_board=evk
elif [ "$board" = "5" ]; then
	sel_board=dev
elif [ "$board" = "6" ]; then
	sel_board=xink
elif [ "$board" = "7" ]; then
	sel_board=xink_nano
elif [ "$board" = "8" ]; then
	sel_board=yx5001_nano
elif [ "$board" = "9" ]; then
	sel_board=sr1
elif [ "$board" = "10" ]; then
	sel_board=ic1
elif [ "$board" = "11" ]; then
	sel_board=it1
elif [ "$board" = "12" ]; then
	sel_board=dvb
elif [ "$board" = "13" ]; then
	sel_board=evs
elif [ "$board" = "19" ]; then
	sel_board=zebu
fi

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

