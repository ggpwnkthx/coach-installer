#!/bin/bash
if [ -z "$(command -v unsquashfs)" ]
then
  sudo apt-get install squashfs-tools
fi

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
sudo mv squashfs-root/etc/resolv.conf squashfs-root/etc/resolv.conf.old
sudo cp /etc/resolv.conf squashfs-root/etc/resolv.conf
sudo mount --bind /proc squashfs-root/proc

sudo chroot squashfs-root/ ./make-changes

sudo umount squashfs-root/proc
sudo rm squashfs-root/etc/resolv.conf
sudo mv squashfs-root/etc/resolv.conf.old squashfs-root/etc/resolv.conf
sudo rm squashfs-root/make-changes
sudo rm squashfs-root/initrd.img
sudo rm squashfs-root/vmlinuz

if [ -f /mnt/ceph/fs/containers/provisioner/www/boot/ubuntu/squashfs ]
then
  sudo rm /mnt/ceph/fs/containers/provisioner/www/boot/ubuntu/squashfs
fi
sudo mksquashfs squashfs-root /mnt/ceph/fs/containers/provisioner/www/boot/ubuntu/squashfs -b 1024k -comp xz -Xbcj x86 -e boot
