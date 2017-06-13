#!/bin/bash
if [ ! -d /mnt/ceph/fs/containers/provisioner/www/boot/ubuntu ]
then
  sudo mkdir -p /mnt/ceph/fs/containers/provisioner/www/boot/ubuntu
fi
sudo wget https://raw.githubusercontent.com/ggpwnkthx/coach/master/docker/provisioner/pxe/ipxe.php -O /mnt/ceph/fs/containers/provisioner/www/ipxe.php

if [ ! -d /mnt/ceph/fs/containers/provisioner/www/2009-04-04/meta-data ]
then
  sudo mkdir -p /mnt/ceph/fs/containers/provisioner/www/2009-04-04/meta-data
fi
if [ ! -d /mnt/ceph/fs/containers/provisioner/www/2009-04-04/meta-data/instance-id ]
then
  sudo mkdir -p /mnt/ceph/fs/containers/provisioner/www/2009-04-04/meta-data/instance-id
fi
if [ ! -d /mnt/ceph/fs/containers/provisioner/www/2009-04-04/meta-data/hostname ]
then
  sudo mkdir -p /mnt/ceph/fs/containers/provisioner/www/2009-04-04/meta-data/hostname
fi
if [ ! -d /mnt/ceph/fs/containers/provisioner/www/2009-04-04/user-data ]
then
  sudo mkdir -p /mnt/ceph/fs/containers/provisioner/www/2009-04-04/user-data
fi
sudo ln -s /mnt/ceph/fs/containers/provisioner/www/2009-04-04 /mnt/ceph/fs/containers/provisioner/www/latest
echo "test" | sudo tee  /mnt/ceph/fs/containers/provisioner/www/latest/meta-data/instance-id/index.php
echo "test" | sudo tee  /mnt/ceph/fs/containers/provisioner/www/latest/meta-data/hostname/index.php
./download_and_run "docker/provisioner/pxe/vmlinuz.sh"
./download_and_run "docker/provisioner/pxe/initrd.sh"
./download_and_run "docker/provisioner/pxe/filesystem.sh"
