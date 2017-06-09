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

echo "[Unit]" | sudo tee /etc/systemd/system/provisioner-lamp.service
echo "Description=COACH LAMP Docker Container for Provisioning Service" | sudo tee --append /etc/systemd/system/provisioner-lamp.service
echo "After=mnt-ceph-fs.service docker.service" | sudo tee --append /etc/systemd/system/provisioner-lamp.service
echo "Requires=mnt-ceph-fs.service docker.service" | sudo tee --append /etc/systemd/system/provisioner-lamp.service
echo "" | sudo tee --append /etc/systemd/system/provisioner-lamp.service
echo "[Service]" | sudo tee --append /etc/systemd/system/provisioner-lamp.service
echo "Restart=always" | sudo tee --append /etc/systemd/system/provisioner-lamp.service
echo "ExecStart=/usr/bin/docker run -rm \\" | sudo tee --append /etc/systemd/system/provisioner-lamp.service
echo "  --name provisioner_lamp --net=host \\" | sudo tee --append /etc/systemd/system/provisioner-lamp.service
echo "  -v /mnt/ceph/fs/containers/provisioner/www:/www \\" | sudo tee --append /etc/systemd/system/provisioner-lamp.service
echo "  janes/alpine-lamp" | sudo tee --append /etc/systemd/system/provisioner-lamp.service
echo "ExecStop=/usr/bin/docker rm -f provisioner_lamp" | sudo tee --append /etc/systemd/system/provisioner-lamp.service
echo "" | sudo tee --append /etc/systemd/system/provisioner-lamp.service
echo "[Install]" | sudo tee --append /etc/systemd/system/provisioner-lamp.service
echo "WantedBy=multi-user.target" | sudo tee --append /etc/systemd/system/provisioner-lamp.service

sudo systemctl daemon-reload
sudo systemctl enable provisioner-lamp.service
sudo systemctl start provisioner-lamp.service
