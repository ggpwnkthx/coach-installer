#!/bin/bash
if [ ! -d /mnt/ceph/fs/containers/provisioner/www/boot/ubuntu ]
then
  sudo mkdir -p /mnt/ceph/fs/containers/provisioner/www/boot/ubuntu
fi
sudo wget https://raw.githubusercontent.com/ggpwnkthx/coach/master/docker/provisioner/pxe/index.php -O /mnt/ceph/fs/containers/provisioner/www/index.php
./download_and_run "docker/provisioner/pxe/vmlinuz.sh"
./download_and_run "docker/provisioner/pxe/initrd.sh"
./download_and_run "docker/provisioner/pxe/filesystem.sh"
