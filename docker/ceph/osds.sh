#!/bin/bash
zap()
{
  sudo docker run -d --privileged=true -v /dev/:/dev/ -e OSD_DEVICE=/dev/$1 --name=ceph_temp ceph/daemon zap_device
  while [ ! -z "$(sudo docker ps | grep ceph_temp)" ]
  do
    sleep 1
  done
  sudo docker rm ceph_temp
}

if [ -z $1 ]
then
  lsblk
  read -p "OSD: " device
  read -p "Zap it OSD target (/dev/$device)? [y,N] " zap
  case $zap in
    y|Y)
      zap $device
  esac
  read -p "Journal (optional): " journal
else
  device=$1
  zap $device
  if [ ! -z $2 ]
  then
    if [ "$2" -eq "bluestore" ]
    then
      bluestore=y
    else
      journal=$2
    fi
  fi
fi
if [ -z $journal ]
then
  if [ -z $bluestore ]
  then
    if [ -z $1 ]
    then
      read -p "Use Bluestore? [y,N] " bluestore
    fi
  fi
  case $bluestore in
    y|Y)
      sudo docker run -d --restart=always --net=host --privileged=true --pid=host -v /etc/ceph:/etc/ceph -v /var/lib/ceph/:/var/lib/ceph/ -v /dev/:/dev/ -e OSD_DEVICE=/dev/$device -e OSD_TYPE=disk -e OSD_BLUESTORE=1 ceph/daemon osd
      ;;
    *)
    sudo docker run -d --restart=always --net=host --privileged=true --pid=host -v /etc/ceph:/etc/ceph -v /var/lib/ceph/:/var/lib/ceph/ -v /dev/:/dev/ -e OSD_DEVICE=/dev/$device -e OSD_TYPE=disk ceph/daemon osd
    ;;
  esac
else
  sudo docker run -d --restart=always --net=host --privileged=true --pid=host -v /etc/ceph:/etc/ceph -v /var/lib/ceph/:/var/lib/ceph/ -v /dev/:/dev/ -e OSD_DEVICE=/dev/$device -e OSD_JOURNAL=/dev/$journal -e OSD_TYPE=disk ceph/daemon osd
fi
part=1
while [ -z "$(lsblk | grep $device$part)" ]
do
  sleep 1
done
