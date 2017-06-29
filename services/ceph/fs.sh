#!/bin/bash
if [ -z "$(command -c ceph)" ]
then
  apt-get -y install ceph-common
fi
if [ ! -f /etc/ceph/ceph.conf ]
then
  ./download_and_run "services/ceph/preflight.sh"
fi

wget https://raw.githubusercontent.com/ggpwnkthx/coach/master/services/ceph/ceph-client.service -O /etc/systemd/system/ceph-client.service
wget https://raw.githubusercontent.com/ggpwnkthx/coach/master/services/ceph/mnt-ceph-fs.service -O /etc/systemd/system/mnt-ceph-fs.service
wget https://raw.githubusercontent.com/ggpwnkthx/coach/master/services/ceph/mnt-ceph-fs.sh -O /etc/ceph/mnt-ceph-fs.sh
chmod +x /etc/ceph/mnt-ceph-fs.sh

systemctl daemon-reload

systemctl stop ceph-client.service
systemctl enable ceph-client.service
systemctl start ceph-client.service

systemctl stop mnt-ceph-fs.service
systemctl enable mnt-ceph-fs.service
systemctl start mnt-ceph-fs.service

systemctl stop mnt-ceph-fs.mount
systemctl enable mnt-ceph-fs.mount
systemctl start mnt-ceph-fs.mount
