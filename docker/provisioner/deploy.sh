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

#sudo apt-get -y install build-essentials git curl
#git clone https://github.com/rancher/os.git
#cd os-kernel
#sudo make
#cd ..

sudo rm /mnt/ceph/fs/containers/provisioner/www/boot/rancher
sudo mkdir -p /mnt/ceph/fs/containers/provisioner/www/boot/rancher
sudo wget https://raw.githubusercontent.com/ggpwnkthx/coach/master/docker/provisioner/ipxe.php -O /mnt/ceph/fs/containers/provisioner/www/index.php
sudo wget https://raw.githubusercontent.com/ggpwnkthx/coach/master/docker/provisioner/cloud-init -O /mnt/ceph/fs/containers/provisioner/www/boot/rancher/cloud-init
sudo wget https://releases.rancher.com/os/latest/vmlinuz -O /mnt/ceph/fs/containers/provisioner/www/boot/rancher/vmlinuz
wget https://releases.rancher.com/os/latest/initrd -O initrd.lzma
sudo apt-get -y install lzma
unlzma initrd.lzma
mkdir rancheros_initrd
cd rancheros_initrd
cpio -id < ../initrd


sudo chmod -R +r /mnt/ceph/fs/containers/provisioner
sudo docker run -d \
  --name provisioner_lamp --restart=always --net=host \
  -v /mnt/ceph/fs/containers/provisioner/www:/www \
  janes/alpine-lamp
