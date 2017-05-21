#!/bin/bash
wget https://raw.githubusercontent.com/ggpwnkthx/coach/master/docker/ceph/dnsmasq/Dockerfile -O Dockerfile
sudo docker build -t "coach/dnsmask" .
if [ ! -z "$(sudo docker ps | grep dnsmask)" ]
then
  sudo docker kill dnsmask
fi
if [ ! -z "$(sudo docker ps -a | grep dnsmask)" ]
then
  sudo docker rm dnsmask
fi
if [ ! -d /mnt/ceph/fs/containers/dnsmasq ]
then
  sudo mkdir -p /mnt/ceph/fs/containers/dnsmasq
fi
sudo chmod +rw /mnt/ceph/fs/containers/dnsmasq
sudo chmod +rw /mnt/ceph/fs/containers/dnsmasq/*

use_iface=""
ceph_net=$(cat /etc/ceph/ceph.conf | grep public_network | awk '{print $3}')
ifaces=($(ifconfig | awk -v RS="\n\n" '{ for (i=1; i<=NF; i++) if ($i == "inet" && $(i+1) ~ /^addr:/) address = substr($(i+1), 6); if (address != "127.0.0.1") printf "%s\t%s\n", $1, address }'))
for i in $ifaces
do
  addr=$(ifconfig $nic | grep Mask | awk '{print $2}' | awk '{split($0,a,":"); print a[2]}')
  mask=$(ifconfig $nic | grep Mask | awk '{print $4}' | awk '{split($0,a,":"); print a[2]}')
  net=$(ipcalc -n $addr $mask | grep Network | awk '{print $2}')
  if [ "$ceph_net" == "$net" ]
  then
    use_iface="$use_iface --interface=$i"
    min=$(ipcalc -n $addr $mask | grep HostMin | awk '{print $2}'
    max=$(ipcalc -n $addr $mask | grep HostMin | awk '{print $2}'
    use_range="$use_range --dhcp-range=$min,$max,infinite
  fi
done

sudo docker run -d \
  --name dhcp --restart=always --net=host coach/dhcp \
  $use_iface \
  $use_range \
  $@
