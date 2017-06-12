#!/bin/bash
mnt_path=/mnt/ceph/fs

case $1 in
  start)
      if [ -z "$(df -h | grep $mnt_path)" ]
      then
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
        else
          rm -r $mnt_path/*
        fi
        secret=$(ceph-authtool -p /etc/ceph/ceph.client.$name.keyring)
        while [ -z "$(df -h | grep $mnt_path)" ]
        do
          echo "mount -t ceph $ceph_mons:/ $mnt_path -o name=$name,secret=$secret"
          mount -t ceph $ceph_mons:/ $mnt_path -o name=$name,secret=$secret
          sleep 5
        done
        sleep 15
      fi
    ;;
  stop)
    umount $mnt_path
    ;;
  status)
    df -h | grep $mnt_path
    ;;
esac
