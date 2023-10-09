#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

LINUX_GIT_REPO="https://github.com/Joshua-Riek/linux.git"
LINUX_GIT_BRANCH="v6.5-rc2-panthor-rk3588"
LINUX_DEFCONFIG="linux-rockchip-rk3588_defconfig"

ZFS_GIT_REPO="https://github.com/openzfs/zfs.git"
ZFS_GIT_BRANCH="zfs-2.2-release"

LINUX_VERSION="6.5-rc2-panthor-rk3588"

echo "Building Linux ${LINUX_VERSION} for Rockchip RK3588"

export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p build && cd build

# if [[ "${MAINLINE}" != "Y" ]]; then
#     test -d linux-rockchip || git clone --single-branch --progress -b turing-rk1 https://github.com/Joshua-Riek/linux-rockchip.git linux-rockchip
#     cd linux-rockchip

#     # Compile kernel into a deb package
#     dpkg-buildpackage -a "$(cat debian/arch)" -d -b -nc -uc

#     rm -f ../*.buildinfo ../*.changes
# else
    echo "git clone: ${LINUX_GIT_REPO} ${LINUX_GIT_BRANCH}"
    test -d "linux-${LINUX_GIT_BRANCH}" ||  git clone --single-branch --progress -b $LINUX_GIT_BRANCH $LINUX_GIT_REPO --depth=100 "linux-${LINUX_GIT_BRANCH}"

    echo "git clone: ${ZFS_GIT_REPO} ${ZFS_GIT_BRANCH}"
    test -d zfs || git clone --single-branch --progress -b $ZFS_GIT_BRANCH $ZFS_GIT_REPO --depth=100

    cd "linux-${LINUX_GIT_BRANCH}" 
        make $LINUX_DEFCONFIG
        make prepare
    cd ../

    cd zfs
        ./autogen.sh
        ./configure --host=aarch64-linux-gnu --enable-linux-builtin --with-linux="../linux-${LINUX_GIT_BRANCH}/" 
        # --build=x86_64-linux 
        ./copy-builtin "../linux-${LINUX_GIT_BRANCH}/" 
    cd "../linux-${LINUX_GIT_BRANCH}/"

    #sed -i 's/# CONFIG_ZFS is not set/CONFIG_ZFS=y/' .config
        grep -q "^CONFIG_ZFS=" .config || echo "CONFIG_ZFS=y" >> .config
        grep -q "^CONFIG_SPL=" .config || echo "CONFIG_SPL=y" >> .config

        make prepare
        make KERNELRELEASE=$LINUX_VERSION KBUILD_IMAGE="arch/arm64/boot/Image" -j "$(nproc)" bindeb-pkg

    rm -f ../linux-image-*dbg*.deb ../linux-libc-dev_*.deb ../*.buildinfo ../*.changes ../*.dsc ../*.tar.gz
# fi