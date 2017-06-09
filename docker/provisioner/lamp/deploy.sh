#!/bin/bash
services=(provisioner_lamp)
for s in ${services[@]}
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
sudo docker run -d \
  --name provisioner_lamp --net=host \
  -v /mnt/ceph/fs/containers/provisioner/www:/www \
  janes/alpine-lamp
