#!/bin/bash
if [ -z $1 ]
then
  echo "No OSD # specified."
  echo "USAGE: ./osd_remove.sh 123"
  exit
fi
hn="$(ceph osd find $1 | awk -F\" '$2 ~ /host/ {print $4}')"
if [ ! -z $hostname ]
then
  if [ $hn == $(hostname -s) ]
  then
    sudo systemctl stop ceph-osd@$1
    sudo umount /var/lib/ceph/osd/ceph-$1
    sudo rm -r /var/lib/ceph/osd/ceph-$1
  else
    ssh -t $hn "sudo systemctl stop ceph-osd@$1"
    ssh -t $hn "sudo umount /var/lib/ceph/osd/ceph-$1"
    ssh -t $hn "sudo rm -r /var/lib/ceph/osd/ceph-$1"
  fi
  ceph osd out $1
  ceph osd crush remove osd.$1
  ceph auth del osd.$1
  ceph osd rm $1
fi
