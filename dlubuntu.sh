#!/bin/bash

COLOR_RED="\033[0;1;31m"
COLOR_ORIGIN="\033[0m"

ECHO="echo -e"

get_ubuntu_prebuilds()
{
    UBUNTU_PREBUILD_FILES=`wget -qO- http://${UBUNTU_PREBUILD_URL}/packages/armhf/${UBUNTU_ROOTFS_NAME}.list | cat`
    if [ "$?" != "0" ]; then
        $ECHO $COLOR_RED"get $UBUNTU_ROOTFS_NAME failed!"$COLOR_ORIGIN
        exit 1
    fi
}

get_ubuntu_prebuild_md5()
{
    UBUNTU_PREBUILD_MD5FILES=`wget -qO- http://${UBUNTU_PREBUILD_URL}/packages/armhf/${UBUNTU_ROOTFS_NAME}.md5 | cat`
    if [ "$?" != "0" ]; then
        $ECHO $COLOR_RED"get $UBUNTU_ROOTFS_NAME.md5 failed!"$COLOR_ORIGIN
        exit 1
    fi
}

UBUNTU_ROOTFS_NAME=`basename "${ROOTFS#*:}"`

get_ubuntu_prebuilds
get_ubuntu_prebuild_md5

UBUNTU_PATH="linux/rootfs/initramfs/ubuntu/${UBUNTU_ROOTFS_NAME}"

cd $UBUNTU_PATH

    if [ -f "$UBUNTU_ROOTFS_NAME.md5" ]; then
        buffer=$(cat $UBUNTU_ROOTFS_NAME.md5)
    fi

    if [ "$UBUNTU_PREBUILD_MD5FILES" != "$buffer" ]; then
        if [ "$?" = "0" ];then
            for file in $UBUNTU_PREBUILD_FILES; do
                wget --no-use-server-timestamps -nv http://${UBUNTU_PREBUILD_URL}/packages/armhf/${file} -O ${file}
                if [ "$?" != "0" ]; then
                    $ECHO $COLOR_RED"get ${file} failed!"$COLOR_ORIGIN
                    exit 1
                fi
            done
        fi
        $ECHO "$UBUNTU_PREBUILD_MD5FILES" > $UBUNTU_ROOTFS_NAME.md5
        md5sum -c $UBUNTU_ROOTFS_NAME.md5
    fi

    if [ "$?" != "0" ]; then
        $ECHO $COLOR_RED"$UBUNTU_ROOTFS_NAME md5 error!"$COLOR_ORIGIN
        exit 1
    fi

cd - > /dev/null
