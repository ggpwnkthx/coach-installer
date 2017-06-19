#!/bin/bash
services=(provisioner_lamp)
for s in ${services[@]}
do
  if [ ! -z "$(sudo docker ps -a | grep $s)" ]
  then
    sudo docker rm -f $s
  fi
done
if [ -d /mnt/ceph/fs/containers/provisioner/www ]
then
  sudo rm -r /mnt/ceph/fs/containers/provisioner/www
fi
sudo mkdir /mnt/ceph/fs/containers/provisioner/www
if [ ! -d /mnt/ceph/fs/containers/provisioner/database ]
then
  sudo mkdir /mnt/ceph/fs/containers/provisioner/database
  echo "default-character-set=utf8" | sudo tee /mnt/ceph/fs/containers/provisioner/database/db.obt
  echo "default-collation=utf8_general_ci" | sudo tee --append /mnt/ceph/fs/containers/provisioner/database/db.obt
  sudo chmod +r /mnt/ceph/fs/containers/provisioner/database/db.obt
  sudo chmod 777 /mnt/ceph/fs/containers/provisioner/database
fi

./download_and_run docker/provisioner/lamp/gui.sh

sudo wget https://raw.githubusercontent.com/ggpwnkthx/coach/master/docker/provisioner/lamp/provisioner-lamp.sh -O /etc/ceph/provisioner-lamp.sh
sudo chmod +x /etc/ceph/provisioner-lamp.sh
sudo wget https://raw.githubusercontent.com/ggpwnkthx/coach/master/docker/provisioner/lamp/provisioner-lamp.service -O /etc/systemd/system/provisioner-lamp.service
sudo systemctl daemon-reload
sudo systemctl enable provisioner-lamp.service
sudo systemctl restart provisioner-lamp.service
