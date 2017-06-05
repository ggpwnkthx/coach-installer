#!/bin/bash

if [ -z "$(systemctl | grep ceph-mon@$(hostname -s))" ]
then
  ./download_and_run "services/ceph/mon.sh"
fi
./download_and_run "services/ceph/disks.sh"
if [ -z "$(systemctl | grep ceph-mds@$(hostname -s))" ]
then
  ./download_and_run "services/ceph/mds.sh"
fi
if [ -z "$(systemctl | grep mnt-ceph-fs)" ]
then
  /download_and_run "services/ceph/fs.sh"
fi
