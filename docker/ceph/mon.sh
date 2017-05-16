#!/bin/bash
if [ -z "$(sudo docker ps -a | grep ceph_mon)" ]
then
  if [ ! -f /etc/ceph/ceph.conf ]
  then
    sudo apt-get -y install ipcalc
    read -n1 -p "Is this the first node? [Y,n]" first
    case $first in
      n|N)
        echo
        echo "Copy ceph configuration from remote host:"
        read -p "Hostname: " hostname
        read -p "Username: " username
        sudo scp -r $username@$hostname:/etc/ceph /etc
    esac
  fi
  echo
  ifconfig | awk -v RS="\n\n" '{ for (i=1; i<=NF; i++) if ($i == "inet" && $(i+1) ~ /^addr:/) address = substr($(i+1), 6); if (address != "127.0.0.1") printf "%s\t%s\n", $1, address }'
  echo "Which IP address should be used for the ceph monitor?"
  read -p "IP: " ip
  sudo docker run -d --net=host -v /etc/ceph:/etc/ceph -v /var/lib/ceph/:/var/lib/ceph/ -e MON_IP=$ip -e CEPH_PUBLIC_NETWORK=$(ipcalc $ip -n | grep Network | awk '{print $2}') --name=ceph_mon --restart=always ceph/daemon mon
  while [ ! -f /etc/ceph/ceph.mon.keyring ]
  do
    sleep 1
  done
  sudo chmod +r /etc/ceph
  sudo chmod +r /etc/ceph/*
  sudo chmod +r /var/lib/ceph/bootstrap-mds/ceph.keyring
  sudo chmod +r /var/lib/ceph/bootstrap-rgw/ceph.keyring
  sudo chmod +r /var/lib/ceph/bootstrap-osd/ceph.keyring
else
  if [ -z "$(sudo docker ps | grep ceph_mon)" ]
  then
    sudo docker start ceph_mon
  fi
fi
