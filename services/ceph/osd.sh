#!/bin/bash
ce ~/ceph

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

sudo apt-get -y install gdisk

parts=($(lsblk -p -l -o kname | grep -e $1"[0-9]"))
if [ ${#parts[@]} -eq 0 ]
then
  echo "No partitions found on the selected storage device."
  echo "Zaping device to assure proper installation."
  sudo sgdisk -z $1
else
  echo "Partitions were found on the selected storage device."
  read -n1 -p "Do you want to zap it to assure proper installation? [y,n]" doit
  case $doit in
    y|Y) echo '' && sudo sgdisk -z $1 ;;
    *) echo '' && echo 'Partitions will not be changed.' ;;
  esac
fi
if [ ! -z "$2" ]
then
  parts=($(lsblk -p -l -o kname | grep -e $2"[0-9]"))
  if [ ${#parts[@]} -eq 0 ]
  then
    echo "No partitions found on the selected journal device."
    echo "Zapping device to assure proper installation."
    sudo sgdisk -z $2
  else
    if [ ! -z "$(sudo sgdisk $2 -p | grep 'ceph journal')" ]
    then
      echo "There are existing, active, journals on the seleced journalling device."
      echo "No changes will be made to the partitioning."
    else
      echo ''
      echo 'There are existing partitions on the journal device,'
      echo "but there are no active journals set up on it."
      read -n1 -p "Do you want to zap it to assure proper installation? [y,n]" doit
      case $doit in
        y|Y) echo '' && sudo sgdisk -z $2 ;;
        *) echo '' && echo 'Partitions will not be changed.' ;;
      esac
    fi
  fi
  echo "Creating OSD with separate Journal device..."
  ceph-deploy osd prepare --fs-type btrfs $HOSTNAME:$1:$2
else
  echo "Creating OSD..."
  ceph-deploy osd prepare --fs-type btrfs $HOSTNAME:$1
fi
echo "OSD has been created for device $1"
