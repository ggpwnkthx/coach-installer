#!/bin/bash
wget https://raw.githubusercontent.com/ggpwnkthx/coach/master/docker/provisioner/dnsmasq/deploy.sh -O docker_dnsmasq_deploy.sh
chmod +x docker_dnsmasq_deploy.sh
./docker_dnsmasq_deploy.sh $@

if [ ! -z "$(sudo docker ps | grep provisioner_lamp)" ]
then
  sudo docker kill provisioner_lamp
fi
if [ ! -z "$(sudo docker ps -a | grep provisioner_lamp)" ]
then
  sudo docker rm provisioner_lamp
fi

if [ ! -d /mnt/ceph/fs/containers/provisioner/www ]
then
  sudo mkdir /mnt/ceph/fs/containers/provisioner/www
fi

sudo rm /mnt/ceph/fs/containers/provisioner/www/boot/coreos
sudo mkdir -p /mnt/ceph/fs/containers/provisioner/www/boot/coreos
sudo wget https://raw.githubusercontent.com/ggpwnkthx/coach/master/docker/provisioner/ipxe.php -O /mnt/ceph/fs/containers/provisioner/www/index.php
sudo wget http://stable.release.core-os.net/amd64-usr/current/coreos_production_pxe.vmlinuz -O /mnt/ceph/fs/containers/provisioner/www/boot/coreos/vmlinuz
sudo wget http://stable.release.core-os.net/amd64-usr/current/coreos_production_pxe_image.cpio.gz -O /mnt/ceph/fs/containers/provisioner/www/boot/coreos/image.cpio.gz

sudo chmod -R +r /mnt/ceph/fs/containers/provisioner
sudo docker run -d \
  --name provisioner_lamp --restart=always --net=host \
  -v /mnt/ceph/fs/containers/provisioner/www:/www \
  janes/alpine-lamp
