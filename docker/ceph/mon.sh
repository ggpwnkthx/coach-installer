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
        echo "Copy ceph configuration from remote host..."
        read -p "Hostname: " hostname
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
          echo -e "\n\n\n" | ssh-keygen
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
        sudo scp -r $scp_user@$hostname:/etc/ceph /etc
        sudo chmod +r /etc/ceph
        sudo chmod +r /etc/ceph/*
        sudo scp -r $scp_user@$hostname:/var/lib/ceph/bootstrap-mds /var/lib/ceph
        sudo scp -r $scp_user@$hostname:/var/lib/ceph/bootstrap-rgw /var/lib/ceph
        sudo scp -r $scp_user@$hostname:/var/lib/ceph/bootstrap-osd /var/lib/ceph
        sudo chmod +r /var/lib/ceph/bootstrap-*/*
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
  sudo chmod +r /var/lib/ceph/bootstrap-*/*
else
  if [ -z "$(sudo docker ps | grep ceph_mon)" ]
  then
    sudo docker start ceph_mon
  fi
fi
