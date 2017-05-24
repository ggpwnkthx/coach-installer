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

wget https://github.com/boot2docker/boot2docker/archive/master.zip
sudo apt-get -y install unzip
unzip master.zip
sed -i '/infiniband/d' boot2docker-master/Dockerfile
cd boot2docker-master
sudo docker build -t boot2docker .
sudo docker run --rm boot2docker > boot2docker.iso
sudo mkdir -p /mnt/boot2docker
sudo mount -o loop $(sudo find / -name boot2docker.iso -printf "%T+\t%p\n" | sort -r | head -1 | awk '{print $2}') /mnt/boot2docker
sudo cp /mnt/boot2docker/boot/initrd.img /mnt/ceph/fs/containers/provisioner/www/boot/boot2docker/initrd.img
sudo cp /mnt/boot2docker/boot/vmlinuz64 /mnt/ceph/fs/containers/provisioner/www/boot/boot2docker/vmlinuz64

sudo chmod -R +rw /mnt/ceph/fs/containers/provisioner
sudo docker run -d \
  --name provisioner_lamp --restart=always --net=host \
  -v /mnt/ceph/fs/containers/provisioner/www:/www \
  janes/alpine-lamp
