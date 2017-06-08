#!/bin/bash

if [ -z "$(command -v docker)" ]
then
  ./download_and_run "docker/deploy.sh"
  sudo sed -i '/^after:/ s/$/ mnt-ceph-fs.mount/' /etc/systemd/system/multi-user.target.wants/docker.service
  sudo systemctl reenable docker.service
fi

./download_and_run "docker/provisioner/deploy.sh"
