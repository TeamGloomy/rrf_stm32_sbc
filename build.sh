#!/bin/bash

if [ $# -lt 1 ]; then
    echo "Usage: $0 <board>"
    exit 1
fi

BOARD=$1
RRF_VERSION="RRF-3.4.6"
MAINTAINER="TeamGloomy"
MAINTAINERMAIL="teamgloomyrrf@gmail.com"
RELEASE_NAME=jammy
KERNEL_BRANCH="current"

# Checkout Armbian build script
git clone --depth 1 https://github.com/armbian/build 

# Merge supported boards into Armbian build environment
mkdir -p ./build/userpatches
cp -R ./armbian/config/boards/* ./build/config/boards/
cp -R ./armbian/userpatches/* ./build/userpatches/
# Path for kernel user patches : 
# Sunxi64 : KERNELPATCHDIR="archive/sunxi-${KERNEL_MAJOR_MINOR}"
# https://github.com/armbian/build/blob/main/config/sources/families/include/sunxi64_common.inc#L41

# cleaning leftovers if any
rm -rf ./build/output/images/*

cd build
./compile.sh VENDOR="${RRF_VERSION}" MAINTAINER="${MAINTAINER}" MAINTAINERMAIL="${MAINTAINERMAIL}" BOARD="${BOARD}" BRANCH="${KERNEL_BRANCH}" RELEASE="${RELEASE_NAME}" BUILD_MINIMAL=no KERNEL_CONFIGURE=no KERNEL_GIT=full BOOTFS_TYPE=fat COMPRESS_OUTPUTIMAGE=sha,xz

# Possible options :
# BUILD_DESKTOP=yes DESKTOP_ENVIRONMENT=xfce DESKTOP_ENVIRONMENT_CONFIG_NAME=config_base
# BOOTBRANCH='tag:v2021.01
# KERNELBRANCH='branch:linux-5.10.y'
