#!/bin/bash
clear
printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
echo "COACH - Cluster Of Arbitrary, Cheap, Hardware"
printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
echo "Setting up the Ubuntu 16.04 Boot Image | chroot"
printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
if [ -d squashfs-root ]
then
  sudo rm -r squashfs-root
fi
wget https://cloud-images.ubuntu.com/xenial/current/xenial-server-cloudimg-amd64.squashfs -O filesystem.squashfs
sudo unsquashfs filesystem.squashfs
sudo wget https://raw.githubusercontent.com/ggpwnkthx/coach/master/docker/provisioner/pxe/chroot.changes -O squashfs-root/make-changes
sudo chmod +x squashfs-root/make-changes
sudo chroot squashfs-root/ ./make-changes
if [ -f /mnt/ceph/fs/containers/provisioner/www/boot/ubuntu/squashfs ]
then
  sudo rm /mnt/ceph/fs/containers/provisioner/www/boot/ubuntu/squashfs
fi
sudo mksquashfs squashfs-root /mnt/ceph/fs/containers/provisioner/www/boot/ubuntu/squashfs -b 1024k -comp xz -Xbcj x86 -e boot
