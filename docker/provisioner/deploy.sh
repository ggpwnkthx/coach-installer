#!/bin/bash
wget https://raw.githubusercontent.com/ggpwnkthx/coach/master/docker/dnsmasq/deploy.sh -O docker_dnsmasq_deploy.sh
chmod +x docker_dnsmasq_deploy.sh
./docker_dnsmasq_deploy.sh $@

sudo docker run -d \
  --name provisioner_lamp --restart=always --net=host \
  -v /mnt/ceph/fs/containers/provisioner/www:/var/www/html \
  janes/alpine-lamp
