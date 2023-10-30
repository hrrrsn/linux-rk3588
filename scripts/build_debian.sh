#!/bin/bash
  #work_dir=$(realpath "$(dirname -- "$(readlink -f -- "$0")")/../build/debian")
  work_dir=/home/harrisongulliver/shared/linux-rk3588/build/debian
  root_dir=$work_dir/root

  debian_version=bookworm
  # install_desktop="gnome"

  disk_image=$work_dir/$debian_version.img
  disk_size="20G"

  echo "Building Debian $debian_version Image..."

  if [ "$(id -u)" -ne 0 ]; then 
      echo "Please run as root"
      exit 1
  fi

  # Clean up dirs
  test -d $root_dir/boot/efi && umount $root_dir/boot/efi
  test -d $root_dir && umount $root_dir
  test -d $root_dir && rm -rf $root_dir
  test -f $disk_image && rm -f $disk_image
  test -b /dev/loop0 && losetup -D /dev/loop0

  # Create disk image and root directory
  test -d $root_dir || mkdir -p $root_dir
  qemu-img create -f raw $disk_image $disk_size
  
  # Partition the disk image
  parted $disk_image -- mklabel gpt
  parted $disk_image -- mkpart EFI fat32 1MiB 501MiB
  parted $disk_image -- set 1 boot on
  parted $disk_image -- mkpart primary ext4 501MiB 100%

  efi_uuid=$(uuidgen)
  root_uuid=$(uuidgen)

  sgdisk -u 1:$efi_uuid $disk_image
  sgdisk -u 2:$root_uuid $disk_image
  
  # Associate the disk image with a loop device
  losetup -P /dev/loop0 $disk_image
  
  # Format the partitions
  mkfs.fat -F32 /dev/loop0p1
  mkfs.ext4 /dev/loop0p2

  echo MOUNTING
  # Mount the partitions
  mount /dev/loop0p2 $root_dir
  mkdir -p $root_dir/boot/efi
  mount /dev/loop0p1 $root_dir/boot/efi
  
  # Bootstrap the Debian system
  debootstrap --arch=arm64 $debian_version $root_dir https://mirror.fsmg.org.nz/debian/

  # Copy kernels to chroot
  rsync -avh --progress $work_dir/install/ $root_dir/install/

  mkdir -p $root_dir/{dev,proc,sys}
  mount --bind /dev $root_dir/dev
  mount --bind /proc $root_dir/proc
  mount --bind /sys $root_dir/sys

  # Chroot and install kernel, grub and systemd
  chroot $root_dir /bin/bash -c "apt-get update; dpkg -i /install/*.deb; \
    apt-get install -y grub-efi-arm64 systemd gpgv2"

  # Install grub
  mkdir -p $root_dir/boot/efi/EFI/BOOT
  chroot $root_dir /bin/bash -c "grub-install --target=arm64-efi --efi-directory=/boot/efi --bootloader-id=debian --recheck"

  patch $root_dir/etc/grub.d/10_linux < $work_dir/../../patch/10_linux.patch 
  chroot $root_dir /bin/bash -c "update-grub; cp /boot/efi/EFI/debian/grubaa64.efi /boot/efi/EFI/BOOT/BOOTAA64.EFI"
  echo "\EFI\debian\grubaa64.efi" > $root_dir/boot/efi/startup.nsh

  cp $root_dir/boot/grub/grub.cfg $root_dir/boot/grub/grub.cfg.original
  loop_uuid=$(blkid -s UUID -o value /dev/loop0p2)
  sed -i 's/$loop_uuid/$root_uuid/g' $root_dir/boot/grub/grub.cfg

  echo "# debug: loop_uuid: $loop_uuid" | tee -a $root_dir/boot/grub/grub.cfg
  echo "# debug: efi_uuid: $efi_uuid" | tee -a $root_dir/boot/grub/grub.cfg
  echo "# debug: root_uuid: $root_uuid" | tee -a $root_dir/boot/grub/grub.cfg
  

  sed -i "s|root=/dev/loop0p2|root=ROOTUUID=$root_uuid|g" $root_dir/boot/grub/grub.cfg
  echo "UUID=$root_uuid /               ext4    errors=remount-ro 0       1" > $root_dir/etc/fstab

  # Install desktop environment
  if [ ! -z "$install_desktop" ]; then
    chroot $root_dir /bin/bash -c "DEBIAN_FRONTEND=noninteractive apt-get install -y $install_desktop"
  fi

  # Set root password
  chroot $root_dir /bin/bash -c "echo root:password | chpasswd"

  # Set hostname
  echo "debian-rk3588" > $root_dir/etc/hostname

  # Set timezone
  chroot $root_dir /bin/bash -c "ln -sf /usr/share/zoneinfo/Pacific/Auckland /etc/localtime"
  
  # Unmount and detach
  rm -rf $root_dir/install
  chroot $root_dir /bin/bash -c "apt-get clean -y; sync;"
  
  umount $root_dir/{boot/efi,dev,proc,sys}
  umount $root_dir
  losetup -D /dev/loop0

  qemu-img convert -f raw -O qcow2 $disk_image $disk_image.qcow2
  
  echo "Debian image created."