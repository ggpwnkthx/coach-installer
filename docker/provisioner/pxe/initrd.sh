#!/bin/bash
clear
printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
echo "COACH - Cluster Of Arbitrary, Cheap, Hardware"
printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
echo "Creating a better initrd file"
printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -

if [ -d initrd-root ]
then
  sudo rm -r initrd-root
fi
mkdir initrd-root

wget https://cloud-images.ubuntu.com/xenial/current/unpacked/xenial-server-cloudimg-amd64-initrd-generic -O initrd.lzma
unlzma initrd.lzma
cd initrd-root
cat ../initrd | cpio -id

sed -i '/^MODULES=/s/=.*/=netboot/' conf/initramfs.conf
echo "mlx4_core" | tee --append conf/modules
echo "mlx4_ib" | tee --append conf/modules
echo "ib_umad" | tee --append conf/modules
echo "ib_uverbs" | tee --append conf/modules
echo "ib_ipoib" | tee --append conf/modules
wget https://raw.githubusercontent.com/ggpwnkthx/coach/master/docker/provisioner/pxe/initramfs.script -O scripts/init-bottom/network
chmod +x scripts/init-bottom/network

find . | cpio --create --format='newc' > ../initrd
cd ..

sudo mv initrd /mnt/ceph/fs/containers/provisioner/www/boot/ubuntu/initrd
