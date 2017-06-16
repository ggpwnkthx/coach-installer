#!/bin/bash
case $1 in
  start)
    if [ ! -z "$(docker ps -a | grep provisioner_lamp)" ]
    then
      docker rm -f provisioner_lamp
    fi
    docker run -d \
      --name provisioner_lamp --net=host \
      -v /mnt/ceph/fs/containers/provisioner/www:/www \
      -v /mnt/ceph/fs/containers/provisioner/database:/var/lib/mysql \
      janes/alpine-lamp
    ;;
  stop)
    docker stop provisioner_lamp
    docker rm -f provisioner_lamp
    ;;
  status)
    docker ps -a | grep provisioner_lamp
    ;;
esac
