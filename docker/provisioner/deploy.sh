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

sudo rm /mnt/ceph/fs/containers/provisioner/www/boot/boot2docker
sudo mkdir -p /mnt/ceph/fs/containers/provisioner/www/boot/boot2docker
sudo wget $(wget https://api.github.com/repos/boot2docker/boot2docker/releases -O - | grep browser_download_url | head -n 1 | awk '{print $2}' | tr -d '"' ) -O /mnt/ceph/fs/containers/provisioner/www/boot/boot2docker/boot2docker.iso
sudo mkdir -p /mnt/boot2docker
sudo mount -o loop /mnt/ceph/fs/containers/provisioner/www/boot/boot2docker/boot2docker.iso /mnt/boot2docker
sudo cp /mnt/boot2docker/boot/initrd.img /mnt/ceph/fs/containers/provisioner/www/boot/boot2docker/initrd.img
sudo cp /mnt/boot2docker/boot/vmlinuz64 /mnt/ceph/fs/containers/provisioner/www/boot/boot2docker/vmlinuz64

sudo chmod -R +rw /mnt/ceph/fs/containers/provisioner
sudo docker run -d \
  --name provisioner_lamp --restart=always --net=host \
  -v /mnt/ceph/fs/containers/provisioner/www:/www \
  janes/alpine-lamp
