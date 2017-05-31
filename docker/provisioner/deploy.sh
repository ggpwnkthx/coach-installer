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

if [ -d initramfs-tools ]
then
  sudo rm -r initramfs-tools
fi
cp -r /etc/initramfs-tools initramfs-tools
echo "chmod -R +x /scripts" | tee initramfs-tools/scripts/local-top/chmod-all
chmod +x initramfs-tools/scripts/init-top/chmod-all
sed -i '/^MODULES=/s/=.*/=netboot/' initramfs-tools/initramfs.conf
echo "mlx4_core" | tee --append initramfs-tools/modules
echo "mlx4_ib" | tee --append initramfs-tools/modules
echo "ib_umad" | tee --append initramfs-tools/modules
echo "ib_uverbs" | tee --append initramfs-tools/modules
echo "ib_ipoib" | tee --append initramfs-tools/modules
mkinitramfs -d initramfs-tools -o initrd
sudo mv initrd /mnt/ceph/fs/containers/provisioner/www/boot/ubuntu/initrd

wget https://cloud-images.ubuntu.com/xenial/current/xenial-server-cloudimg-amd64.squashfs -O filesystem.squashfs
sudo unsquashfs filesystem.squashfs
echo "useradd ubuntu" | sudo tee squashfs-root/make-changes
echo "usermod --password ubuntu ubuntu" | sudo tee --append squashfs-root/make-changes
echo "adduser ubuntu sudo" | sudo tee --append squashfs-root/make-changes
echo "exit" | sudo tee --append squashfs-root/make-changes
sudo chmod +x squashfs-root/make-changes
sudo chroot squashfs-root/ ./make-changes
sudo mksquashfs squashfs-root /mnt/ceph/fs/containers/provisioner/www/boot/ubuntu/squashfs -b 1024k -comp xz -Xbcj x86 -e boot

#sudo wget https://cloud-images.ubuntu.com/xenial/current/unpacked/xenial-server-cloudimg-amd64-initrd-generic -O /mnt/ceph/fs/containers/provisioner/www/boot/ubuntu/initrd
sudo wget https://cloud-images.ubuntu.com/xenial/current/unpacked/xenial-server-cloudimg-amd64-vmlinuz-generic -O /mnt/ceph/fs/containers/provisioner/www/boot/ubuntu/vmlinuz

sudo chmod -R +r /mnt/ceph/fs/containers/provisioner

sudo docker run -d \
  --name provisioner_lamp --restart=always --net=host \
  -v /mnt/ceph/fs/containers/provisioner/www:/www \
  janes/alpine-lamp
