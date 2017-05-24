#/bin/bash
# Install Docker
sudo apt-get -y install docker.io
# Add the CephFS mount as a dependancy to the docker.service
if [ -z "$(cat /etc/systemd/system/multi-user.target.wants/docker.service | grep mnt-ceph-fs.mount)" ]
then
  sudo sed '/^After=/ s/$/ mnt-ceph-fs.mount/' /etc/systemd/system/multi-user.target.wants/docker.service
fi
# Deploy the Rancher Server container
sudo docker run -d --restart=always -p 8080:8080 rancher/server
