#!/bin/bash
clear
printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
echo "COACH - Cluster Of Arbitrary, Cheap, Hardware"
printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
echo "Creating a better initrd file"
printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -

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

if [ -d initrd-root ]
then
  sudo rm -r initrd-root
fi
mkdir initrd-root
cd initrd-root
zcat ../initrd | cpio -id
cp /usr/bin/unsquashfs bin/
cp /lib/x86_64-linux-gnu/libm.so.6 lib/x86_64-linux-gnu/
cp /lib/x86_64-linux-gnu/liblzma.so.5 lib/x86_64-linux-gnu/
cp /usr/lib/x86_64-linux-gnu/liblz4.so.1 lib/x86_64-linux-gnu/

find . | cpio --create --format='newc' > ../initrd
cd ..

sudo mv initrd /mnt/ceph/fs/containers/provisioner/www/boot/ubuntu/initrd
