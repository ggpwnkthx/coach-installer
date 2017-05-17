#!/bin/bash
if [ ! -f ceph_preflight.sh ]
then
  wget https://raw.githubusercontent.com/ggpwnkthx/coach/master/docker/ceph/preflight.sh -O ceph_preflight.sh
fi
chmod +x ceph_preflight.sh
./ceph_preflight.sh
sudo apt-get -y install ceph-common
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
if [ ! -d "/mnt" ]
then
  sudo mkdir /mnt
fi
if [ ! -d "/mnt/ceph" ]
then
  sudo mkdir /mnt/ceph
fi
if [ ! -d "/mnt/ceph/fs" ]
then
  sudo mkdir /mnt/ceph/fs
fi
secret=$(sudo ceph-authtool -p /etc/ceph/ceph.client.admin.keyring)
if [ -z "$(df -h | grep /mnt/ceph/fs)" ]
then
  sudo mount -t ceph $ceph_mons:/ /mnt/ceph/fs -o name=admin,secret=$secret
fi
fstab="$ceph_mons:/ /mnt/ceph/fs ceph name=admin,secret=$secret,noatime,_netdev,x-systemd.automount 0 2"
if [ -z "$(cat /etc/fstab | grep /mnt/ceph/fs)" ]
then
  echo $fstab | sudo tee --append /etc/fstab
fi