read -p "Any PVE hostname or IP: " pve
sudo scp -r root@$pve:/etc/ceph /etc
if [ ! -d /etc/pve ]
then
  sudo mkdir /etc/pve
fi
if [ ! -d /etc/pve/priv ]
then
  sudo ln -s /etc/ceph /etc/pve/priv
fi
if [ -z $(command -c ceph) ]
then
  sudo apt-get -y install ceph-common
fi
