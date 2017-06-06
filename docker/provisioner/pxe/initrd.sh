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
mkinitramfs -d initramfs-tools -o initrd

if [ -d initrd-mod ]
then
  sudo rm -r initrd-mod
fi
mkdir initrd-mod

cd initrd-mod
zcat ../initrd | cpio -id
cd ..
rm initrd

if [ -d initrd-root ]
then
  sudo rm -r initrd-root
fi

wget https://cloud-images.ubuntu.com/xenial/current/unpacked/xenial-server-cloudimg-amd64-initrd-generic -O initrd.lzma
unlzma initrd.lzma
mkdir initrd-root
cd initrd-root
cat ../initrd | cpio -id

sed -i '/^MODULES=/s/=.*/=netboot/' conf/initramfs.conf
echo "mlx4_core" | tee --append conf/modules
echo "mlx4_ib" | tee --append conf/modules
echo "ib_umad" | tee --append conf/modules
echo "ib_uverbs" | tee --append conf/modules
echo "ib_ipoib" | tee --append conf/modules
#cp -r ../initrd-mod/lib/modules lib/
cp -r ../initrd-mod/lib/modules/4.4.0-78-generic/kernel/drivers lib/modules/4.4.0-78-generic/kernel/
cp ../initrd-mod/lib/modules/4.4.0-78-generic/modules.dep lib/modules/4.4.0-78-generic/
diff lib/modules/4.4.0-78-generic/modules.dep ../initrd-mod/lib/modules/4.4.0-78-generic/modules.dep | grep "> " | sed 's/> //g' | tee --append lib/modules/4.4.0-78-generic/modules.dep
cd ..
depmod -b initrd-root
cd initrd-root

find . | cpio --create --format='newc' > ../initrd
cd ..

sudo mv initrd /mnt/ceph/fs/containers/provisioner/www/boot/ubuntu/initrd
