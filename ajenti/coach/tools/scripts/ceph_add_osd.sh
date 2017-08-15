#!/bin/bash

if [ -z $1 ]
then
  echo "No device specified."
  echo "USAGE: ./osd.sh osd-path [journal-path]"
  echo "EXAMPLE: ./osd.sh /dev/sdm"
  echo "EXAMPLE: ./osd.sh /dev/sdm /dev/sdo"
  exit
fi
if [ -z "$(command -v ceph-deploy)" ]
then
  echo "ceph-deploy is not installed on this node"
  exit
fi
if [ -z "$(command -v gdisk)" ]
then
  apt-get -y install gdisk 
fi
if [ -z "$(command -v mkfs.btrfs)" ]
then
  apt-get -y install btrfs-tools
fi

if [ ! -f ceph.bootstrap-osd.keyring ]
then
  ceph-deploy gatherkeys $(hostname -s)
fi

sgdisk -z $1
if [ ! -z "$2" ]
then
  parts=($(lsblk -p -l -o kname | grep -e $2"[0-9]"))
  if [ ${#parts[@]} -eq 0 ]
  then
    sgdisk -z $2
  else
    if [ ! -z "$(sgdisk $2 -p | grep 'ceph journal')" ]
    then
      echo "There are existing, active, journals on the seleced journalling device."
      echo "No changes will be made to the partitioning."
    else
      sgdisk -z $2
    fi
  fi
  echo "Creating OSD with separate Journal device..."
  ceph-deploy osd prepare --fs-type btrfs $(hostname -s):$1:$2
else
  echo "Creating OSD..."
  ceph-deploy osd prepare --fs-type btrfs $(hostname -s):$1
fi
echo "OSD has been created for device $1"