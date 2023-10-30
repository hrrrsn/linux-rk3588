sudo apt install mkisofs
sudo su -

#location where the original iso of proxmox is
cd /home
#copy into proxmox.mbr the mbr from original iso (first 512byte)
dd if=proxmox-ve_7.3-1.iso bs=512 count=1 of=proxmox.mbr

mkdir /tmp/prox
cd /tmp/prox
mount -t iso9660 -o loop /home/proxmox-ve_7.3-1.iso /mnt/
cd /mnt
tar cf - . | (cd /tmp/prox; tar xfp -)

#Then i unsquashed the pve-installer.squashfs:
cd /tmp/prox
unsquashfs pve-installer.squashfs

#Here I edited the files

#Then I squashed it back

rm pve-installer.squashfs
mksquashfs squashfs-root/ pve-installer.squashfs

#After that I repacked with

xorriso -as mkisofs \
     -o repacked.iso \
     -r -V 'PVE' \
     --modification-date=2023030619475500 \
     --grub2-mbr /home/proxmox.mbr \
     --protective-msdos-label \
     -efi-boot-part --efi-boot-image \
     -c '/boot/boot.cat' \
     -b '/boot/grub/i386-pc/eltorito.img' \
       -no-emul-boot -boot-load-size 4 -boot-info-table --grub2-boot-info \
     -eltorito-alt-boot \
     -e '/efi.img' -no-emul-boot \
     /tmp/prox

#the key part is passing to --grub-mbr the path of the mbr I copied from the original
#I obtained 'repacked.iso' and it's bootable like the original one (I used etcher but I think dd should be ok )