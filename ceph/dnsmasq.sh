if [ -z $(sudo ceph osd pool ls | rbd) ]
then
  sudo ceph osd pool create rbd 256
fi
if [ -z $(sudo rbd ls | grep dhcp) ]
then
  sudo bd create rbd/dhcp --size 1024
fi
if [ -f /etc/ceph/rbdmap ]
then
  echo "rbd/dhcp id=admin,keyring=/etc/ceph/ceph.client.admin.keyring" | sudo tee --append /etc/ceph/rbdmap
else
  echo "rbd/dhcp id=admin,keyring=/etc/ceph/ceph.client.admin.keyring" | sudo tee /etc/ceph/rbdmap
fi
