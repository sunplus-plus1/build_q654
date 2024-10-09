#!/bin/bash

COLOR_RED="\033[0;1;31m"
COLOR_ORIGIN="\033[0m"

ECHO="echo -e"

UBUNTU_PATH="linux/rootfs/initramfs/ubuntu"

get_ubuntu_prebuilds()
{
    if [ "$USE_FTP" == "0" ]; then
        UBUNTU_PREBUILD_FILES=`wget -qO- http://${UBUNTU_PREBUILD_URL}/packages/armhf/${UBUNTU_ROOTFS_NAME}.list | cat`
        if [ "$?" != "0" ]; then
            $ECHO $COLOR_RED"get $UBUNTU_ROOTFS_NAME failed!"$COLOR_ORIGIN
            exit 1
        fi
    fi
}

get_ubuntu_prebuild_md5()
{
    if [ "$USE_FTP" == "0" ]; then
        wget -q http://${UBUNTU_PREBUILD_URL}/packages/armhf/${UBUNTU_ROOTFS_NAME}.md5 -O ${UBUNTU_ROOTFS_NAME}.md5.0
    else
        wget -q ftp://${UBUNTU_PREBUILD_URL}/ubuntu_prebuild/${UBUNTU_ROOTFS_NAME}/${UBUNTU_ROOTFS_NAME}.md5 -O ${UBUNTU_ROOTFS_NAME}.md5.0
    fi
    if [ "$?" != "0" ]; then
        $ECHO $COLOR_RED"get $UBUNTU_ROOTFS_NAME.md5 failed!"$COLOR_ORIGIN
        exit 1
    fi
    dos2unix $UBUNTU_ROOTFS_NAME.md5.0 2> /dev/null
}

UBUNTU_ROOTFS_NAME=`basename "${ROOTFS#*:}"`

UBUNTU_ROOTFS_PATH="linux/rootfs/initramfs/ubuntu/${UBUNTU_ROOTFS_NAME}"

cd $UBUNTU_ROOTFS_PATH

    get_ubuntu_prebuilds
    get_ubuntu_prebuild_md5

    retry=0
    is_diff=1

    if [ -f "${UBUNTU_ROOTFS_NAME}.md5" ]; then
        diff -q ${UBUNTU_ROOTFS_NAME}.md5.0 ${UBUNTU_ROOTFS_NAME}.md5 2> /dev/null
        if [ "$?" = "0" ]; then is_diff=0; fi
    fi
    if [ "$is_diff" != "0" ]; then
        while true
        do
            if [ "$USE_FTP" == "0" ]; then
                for file in $UBUNTU_PREBUILD_FILES; do
                    wget --no-use-server-timestamps -nv http://${UBUNTU_PREBUILD_URL}/packages/armhf/${file} -O ${file}
                    if [ "$?" != "0" ]; then
                        $ECHO $COLOR_RED"get ${file} failed!"$COLOR_ORIGIN
                        exit 1
                    fi
                done
            else
                wget -r --no-verbose --no-parent -nH --cut-dirs=2 --connect-timeout=5 --tries=1 ftp://${UBUNTU_PREBUILD_URL}/ubuntu_prebuild/${UBUNTU_ROOTFS_NAME}/			
                if [ "$?" != "0" ]; then
                    $ECHO $COLOR_RED"get ${UBUNTU_ROOTFS_NAME} failed!"$COLOR_ORIGIN
                    exit 1
                fi
            fi
            dos2unix $UBUNTU_ROOTFS_NAME.md5
            md5sum -c $UBUNTU_ROOTFS_NAME.md5
            if [ "$?" != "0" ]; then
                retry=$((retry + 1))
                if [ $retry -ge 2 ]; then
                    $ECHO $COLOR_RED"$UBUNTU_ROOTFS_NAME md5 error!"$COLOR_ORIGIN
                    exit 1
                else
                    continue
                fi
            fi
            break
        done
    fi
    rm -f $UBUNTU_ROOTFS_NAME.md5.0 > /dev/null
cd - > /dev/null
