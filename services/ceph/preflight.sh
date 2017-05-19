#!/bin/bash
if [ ! -z $1 ]
then
  hostname=$1
fi
if [ ! -f /etc/ceph/ceph.conf ]
then
  echo
  echo "Copy ceph configuration from remote host..."
  if [ -z $hostname ]
  then
    read -p "Hostname: " hostname
  fi
  scp_user=$(cat ~/.ssh/config | grep -A 2 $hostname | grep User | awk '{print $2}')
  scp_found=1
  if [ -z "$scp_user" ]
  then
    read -p "Username: " scp_user
    scp_found=0
  fi
  if [ -f ~/.ssh/id_rsa ]
  then
    echo ''
    echo "SSH keys are already created."
  else
    echo "Creating SSH keys..."
    ssh-keygen
  fi
  if [ -z "$(ssh-keygen -F $hostname)" ]
  then
    echo "Copying new public key from $hostname..."
    ssh-copy-id $scp_user@$hostname
    if [ $scp_found == 0 ]
    then
      echo "Host $hostname" >> ~/.ssh/config
      echo "	Hostname $hostname" >> ~/.ssh/config
      echo "	User $scp_user" >> ~/.ssh/config
    fi
  fi
  mkdir -p ~/ceph/etc
  scp -r $scp_user@$hostname:/etc/ceph ~/ceph/etc
  sudo cp -a ~/ceph/etc/ceph /etc
  sudo chmod +r /etc/ceph
  sudo chmod +r /etc/ceph/*
  mkdir -p ~/ceph/var/lib/ceph
  scp -r $scp_user@$hostname:/var/lib/ceph/bootstrap-mds ~/ceph/var/lib/ceph
  scp -r $scp_user@$hostname:/var/lib/ceph/bootstrap-rgw ~/ceph/var/lib/ceph
  scp -r $scp_user@$hostname:/var/lib/ceph/bootstrap-osd ~/ceph/var/lib/ceph
  sudo mkdir /var/lib/ceph
  sudo cp -r ~/ceph/var/lib/ceph/bootstrap-mds /var/lib/ceph
  sudo cp -r ~/ceph/var/lib/ceph/bootstrap-rgw /var/lib/ceph
  sudo cp -r ~/ceph/var/lib/ceph/bootstrap-osd /var/lib/ceph
  sudo chmod +r /var/lib/ceph
  sudo chmod +r /var/lib/ceph/*
  sudo chmod +r /var/lib/ceph/*/*
  rm -r ~/ceph
fi
