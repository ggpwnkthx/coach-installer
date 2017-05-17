#!/bin/bash
if [ ! -f ceph_preflight.sh ]
then
  wget https://raw.githubusercontent.com/ggpwnkthx/coach/master/docker/ceph/preflight.sh -O ceph_preflight.sh
fi
chmod +x ceph_preflight.sh
sudo apt-get -y install ceph-common
ceph_mon_ls=($(sudo ceph mon dump | grep mon | awk '{print $3}' | awk '{split($0,a,"."); print a[2]}'))
ceph_mons=""
for i in ${ceph_mon_ls[@]}
do
ping=$(ping $i -c 1 | grep -w PING | awk '{print $3}' | tr -d '()')
if [ "$ping" != "ping: unknown host $i" ]
then
  if [ -z $ceph_mons ]
  then
    ceph_mons="$ping"
  else
    ceph_mons="$ceph_mons,$ping"
  fi
fi
done
if [ ! -f "/mnt" ]
then
  sudo mkdir /mnt
fi
if [ ! -f "/mnt/ceph" ]
then
  sudo mkdir /mnt/ceph
fi
if [ ! -f "/mnt/ceph/fs" ]
then
  sudo mkdir /mnt/ceph/fs
fi
ceph_authenticate $HOSTNAME
secret=$(sudo ceph-authtool -p /etc/ceph/ceph.client.admin.keyring)
sudo mount -t ceph $ceph_mons:/ /mnt/ceph/fs -o name=admin,secret=$secret	
echo "$ceph_mons:/  ceph name=admin,secret=$secret,noatime,_netdev,x-systemd.automount 0 2" | sudo tee --append /etc/fstab
