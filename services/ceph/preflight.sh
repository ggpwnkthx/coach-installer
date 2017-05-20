#!/bin/bash
if [ ! -z $1 ]
then
  hostname=$1
fi
if [ ! -f /etc/ceph/ceph.conf ]
then
  echo "Copy ceph configuration from remote host..."
  
  wget https://raw.githubusercontent.com/ggpwnkthx/coach/master/services/ssh/passwordless.sh -O services_ssh_passwordless.sh
  chmod +x services_ssh_passwordless.sh
  ./services_ssh_passwordless.sh $hostname
  
  mkdir -p ~/ceph/etc
  scp -r $hostname:/etc/ceph ~/ceph/etc
  sudo cp -a ~/ceph/etc/ceph /etc
  sudo chmod +r /etc/ceph
  sudo chmod +r /etc/ceph/*
  mkdir -p ~/ceph/var/lib/ceph
  scp -r $hostname:/var/lib/ceph/bootstrap-mds ~/ceph/var/lib/ceph
  scp -r $hostname:/var/lib/ceph/bootstrap-rgw ~/ceph/var/lib/ceph
  scp -r $hostname:/var/lib/ceph/bootstrap-osd ~/ceph/var/lib/ceph
  sudo mkdir /var/lib/ceph
  sudo cp -r ~/ceph/var/lib/ceph/bootstrap-mds /var/lib/ceph
  sudo cp -r ~/ceph/var/lib/ceph/bootstrap-rgw /var/lib/ceph
  sudo cp -r ~/ceph/var/lib/ceph/bootstrap-osd /var/lib/ceph
  sudo chmod +r /var/lib/ceph
  sudo chmod +r /var/lib/ceph/*
  sudo chmod +r /var/lib/ceph/*/*
  rm -r ~/ceph
fi
