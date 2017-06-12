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

sudo wget https://raw.githubusercontent.com/ggpwnkthx/coach/master/docker/provisioner/lamp/provisioner-lamp.sh -O /etc/ceph/provisioner-lamp.sh
sudo chmod +x /etc/ceph/provisioner-lamp.sh
sudo wget https://raw.githubusercontent.com/ggpwnkthx/coach/master/docker/provisioner/lamp/provisioner-lamp.service -O /etc/systemd/system/provisioner-lamp.service
sudo systemctl daemon-reload
sudo systemctl enable provisioner-lamp.service
sudo systemctl start provisioner-lamp.service
