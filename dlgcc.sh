#!/bin/bash
# set -x
TOOLCHAIN_AARCH32_PREFIX=arm-none-eabi
TOOLCHAIN_AARCH64_PREFIX=aarch64-none-linux-gnu

GCC_ARM_NONE=arm-gnu-toolchain-12.3.rel1-x86_64-arm-none-eabi
GCC_AARCH64_NONE=arm-gnu-toolchain-12.3.rel1-x86_64-aarch64-none-linux-gnu
GCC_Q4_MAJOR=gcc-arm-none-eabi-10-2020-q4-major-x86_64-linux
GCC_Q4_MAJOR_PATH=gcc-arm-none-eabi-10-2020-q4-major
cd crossgcc/ 

if [ ! -d ${GCC_ARM_NONE} ]; then
    if [ -f ${GCC_ARM_NONE}.tar.xz ]; then
        rm ${GCC_ARM_NONE}.tar.xz
    fi
    wget https://developer.arm.com/-/media/Files/downloads/gnu/12.3.rel1/binrel/${GCC_ARM_NONE}.tar.xz
    tar Jxvf ${GCC_ARM_NONE}.tar.xz
    if [ $? -eq 0 ]; then
        rm ${GCC_ARM_NONE}.tar.xz
    else
        exit 1
    fi
fi

if [ ! -d ${GCC_AARCH64_NONE} ]; then
    if [ -f ${GCC_AARCH64_NONE}.tar.xz ]; then
        rm ${GCC_AARCH64_NONE}.tar.xz
    fi
    wget https://developer.arm.com/-/media/Files/downloads/gnu/12.3.rel1/binrel/${GCC_AARCH64_NONE}.tar.xz
    tar Jxvf ${GCC_AARCH64_NONE}.tar.xz
    if [ $? -eq 0 ]; then
        rm ${GCC_AARCH64_NONE}.tar.xz
    else
        exit 1
    fi
fi

if [ ! -d ${GCC_Q4_MAJOR_PATH} ]; then
    if [ -f ${GCC_Q4_MAJOR}.tar.bz2  ]; then
        rm ${GCC_Q4_MAJOR}.tar.bz2 
    fi
    wget https://developer.arm.com/-/media/Files/downloads/gnu-rm/10-2020q4/${GCC_Q4_MAJOR}.tar.bz2 
    tar jxvf ${GCC_Q4_MAJOR}.tar.bz2
    if [ $? -eq 0 ]; then
        rm ${GCC_Q4_MAJOR}.tar.bz2
    else
        exit 1
    fi
fi

CROSSGCC_DIR=$(realpath .)
TOOLCHAIN_AARCH32_PATH=$CROSSGCC_DIR/$GCC_ARM_NONE
TOOLCHAIN_AARCH64_PATH=$CROSSGCC_DIR/$GCC_AARCH64_NONE
echo "TOOLCHAIN_AARCH32_PATH=$TOOLCHAIN_AARCH32_PATH" > $CROSSGCC_DIR/toolchain.config
echo "TOOLCHAIN_AARCH64_PATH=$TOOLCHAIN_AARCH64_PATH" >> $CROSSGCC_DIR/toolchain.config
echo "TOOLCHAIN_AARCH32_PREFIX=$TOOLCHAIN_AARCH32_PREFIX" >> $CROSSGCC_DIR/toolchain.config
echo "TOOLCHAIN_AARCH64_PREFIX=$TOOLCHAIN_AARCH64_PREFIX" >> $CROSSGCC_DIR/toolchain.config
