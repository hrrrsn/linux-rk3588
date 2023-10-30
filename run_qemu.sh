#!/bin/bash
disk_image=/home/harrisongulliver/shared/linux-rk3588/build/debian/bookworm.img

qemu-system-aarch64 \
-daemonize     -M virt \
    -cpu cortex-a57 \
    -smp 2 \
    -m 2G \
    -drive if=none,file=$disk_image,format=raw,id=hd0 \
    -device virtio-blk-device,drive=hd0 \
    -netdev user,id=net0 \
    -device virtio-net-device,netdev=net0 \
    -vnc :0,password \
    -bios /usr/share/qemu-efi-aarch64/QEMU_EFI.fd \
    -monitor telnet:127.0.0.1:4444,server,nowait;
echo "change vnc password secure1103" | nc -q 1 127.0.0.1 4444
