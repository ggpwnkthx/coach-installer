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
#wget https://cloud-images.ubuntu.com/xenial/current/xenial-server-cloudimg-amd64.squashfs -O filesystem.squashfs
#sudo unsquashfs filesystem.squashfs
if [ ! -f ubuntu-mini-remix-16.04-amd64.iso ]
then
  wget http://ubuntu-mini-remix.mirror.garr.it/mirrors/ubuntu-mini-remix/16.04/ubuntu-mini-remix-16.04-amd64.iso -O ubuntu-mini-remix-16.04-amd64.iso
fi
if [ -d remix ]
then
  sudo umount remix
fi
sudo mount ubuntu-mini-remix-16.04-amd64.iso remix -t iso9660 -o loop
sudo unsquashfs remix/casper/filesystem.squashfs

ceph_mon_ls=($(sudo ceph mon dump | grep mon | awk '{print $2}' | awk '{split($0,a,"/"); print a[1]}'))
ceph_mons=""
for i in ${ceph_mon_ls[@]}
do
  if [ -z $ceph_mons ]
  then
    ceph_mons="$i"
  else
    ceph_mons="$ceph_mons,$i"
  fi
done
sudo mkdir -p squashfs-root/mnt/ceph/fs
sudo wget https://raw.githubusercontent.com/ggpwnkthx/coach/master/services/ceph/client.service -O squashfs-root/etc/systemd/system/ceph-client.service
secret=$(sudo ceph-authtool -p /etc/ceph/ceph.client.admin.keyring)
echo "[Unit]" | sudo tee squashfs-root/etc/systemd/system/mnt-ceph-fs.mount
echo "Description=Mount CephFS" | sudo tee --append squashfs-root/etc/systemd/system/mnt-ceph-fs.mount
echo "After=ceph-client.service" | sudo tee --append squashfs-root/etc/systemd/system/mnt-ceph-fs.mount
echo "" | sudo tee --append squashfs-root/etc/systemd/system/mnt-ceph-fs.mount
echo "[Mount]" | sudo tee --append squashfs-root/etc/systemd/system/mnt-ceph-fs.mount
echo "What=$ceph_mons:/" | sudo tee --append squashfs-root/etc/systemd/system/mnt-ceph-fs.mount
echo "Where=/mnt/ceph/fs" | sudo tee --append squashfs-root/etc/systemd/system/mnt-ceph-fs.mount
echo "Type=ceph" | sudo tee --append squashfs-root/etc/systemd/system/mnt-ceph-fs.mount
echo "Options=name=admin,secret=$secret" | sudo tee --append squashfs-root/etc/systemd/system/mnt-ceph-fs.mount
echo "" | sudo tee --append squashfs-root/etc/systemd/system/mnt-ceph-fs.mount
echo "[Install]" | sudo tee --append squashfs-root/etc/systemd/system/mnt-ceph-fs.mount
echo "WantedBy=multi-user.target" | sudo tee --append squashfs-root/etc/systemd/system/mnt-ceph-fs.mount

sudo wget https://raw.githubusercontent.com/ggpwnkthx/coach/master/docker/provisioner/pxe/chroot.changes -O squashfs-root/make-changes
sudo chmod +x squashfs-root/make-changes
sudo mv squashfs-root/etc/resolv.conf squashfs-root/etc/resolv.conf.old
sudo cp /etc/resolv.conf squashfs-root/etc/resolv.conf
binders=(/dev /tmp /proc)
for bind in ${binders[@]}
do
  sudo mount --bind $bind squashfs-root$bind
done

sudo mkdir -p squashfs-root/etc/ceph
sudo cp /etc/ceph/ceph.conf squashfs-root/etc/ceph/
sudo chmod +r squashfs-root/etc/ceph/ceph.conf
sudo cp /etc/ceph/ceph.client.admin.keyring squashfs-root/etc/ceph/
sudo chmod +r squashfs-root/etc/ceph/ceph.client.admin.keyring

sudo chroot squashfs-root/ ./make-changes
for bind in ${binders[@]}
do
  sudo umount squashfs-root$bind
done
sudo rm squashfs-root/etc/resolv.conf
sudo mv squashfs-root/etc/resolv.conf.old squashfs-root/etc/resolv.conf

if [ -f /mnt/ceph/fs/containers/provisioner/www/boot/ubuntu/squashfs ]
then
  sudo rm /mnt/ceph/fs/containers/provisioner/www/boot/ubuntu/squashfs
fi
sudo mksquashfs squashfs-root /mnt/ceph/fs/containers/provisioner/www/boot/ubuntu/squashfs -b 1024k -comp xz -Xbcj x86 -e boot
