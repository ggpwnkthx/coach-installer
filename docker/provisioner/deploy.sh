#!/bin/bash
./download_and_run "docker/provisioner/dnsmasq/deploy.sh" $@

services=(provisioner_lamp provisioner_tftp)
for s in $services
do
  if [ ! -z "$(sudo docker ps -a | grep $s)" ]
  then
    sudo docker rm -f $s
  fi
done

if [ ! -d /mnt/ceph/fs/containers/provisioner/www ]
then
  sudo mkdir /mnt/ceph/fs/containers/provisioner/www
fi
if [ ! -d /mnt/ceph/fs/containers/provisioner/tftp ]
then
  sudo mkdir /mnt/ceph/fs/containers/provisioner/tftp
fi
wget https://raw.githubusercontent.com/ggpwnkthx/coach/master/docker/provisioner/ipxe.php -O /mnt/ceph/fs/containers/provisioner/www/index.php
sudo chmod -R +r /mnt/ceph/fs/containers/provisioner

sudo docker run -d \
  --name provisioner_lamp --restart=always --net=host \
  -v /mnt/ceph/fs/containers/provisioner/www:/www \
  janes/alpine-lamp
  
sudo docker run -d \
  --name provisioner_tftp --restart=always --net=host \ 
  -v /mnt/ceph/fs/containers/provisioner/tftp: \
  pghalliday/tftp
