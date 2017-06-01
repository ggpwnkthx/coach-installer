#!/bin/bash

sudo wget https://raw.githubusercontent.com/ggpwnkthx/coach/master/docker/provisioner/pxe/index.php -O /mnt/ceph/fs/containers/provisioner/www/index.php

if [ -d initramfs-tools ]
then
  sudo rm -r initramfs-tools
fi
cp -r /etc/initramfs-tools initramfs-tools
sed -i '/^MODULES=/s/=.*/=netboot/' initramfs-tools/initramfs.conf
echo "mlx4_core" | tee --append initramfs-tools/modules
echo "mlx4_ib" | tee --append initramfs-tools/modules
echo "ib_umad" | tee --append initramfs-tools/modules
echo "ib_uverbs" | tee --append initramfs-tools/modules
echo "ib_ipoib" | tee --append initramfs-tools/modules
wget https://raw.githubusercontent.com/ggpwnkthx/coach/master/docker/provisioner/pxe/initramfs.script -O initramfs-tools/scripts/init-bottom/network
chmod +x initramfs-tools/scripts/init-bottom/network
mkinitramfs -d initramfs-tools -o initrd
sudo mv initrd /mnt/ceph/fs/containers/provisioner/www/boot/ubuntu/initrd

if [ -d squashfs-root ]
then
  sudo rm -r squashfs-root
fi
wget https://cloud-images.ubuntu.com/xenial/current/xenial-server-cloudimg-amd64.squashfs -O filesystem.squashfs
sudo unsquashfs filesystem.squashfs
echo "useradd ubuntu" | sudo tee squashfs-root/make-changes
echo 'passwd ubuntu' | sudo tee --append squashfs-root/make-changes
echo "adduser ubuntu sudo" | sudo tee --append squashfs-root/make-changes
echo "exit" | sudo tee --append squashfs-root/make-changes
sudo chmod +x squashfs-root/make-changes
sudo chroot squashfs-root/ ./make-changes
if [ -f /mnt/ceph/fs/containers/provisioner/www/boot/ubuntu/squashfs ]
then
  sudo rm /mnt/ceph/fs/containers/provisioner/www/boot/ubuntu/squashfs
fi
sudo mksquashfs squashfs-root /mnt/ceph/fs/containers/provisioner/www/boot/ubuntu/squashfs -b 1024k -comp xz -Xbcj x86 -e boot

#sudo wget https://cloud-images.ubuntu.com/xenial/current/unpacked/xenial-server-cloudimg-amd64-initrd-generic -O /mnt/ceph/fs/containers/provisioner/www/boot/ubuntu/initrd
sudo wget https://cloud-images.ubuntu.com/xenial/current/unpacked/xenial-server-cloudimg-amd64-vmlinuz-generic -O /mnt/ceph/fs/containers/provisioner/www/boot/ubuntu/vmlinuz
