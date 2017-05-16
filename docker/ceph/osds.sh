#!/bin/bash
lsblk
read -p "OSD: " device
read -p "Journal (optional): " journal
if [ -z $journal ]
then
  read -p "Use Bluestore? [y,N] " bluestore
fi
read -p "Zap it OSD target ($device)? [y,N] " zap
case $zap in
  y|Y)
    sudo docker run -d --privileged=true -v /dev/:/dev/ -e OSD_DEVICE=/dev/$device ceph/daemon zap_device
esac
case $bluestore in
  y|Y)
    docker run -d --net=host --privileged=true --pid=host -v /etc/ceph:/etc/ceph -v /var/lib/ceph/:/var/lib/ceph/ -v /dev/:/dev/ -e OSD_DEVICE=/dev/$device -e OSD_TYPE=prepare -e OSD_BLUESTORE=1 ceph/daemon osd
    ;;
  *)
    if [ -z $journal ]
    then
      docker run -d --net=host --privileged=true --pid=host -v /etc/ceph:/etc/ceph -v /var/lib/ceph/:/var/lib/ceph/ -v /dev/:/dev/ -e OSD_DEVICE=/dev/$device -e OSD_TYPE=prepare -e ceph/daemon osd
    else
      docker run -d --net=host --privileged=true --pid=host -v /etc/ceph:/etc/ceph -v /var/lib/ceph/:/var/lib/ceph/ -v /dev/:/dev/ -e OSD_DEVICE=/dev/$device -e OSD_JOURNAL=/dev/$journal -e OSD_TYPE=prepare -e ceph/daemon osd
    fi
    ;;
esac
