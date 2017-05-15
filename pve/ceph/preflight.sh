if [ ! -d /etc/ceph ]
then
  read -p "Any PVE hostname or IP: " pve
  sudo scp -r root@$pve:/etc/ceph /etc/ceph
fi
if [ ! -d /etc/pve ]
then
  sudo mkdir /etc/pve
fi
if [ ! -d /etc/pve/priv ]
then
  sudo ln -s /etc/ceph /etc/pve/priv
fi
