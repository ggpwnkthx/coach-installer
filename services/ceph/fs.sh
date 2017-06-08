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
sudo wget https://raw.githubusercontent.com/ggpwnkthx/coach/master/services/ceph/client.service -O /etc/systemd/system/ceph-client.service
sudo wget https://raw.githubusercontent.com/ggpwnkthx/coach/master/services/ceph/mnt-ceph-fs.service -O /etc/systemd/system/mnt-ceph-fs.service
sudo systemctl daemon-reload
sudo systemctl enable ceph-client.service
sudo systemctl enable mnt-ceph-fs.service
sudo systemctl start mnt-ceph-fs.service
