#!/bin/bash
clear
printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
echo "COACH - Cluster Of Arbitrary, Cheap, Hardware"
printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
echo "Creating a better initrd file"
printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -

if [ -f initrd ]
then
  sudo rm initrd
fi

## Grab the latest Ubuntu Cloud-Image
if [ -d initrd-root ]
then
  sudo rm -r initrd-root
fi
wget https://cloud-images.ubuntu.com/xenial/current/unpacked/xenial-server-cloudimg-amd64-initrd-generic -O initrd.lzma
unlzma initrd.lzma
mkdir initrd-root
cd initrd-root
cat ../initrd | cpio -id
wget https://raw.githubusercontent.com/ggpwnkthx/coach/master/docker/provisioner/pxe/initramfs.script -O scripts/init-bottom/network
chmod +x scripts/init-bottom/network
echo '/scripts/init-bottom/network "$@"' | tee --append scripts/init-bottom/ORDER
echo '[ -e /conf/param.conf ] && . /conf/param.conf' | tee --append scripts/init-bottom/ORDER
sed -i '/^MODULES=/s/=.*/=netboot/' conf/initramfs.conf
echo "mlx4_core" | tee --append conf/modules
echo "mlx4_ib" | tee --append conf/modules
echo "ib_umad" | tee --append conf/modules
echo "ib_uverbs" | tee --append conf/modules
echo "ib_ipoib" | tee --append conf/modules
ver=$(ls lib/modules/)

cd ..
rm initrd

## Prep for a new initramfs file
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
## Make sure we have the right files
if [ ! -d /lib/modules/$ver/build ]
then
  sudo apt-get -y install linux-headers-$ver
fi
if [ ! -d /lib/modules/$ver/kernel ]
then
  sudo apt-get -y install linux-image-$ver
fi
sudo apt-get -y install linux-image-extra-$ver
## Make the new initramfs with all the modules
sudo mkinitramfs -d initramfs-tools -o initrd $ver
if [ -d initrd-mod ]
then
  sudo rm -r initrd-mod
fi
mkdir initrd-mod
cd initrd-mod
zcat ../initrd | cpio -id
cd ..
sudo rm initrd

## Copy the module data from new initramfs to the official Ubuntu Cloud-Image
cp -r initrd-mod/lib/modules/$ver/kernel/drivers/infiniband initrd-root/lib/modules/$ver/kernel/drivers
diff initrd-root/lib/modules/$ver/modules.dep initrd-mod/lib/modules/$ver/modules.dep | grep "> " | sed 's/> //g' | grep kernel/drivers/infiniband | tee --append initrd-root/lib/modules/*/modules.dep
cp -r initrd-mod/lib/modules/$ver/kernel/drivers/net initrd-root/lib/modules/$ver/kernel/drivers
diff initrd-root/lib/modules/$ver/modules.dep initrd-mod/lib/modules/$ver/modules.dep | grep "> " | sed 's/> //g' | grep kernel/drivers/net | tee --append initrd-root/lib/modules/*/modules.dep
cp -r initrd-mod/lib/modules/$ver/kernel/drivers/ntb initrd-root/lib/modules/$ver/kernel/drivers
diff initrd-root/lib/modules/$ver/modules.dep initrd-mod/lib/modules/$ver/modules.dep | grep "> " | sed 's/> //g' | grep kernel/drivers/ntb | tee --append initrd-root/lib/modules/*/modules.dep

depmod $ver -b initrd-root -E /lib/modules/$ver/build/Module.symvers
cd initrd-root
find . | cpio --create --format='newc' > ../initrd
cd ..

sudo mv initrd /mnt/ceph/fs/containers/provisioner/www/boot/ubuntu/initrd
