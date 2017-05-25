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

sudo rm /mnt/ceph/fs/containers/provisioner/www/boot/rancher
sudo mkdir -p /mnt/ceph/fs/containers/provisioner/www/boot/rancher
sudo wget https://releases.rancher.com/os/latest/vmlinuz -O /mnt/ceph/fs/containers/provisioner/www/boot/rancher/vmlinuz
sudo wget https://releases.rancher.com/os/latest/initrd -O /mnt/ceph/fs/containers/provisioner/www/boot/rancher/initrd

sudo chmod -R +rw /mnt/ceph/fs/containers/provisioner
sudo docker run -d \
  --name provisioner_lamp --restart=always --net=host \
  -v /mnt/ceph/fs/containers/provisioner/www:/www \
  janes/alpine-lamp
