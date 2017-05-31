#!/bin/bash
./download_and_run "docker/provisioner/dnsmasq/deploy.sh" $@

services=(provisioner_lamp)
for s in ${services[@]}
do
  if [ ! -z "$(sudo docker ps -a | grep $s)" ]
  then
    sudo docker rm -f $s
  fi
done

if [ ! -d /mnt/ceph/fs/containers/provisioner/www ]
then
  sudo mkdir /mnt/ceph/fs/containers/provisioner/www
fi
sudo wget https://raw.githubusercontent.com/ggpwnkthx/coach/master/docker/provisioner/ipxe.php -O /mnt/ceph/fs/containers/provisioner/www/index.php

cp -r /etc/initramfs-tools initramfs-tools
sed -i '/^MODULES=/s/=.*/=netboot/' initramfs-tools/initramfs.conf
echo "mlx4_core" | tee --append initramfs-tools/modules
echo "mlx4_ib" | tee --append initramfs-tools/modules
echo "ib_umad" | tee --append initramfs-tools/modules
echo "ib_uverbs" | tee --append initramfs-tools/modules
echo "ib_ipoib" | tee --append initramfs-tools/modules
mkinitramfs -d initramfs-tools -o initrd
sudo mv initrd /mnt/ceph/fs/containers/provisioner/www/boot/ubuntu/initrd
sudo cp /boot/vmlinuz-`uname -r` /mnt/ceph/fs/containers/provisioner/www/boot/ubuntu/vmlinuz

wget https://cloud-images.ubuntu.com/xenial/current/xenial-server-cloudimg-amd64.squashfs -O squashfs
unsquashfs squashfs

sudo wget https://cloud-images.ubuntu.com/xenial/current/unpacked/xenial-server-cloudimg-amd64-initrd-generic -O /mnt/ceph/fs/containers/provisioner/www/boot/ubuntu/initrd
sudo wget https://cloud-images.ubuntu.com/xenial/current/unpacked/xenial-server-cloudimg-amd64-vmlinuz-generic -O /mnt/ceph/fs/containers/provisioner/www/boot/ubuntu/vmlinuz

sudo chmod -R +r /mnt/ceph/fs/containers/provisioner

sudo docker run -d \
  --name provisioner_lamp --restart=always --net=host \
  -v /mnt/ceph/fs/containers/provisioner/www:/www \
  janes/alpine-lamp
