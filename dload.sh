#!/bin/bash

COLOR_RED="\033[0;1;31m"
COLOR_ORIGIN="\033[0m"

ECHO="echo -e"

dos2unix_func()
{
    sed -i 's/\r$//' $1
}

get_file_md5()
{
    if [ "$USE_FTP" == "0" ]; then
        wget -q ${URL_PROTOCAL}://${UBUNTU_PREBUILD_URL}/packages/prebuilt/${FILENAME}.md5 -O ${FILENAME}.md5.0
    else
        wget -q ftp://${UBUNTU_PREBUILD_URL}/app_prebuilt/${FILENAME}.md5 -O ${FILENAME}.md5.0
    fi
    if [ "$?" != "0" ]; then
        $ECHO $COLOR_RED"get $FILENAME.md5 failed!"$COLOR_ORIGIN
        exit 1
    fi

    dos2unix_func $FILENAME.md5.0
}

download_file() {

    retry=0
    is_diff=1
    get_file_md5

    if [ -f "${FILENAME}.md5" ]; then
        diff -q ${FILENAME}.md5.0 ${FILENAME}.md5 2> /dev/null
        if [ "$?" = "0" ]; then 
            is_diff=0
        else
            rm -rf ${FILENAME}
        fi
    fi
    
    if [ "$is_diff" != "0" ]; then
        
        echo -ne "Downloading ${FILENAME}.tar.bz2 ... " 
        
        while true
        do
            if [ "$USE_FTP" == "0" ]; then
                wget --no-use-server-timestamps -nv ${URL_PROTOCAL}://${UBUNTU_PREBUILD_URL}/packages/prebuilt/${FILENAME}.tar.bz2 
                if [ "$?" != "0" ]; then
                    $ECHO $COLOR_RED"get ${FILENAME}.tar.bz2 failed!"$COLOR_ORIGIN
                    exit 1
                fi
            else
                wget --no-verbose --no-parent -nH --cut-dirs=2 --connect-timeout=5 --tries=1 ftp://${UBUNTU_PREBUILD_URL}/app_prebuilt/${FILENAME}.tar.bz2		
                if [ "$?" != "0" ]; then
                    $ECHO $COLOR_RED"get ${FILENAME}.tar.bz2 failed!"$COLOR_ORIGIN
                    exit 1
                fi
            fi
            dos2unix_func $FILENAME.md5.0
            md5sum -c $FILENAME.md5.0
            if [ "$?" != "0" ]; then
                rm -f ${FILENAME}.tar.bz2 
                retry=$((retry + 1))
                if [ $retry -ge 2 ]; then
                    $ECHO $COLOR_RED"$FILENAME md5 error!"$COLOR_ORIGIN
                    exit 1
                else
                    continue
                fi
            fi
            tar jxvf ${FILENAME}.tar.bz2 > /dev/null 2>&1
            if [ "$?" != "0" ]; then
                $ECHO $COLOR_RED"extract ${FILENAME}.tar.bz2 failed!"$COLOR_ORIGIN
                exit 1
            fi

            break
        done
        if [ -f "$FILENAME.md5.0" ]; then
            mv $FILENAME.md5.0 $FILENAME.md5
        fi
        echo ""
    fi
}

download()
{
    cd ${WORKPATH}
        rm -f $FILENAME.md5.0
        rm -f $FILENAME.tar.bz2

        download_file

        rm -f ${FILENAME}.tar.bz2
    cd - > /dev/null
}



