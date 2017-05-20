#!/bin/bash
if [ -f /etc/ceph/ceph.conf ]
then
  wget https://raw.githubusercontent.com/ggpwnkthx/coach/master/services/ceph/preflight.sh -O services_ceph_preflight.sh
  chmod +x services_ceph_preflight.sh
  ./services_ceph_preflight.sh
  sudo apt-get -y install ceph-common
fi

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
if [ ! -z "$(systemctl | grep ceph_client.service)" ]
then
  sudo systemctl disable ceph_client.service
fi
sudo wget https://raw.githubusercontent.com/ggpwnkthx/coach/master/docker/ceph/client.service -O /etc/systemd/system/ceph_client.service
sudo systemctl daemon-reload
sudo systemctl enable ceph_client.service
secret=$(sudo ceph-authtool -p /etc/ceph/ceph.client.admin.keyring)
if [ ! -z "$(systemctl | grep mnt-ceph-fs.mount)" ]
then
  sudo systemctl stop mnt-ceph-fs.mount
  sudo systemctl disable mnt-ceph-fs.mount
fi
sudo rm /etc/systemd/system/mnt-ceph-fs.mount
echo "[Unit]" | sudo tee /etc/systemd/system/mnt-ceph-fs.mount
echo "Description=Mount CephFS" | sudo tee --append /etc/systemd/system/mnt-ceph-fs.mount
echo "After=ceph_client.service" | sudo tee --append /etc/systemd/system/mnt-ceph-fs.mount
echo "" | sudo tee --append /etc/systemd/system/mnt-ceph-fs.mount
echo "[Mount]" | sudo tee --append /etc/systemd/system/mnt-ceph-fs.mount
echo "What=$ceph_mons:/" | sudo tee --append /etc/systemd/system/mnt-ceph-fs.mount
echo "Where=/mnt/ceph/fs" | sudo tee --append /etc/systemd/system/mnt-ceph-fs.mount
echo "Type=ceph" | sudo tee --append /etc/systemd/system/mnt-ceph-fs.mount
echo "Options=name=admin,secret=$secret" | sudo tee --append /etc/systemd/system/mnt-ceph-fs.mount
echo "" | sudo tee --append /etc/systemd/system/mnt-ceph-fs.mount
echo "[Install]" | sudo tee --append /etc/systemd/system/mnt-ceph-fs.mount
echo "WantedBy=multi-user.target" | sudo tee --append /etc/systemd/system/mnt-ceph-fs.mount
echo "sudo systemctl daemon-reload
echo "sudo systemctl enable mnt-ceph-fs.mount
echo "sudo systemctl start mnt-ceph-fs.mount
