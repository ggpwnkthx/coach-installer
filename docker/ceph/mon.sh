#!/bin/bash
if [ ! -f /etc/ceph/ceph.conf ]
then
  sudo apt-get -y install ipcalc
  read -n1 -p "Is this the first node? [Y,n]" first
  case in first
    n,N)
     echo "Copy ceph configuration from remote host:"
     read -p "Hostname: " hostname
     read -p "Username: " username
     sudo scp -r $username@$hostname:/etc/ceph /etc
  esac
  echo
  echo "Which IP address should be used for the ceph monitor?"
  ifconfig | awk -v RS="\n\n" '{ for (i=1; i<=NF; i++) if ($i == "inet" && $(i+1) ~ /^addr:/) address = substr($(i+1), 6); if (address != "127.0.0.1") printf "%s\t%s\n", $1, address }'
  read -p "IP: " ip
  sudo docker run -d --net=host -v /etc/ceph:/etc/ceph -v /var/lib/ceph/:/var/lib/ceph/ -e MON_IP=$ip -e CEPH_PUBLIC_NETWORK=$(ipcalc $ip -n | grep Network | awk '{print $2}') ceph/daemon mon
  sleep 10
  sudo chmod 777 /etc/ceph
  sudo chmod 777 /etc/ceph/*
else
  echo "Which IP address should be used for the ceph monitor?"
  ifconfig | awk -v RS="\n\n" '{ for (i=1; i<=NF; i++) if ($i == "inet" && $(i+1) ~ /^addr:/) address = substr($(i+1), 6); if (address != "127.0.0.1") printf "%s\t%s\n", $1, address }'
  read -p "IP: " ip
  sudo docker run -d --net=host -v /etc/ceph:/etc/ceph -v /var/lib/ceph/:/var/lib/ceph/ -e MON_IP=$ip -e CEPH_PUBLIC_NETWORK=$(ipcalc $ip -n | grep Network | awk '{print $2}') ceph/daemon mon
fi
