#!/bin/bash
wget https://raw.githubusercontent.com/ggpwnkthx/coach/master/docker/dnsmasq/Dockerfile -O Dockerfile
sudo docker build -t "coach/dnsmasq" .
if [ ! -z "$(sudo docker ps | grep dnsmasq)" ]
then
  sudo docker kill dnsmasq
fi
if [ ! -z "$(sudo docker ps -a | grep dnsmasq)" ]
then
  sudo docker rm dnsmasq
fi

if [ ! -d /mnt/ceph/fs/containers/dnsmasq ]
then
  sudo mkdir -p /mnt/ceph/fs/containers/dnsmasq
fi
sudo chmod +rw /mnt/ceph/fs/containers/dnsmasq

if [ ! -f /mnt/ceph/fs/containers/dnsmasq/leases ]
then
  sudo touch /mnt/ceph/fs/containers/dnsmasq/leases
fi
sudo chmod +rw /mnt/ceph/fs/containers/dnsmasq/leases

if [ ! -f /mnt/ceph/fs/containers/dnsmasq/conf ]
then
  echo "domain-needed" | sudo tee /mnt/ceph/fs/containers/dnsmasq/conf
  echo "bogus-priv" | sudo tee --append /mnt/ceph/fs/containers/dnsmasq/conf
  echo "no-resolv" | sudo tee --append /mnt/ceph/fs/containers/dnsmasq/conf
  echo "no-poll" | sudo tee --append /mnt/ceph/fs/containers/dnsmasq/conf
  echo "no-hosts" | sudo tee --append /mnt/ceph/fs/containers/dnsmasq/conf
  echo "expand-hosts" | sudo tee --append /mnt/ceph/fs/containers/dnsmasq/conf
fi
sudo chmod +r /mnt/ceph/fs/containers/dnsmasq/conf

use_iface=""

ceph_net=$(cat /etc/ceph/ceph.conf | grep "public_network" | awk '{print $3}')
if [ -z "$ceph_net" ]
then
  ceph_net=$(cat /etc/ceph/ceph.conf | grep "public network" | awk '{print $4}')
fi
ifaces=($(ifconfig | awk -v RS="\n\n" '{ for (i=1; i<=NF; i++) if ($i == "inet" && $(i+1) ~ /^addr:/) address = substr($(i+1), 6); if (address != "127.0.0.1") printf "%s\n", $1 }'))
for i in ${ifaces[@]}
do
  addr=$(ifconfig $i | grep Mask | awk '{print $2}' | awk '{split($0,a,":"); print a[2]}')
  mask=$(ifconfig $i | grep Mask | awk '{print $4}' | awk '{split($0,a,":"); print a[2]}')
  net=$(ipcalc -n $addr $mask | grep Network | awk '{print $2}')
  if [ "$ceph_net" == "$net" ]
  then
    use_iface="$use_iface --interface=$i"
    min=$(ipcalc -n $addr $mask | grep HostMin | awk '{print $2}')
    max=$(ipcalc -n $addr $mask | grep HostMax | awk '{print $2}')
    use_range="$use_range --dhcp-range=$min,$max,infinite"
    advertize=$addr
  fi
  addr=""
  mask=""
  net=""
done

ceph_mon_ls=($(sudo ceph mon dump | grep mon | awk '{print $2}' | awk '{split($0,a,"/"); print a[1]}'))
ceph_mons="--dhcp-option=242"
for i in ${ceph_mon_ls[@]}
do
  ceph_mons="$ceph_mons,$i"
done

domain_name=$(domainname)
if [ "$domain_name" == "(none)" ]
then
  read -p "Domain Name: " domain_name
fi

sudo docker service \
  --name dnsmasq --restart=always --net=host \
  -v /mnt/ceph/fs/containers/dnsmasq/leases:/var/lib/misc/dnsmasq.leases \
  -v /mnt/ceph/fs/containers/dnsmasq/conf:/etc/dnsmasq.conf \
  coach/dnsmasq --dhcp-leasefile=/var/lib/misc/dnsmasq.leases \
  --host-record=$HOSTNAME,$advertize
  --domain=$domain_name \
  --local=/$domain_name/ \
  $use_iface \
  $use_range \
  $ceph_mons \
  $@
