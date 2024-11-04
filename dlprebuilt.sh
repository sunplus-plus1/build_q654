#!/bin/bash

source build/dload.sh

INITRAMFS="linux/rootfs/initramfs"
prebuiltversion=$(echo "$ROOTFS" | grep -oP '\d+\.\d+')

WORKPATH="${INITRAMFS}/prebuilt/"
FILENAME="vip9000sdk"
download


