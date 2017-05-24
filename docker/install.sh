#!/bin/bash
sudo apt-get -y install docker.io
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
    advertize=$addr
  fi
done
sudo docker swarm ini --advertize-addr $advertize
