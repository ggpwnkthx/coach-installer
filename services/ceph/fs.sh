#!/bin/bash
if [ -z "$(command -c ceph)" ]
then
  sudo apt-get -y install ceph-common
fi
if [ ! -f /etc/ceph/ceph.conf ]
then
  ./download_and_run "services/ceph/preflight.sh"
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
if [ ! -z "$(systemctl | grep ceph-client.service)" ]
then
  sudo systemctl disable ceph-client.service
fi
sudo wget https://raw.githubusercontent.com/ggpwnkthx/coach/master/services/ceph/client.service -O /etc/systemd/system/ceph-client.service
sudo systemctl daemon-reload
sudo systemctl enable ceph-client.service
secret=$(sudo ceph-authtool -p /etc/ceph/ceph.client.admin.keyring)
if [ ! -z "$(systemctl | grep mnt-ceph-fs.mount)" ]
then
  sudo systemctl stop mnt-ceph-fs.mount
  sudo systemctl disable mnt-ceph-fs.mount
fi
sudo rm /etc/systemd/system/mnt-ceph-fs.mount
echo "[Unit]" | sudo tee /etc/systemd/system/mnt-ceph-fs.mount
echo "Description=Mount CephFS" | sudo tee --append /etc/systemd/system/mnt-ceph-fs.mount
echo "After=ceph-client.service" | sudo tee --append /etc/systemd/system/mnt-ceph-fs.mount
echo "" | sudo tee --append /etc/systemd/system/mnt-ceph-fs.mount
echo "[Mount]" | sudo tee --append /etc/systemd/system/mnt-ceph-fs.mount
echo "What=$ceph_mons:/" | sudo tee --append /etc/systemd/system/mnt-ceph-fs.mount
echo "Where=/mnt/ceph/fs" | sudo tee --append /etc/systemd/system/mnt-ceph-fs.mount
echo "Type=ceph" | sudo tee --append /etc/systemd/system/mnt-ceph-fs.mount
echo "Options=name=admin,secret=$secret" | sudo tee --append /etc/systemd/system/mnt-ceph-fs.mount
echo "" | sudo tee --append /etc/systemd/system/mnt-ceph-fs.mount
echo "[Install]" | sudo tee --append /etc/systemd/system/mnt-ceph-fs.mount
echo "WantedBy=multi-user.target" | sudo tee --append /etc/systemd/system/mnt-ceph-fs.mount

sudo rm /etc/systemd/system/mnt-ceph-fs.service
echo "[Unit]" | sudo tee /etc/systemd/system/mnt-ceph-fs.service
echo "Description=Mount CephFS Service" | sudo tee --append /etc/systemd/system/mnt-ceph-fs.service
echo "After=ceph-client.service" | sudo tee --append /etc/systemd/system/mnt-ceph-fs.service
echo "[Service]" | sudo tee --append /etc/systemd/system/mnt-ceph-fs.service
echo "Type=simple" | sudo tee --append /etc/systemd/system/mnt-ceph-fs.service
echo "ExecStartPre=/bin/systemctl start mnt-ceph-fs.mount" | sudo tee --append /etc/systemd/system/mnt-ceph-fs.service
echo "ExecStop=/bin/systemctl stop mnt-ceph-fs.mount" | sudo tee --append /etc/systemd/system/mnt-ceph-fs.service
echo "ExecStart=/bin/sleep 10000000d" | sudo tee --append /etc/systemd/system/mnt-ceph-fs.service
echo "Restart=always" | sudo tee --append /etc/systemd/system/mnt-ceph-fs.service
echo "RestartSec=" | sudo tee --append /etc/systemd/system/mnt-ceph-fs.service

sudo systemctl daemon-reload
sudo systemctl enable mnt-ceph-fs.mount
#sudo systemctl start mnt-ceph-fs.mount
sudo systemctl enable mnt-ceph-fs.service
sudo systemctl start mnt-ceph-fs.service
