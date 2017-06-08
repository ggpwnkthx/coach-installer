#!/bin/bash
mnt_path=/mnt/ceph/fs

case $1 in
  start)
    name=admin
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
    if [ ! -d $mnt_path ]
    then
      mkdir -p $mnt_path
    fi
    secret=$(ceph-authtool -p /etc/ceph/ceph.client.admin.keyring)
    while [ -z "$(df -h | grep $mnt_path)" ]
    do
      mount -t ceph $ceph_mons:/ $mnt_path -o name=$name,secret=$secret
    done
    ;;
  stop)
    umount $mnt_path
    ;;
  status)
    df -h | grep $mnt_path
    ;;
esac
