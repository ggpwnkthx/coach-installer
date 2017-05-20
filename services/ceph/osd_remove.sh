#!/bin/bash
if [ -z $1 }
then
  echo "No OSD # specified."
  "USAGE: ./osd_remove.sh 123"
  exit
"
hostname="$(ceph osd find $1 | awk -F\" '$2 ~ /host/ {print $4}')"
ssh -t $hostname "sudo systemctl stop ceph-osd@$1"
ssh -t $hostname "sudo umount /var/lib/ceph/osd/ceph-$1"
ceph osd out $1 
ceph osd crush remove osd.$1
ceph auth del osd.$1
ceph osd rm $1
