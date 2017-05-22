#!/bin/bash
if [ -z $1 ]
then
  ceph_mons=($cat /var/lib/dhcp/* | grep "option ceph-mons" | awk '{print $3}')
  ceph_mons="${ceph_mons::-1}"
  ceph_mons=echo "$ceph_mons" | tr -d '"'
  if [ ! -z $ceph_mons ]
  then
    IFS=',' read -r -a ceph_mon_ips <<< "$ceph_mons"
    for ip in ${ceph_mon_ips[@]}
    do
      ip=$(echo $ip | awk '{split($0,a":"); print a[1]}')
      if [ $(ping $ip -c 3 | grep received | awk '{print $4}') -gt 1 ]
      then
        hostname=$ip
      fi
    done
  fi
else
  hostname=$1
fi

if [ !-z "$(ipcalc $hostname | grep INVALID)" ]
then
  if [ -z "$(command -v host)" ]
  then
    sudo apt-get -y install host
    hostname=$(host $hostname | awk '{print $5}' | awk '{split($0,a,'.'); print a[1]}'
  fi
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
