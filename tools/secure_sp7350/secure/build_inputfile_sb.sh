#!/bin/bash

# do this once to generate OTP key for IC
if [ ! -d otp_Device_keys ]; then
./gen_OTP_keys.sh
fi

#[ $? -ne 0 ] && echo "fail!" && exit 1

echo "[secure] input file = $1 sb_info = $2"

# for each xboot build
./00_prepare.sh $1
[ $? -ne 0 ] && echo "fail!" && exit 1
./01_gen_Build_keys.sh
[ $? -ne 0 ] && echo "fail!" && exit 1
./02_encrypt_inputfile.sh $1
[ $? -ne 0 ] && echo "fail!" && exit 1
./03_ecies_encrypt_KAES.sh
[ $? -ne 0 ] && echo "fail!" && exit 1
./04_gen_sb_info.sh $2
[ $? -ne 0 ] && echo "fail!" && exit 1
./05_sign_inputfile_sb.sh $1
[ $? -ne 0 ] && echo "fail!" && exit 1

echo "$0 : Well Done"
