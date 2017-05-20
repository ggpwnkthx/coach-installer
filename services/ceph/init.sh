#!/bin/bash

echo "$(whoami) ALL = (root) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$(whoami)
sudo chmod 0440 /etc/sudoers.d/$(whoami)

wget https://raw.githubusercontent.com/ggpwnkthx/coach/master/services/ceph/purge.sh -O services_ceph_purge.sh
chmod +x services_ceph_purge.sh
./services_ceph_purge.sh

sudo apt-get -y install net-tools ipcalc ceph-deploy

ifconfig | awk -v RS="\n\n" '{ for (i=1; i<=NF; i++) if ($i == "inet" && $(i+1) ~ /^addr:/) address = substr($(i+1), 6); if (address != "127.0.0.1") printf "%s\t%s\n", $1, address }'
read -p "Which adapter should be used for the ceph cluster? " nic
addr=$(ifconfig $nic | grep Mask | awk '{print $2}' | awk '{split($0,a,":"); print a[2]}')
mask=$(ifconfig $nic | grep Mask | awk '{print $4}' | awk '{split($0,a,":"); print a[2]}')
net=$(ipcalc -n $addr $mask | grep Network | awk '{print $2}')

wget https://raw.githubusercontent.com/ggpwnkthx/coach/master/hardware/networking/hosts.sh -O hardware_networking_hosts.sh
chmod +x hardware_networking_hosts.sh
./hardware_networking_hosts.sh $addr $HOSTNAME

if [ ! -d ~/ceph ]
then
  mkdir ~/ceph
fi
cd ~/ceph
ceph-deploy new $HOSTNAME
echo "osd pool default size = 2" >> ceph.conf
echo "public network = $net" >> ceph.conf
ceph-deploy install $HOSTNAME
ceph-deploy mon create-initial
ceph-deploy admin $HOSTNAME
sudo chmod +r /etc/ceph
sudo chmod +r /etc/ceph/*
sudo chmod +r /var/lib/ceph
sudo chmod +r /var/lib/ceph/*
