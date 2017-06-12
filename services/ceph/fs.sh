#!/bin/bash
if [ -z "$(command -c ceph)" ]
then
  sudo apt-get -y install ceph-common
fi
if [ ! -f /etc/ceph/ceph.conf ]
then
  ./download_and_run "services/ceph/preflight.sh"
fi

if [ ! -z "$(systemctl | grep ceph-client.service)" ]
then
  sudo systemctl disable ceph-client.service
fi
sudo wget https://raw.githubusercontent.com/ggpwnkthx/coach/master/services/ceph/ceph-client.service -O /etc/systemd/system/ceph-client.service

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

sudo systemctl daemon-reload
sudo systemctl enable ceph-client.service
sudo systemctl start ceph-client.service
sudo systemctl enable mnt-ceph-fs.mount
sudo systemctl start mnt-ceph-fs.mount
