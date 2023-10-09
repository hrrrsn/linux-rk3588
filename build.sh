#!/bin/bash
# Linux kernel build script for Rockchip RK3588
set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

    if [ "$(id -u)" -ne 0 ]; then 
        echo "Please run as root"
        exit 1
    fi

    if [ -z "$1" ]; then
        echo "No kernel version specified. Exiting."
        exit 1
    fi

    LINUX_VERSION=$1
    source "config/${LINUX_VERSION}"

    echo "Building Linux ${LINUX_VERSION} for Rockchip RK3588"

    export ARCH=arm64
    export CROSS_COMPILE=aarch64-linux-gnu-

    cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
    mkdir -p build && cd build

    if [ ! -d "linux-${LINUX_GIT_BRANCH}" ]; then
        echo "git clone: ${LINUX_GIT_REPO} ${LINUX_GIT_BRANCH}"
        git clone --single-branch --progress -b $LINUX_GIT_BRANCH $LINUX_GIT_REPO --depth=100 "linux-${LINUX_GIT_BRANCH}"
    else
        echo "git pull: ${LINUX_GIT_REPO} ${LINUX_GIT_BRANCH}"
        cd "linux-${LINUX_GIT_BRANCH}"
        git pull origin ${LINUX_GIT_BRANCH}
        cd ..
    fi

    if [ ! -d "zfs-${ZFS_GIT_BRANCH}" ]; then
        echo "git clone: ${ZFS_GIT_REPO} ${ZFS_GIT_BRANCH}"
        git clone --single-branch --progress -b $ZFS_GIT_BRANCH $ZFS_GIT_REPO --depth=100 "zfs-${ZFS_GIT_BRANCH}"
    else
        echo "git pull: ${ZFS_GIT_REPO} ${ZFS_GIT_BRANCH}"
        cd "zfs-${ZFS_GIT_BRANCH}"
        git pull origin ${ZFS_GIT_BRANCH}
        cd ..
    fi

    cd "linux-${LINUX_GIT_BRANCH}" 
        make $LINUX_DEFCONFIG
        make prepare
    cd ../

    cd "zfs-${ZFS_GIT_BRANCH}"
        ./autogen.sh

        if [ "$(uname -m)" = "x86_64" ]; then
            ./configure --host=aarch64-linux-gnu --enable-linux-builtin --with-linux="../linux-${LINUX_GIT_BRANCH}/"
        else
            ./configure --enable-linux-builtin --with-linux="../linux-${LINUX_GIT_BRANCH}/"
        fi

        ./copy-builtin "../linux-${LINUX_GIT_BRANCH}/" 
    cd "../linux-${LINUX_GIT_BRANCH}/"

    grep -q "^CONFIG_ZFS=" .config || echo "CONFIG_ZFS=y" >> .config
    grep -q "^CONFIG_SPL=" .config || echo "CONFIG_SPL=y" >> .config

    make prepare
    make KERNELRELEASE=$LINUX_VERSION KBUILD_IMAGE="arch/arm64/boot/Image" ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j "$(nproc)" bindeb-pkg

    rm -f ../linux-image-*dbg*.deb ../linux-libc-dev_*.deb ../*.buildinfo ../*.changes ../*.dsc ../*.tar.gz


#