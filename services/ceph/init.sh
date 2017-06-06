#!/bin/bash
rtb=$(pwd)

if [ -z "$(command -v ifconfig)" ]
then
  sudo apt-get -y install net-tools
fi
if [ -z "$(command -v ipcalc)" ]
then
  sudo apt-get -y install ipcalc
fi
if [ -z "$(command -v ceph-deploy)" ]
then
  sudo apt-get -y install ceph-deploy
fi
if [ -z "$(command -v sgdisk)" ]
then
  sudo apt-get -y install gdisk
fi

./download_and_run "services/ceph/purge.sh"
if [ -f /etc/network/interfaces.d/storage ]
then
  addr=$(cat /etc/network/interfaces.d/storage | grep address | awk '{print $2}')
  mask=$(cat /etc/network/interfaces.d/storage | grep netmaks | awk '{print $2}')
else
  if [ -z $1 ]
  then
    clear
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
    echo "COACH - Cluster Of Arbitrary, Cheap, Hardware"
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
    echo "Ceph Initialization - $HOSTNAME"
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
    ifconfig | awk -v RS="\n\n" '{ for (i=1; i<=NF; i++) if ($i == "inet" && $(i+1) ~ /^addr:/) address = substr($(i+1), 6); if (address != "127.0.0.1") printf "%s\t%s\n", $1, address }'
    read -p "Which adapter should be used for the ceph cluster? " nic
  else
    nic=$1
  fi
  addr=$(ifconfig $nic | grep Mask | awk '{print $2}' | awk '{split($0,a,":"); print a[2]}')
  mask=$(ifconfig $nic | grep Mask | awk '{print $4}' | awk '{split($0,a,":"); print a[2]}')
fi
net=$(ipcalc -n $addr $mask | grep Network | awk '{print $2}')

./download_and_run "hardware/networking/hosts.sh" $addr $HOSTNAME

if [ ! -d ~/ceph ]
then
  mkdir ~/ceph
fi
cd ~/ceph
ceph-deploy new $HOSTNAME
echo "osd pool default size = 2" >> ceph.conf
echo "public network = $net" >> ceph.conf
if [ ! -z $2 ]
then
  echo "osd_journal_size = $2" >> ceph.conf
fi
ceph-deploy install $HOSTNAME
sudo chmod +rw /etc/ceph
sudo chmod +rw /etc/ceph/*
ceph-deploy admin $HOSTNAME
sudo chmod +rw /etc/ceph
sudo chmod +rw /etc/ceph/*
ceph-deploy mon create-initial
sudo chmod +rw /etc/ceph
sudo chmod +rw /etc/ceph/*

cd $rtb
