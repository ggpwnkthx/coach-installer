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
if [ ! -f /etc/systemd/system/rbdmap.service ]
then
  sudo wget https://raw.githubusercontent.com/ggpwnkthx/coach/master/ceph/rbdmap.init -O /etc/init.d/rbdmap
  sudo wget https://raw.githubusercontent.com/ggpwnkthx/coach/master/ceph/rbdmap.service - O /etc/systemd/system/rbdmap.service
  sudo systemctl enable rbdmap.service
fi
systemctl restart rbdmap.service
sudo apt-get -y install dnsmasq
if [ ! -d /mnt/ceph/rbd/rbd/dhcp/dnsmasq.d ]
then
  sudo cp -r /etc/dnsmasq.d /mnt/ceph/rbd/rbd/dhcp/dnsmasq.d
  echo "dhcp-range=192.168.0.50,192.168.0.150,255.255.255.0,12h" | sudo tee /mnt/ceph/rbd/rbd/dhcp/dnsmasq.d/range.conf
  echo "dhcp-leasefile=/mnt/ceph/rbd/rbd/dhcp/dnsmasq.leases" | sudo tee /mnt/ceph/rbd/rbd/dhcp/dnsmasq.d/leases.conf
fi
if [ ! -z /mnt/ceph/rbd/rbd/dhcp/dnsmasq.leases ]
then
  sudo touch /mnt/ceph/rbd/rbd/dhcp/dnsmasq.leases
fi
sudo rm -r /etc/dnsmasq.d
sudo ln -s /mnt/ceph/rbd/rbd/dhcp/dnsmasq.d /etc
if [ ! -f /etc/systemd/system/dnsmasq.service ]
then
  echo "interface=ib0" | sudo tee --append /etc/dnsmasq.conf
  echo "conf-dir=/etc/dnsmasq.d" | sudo tee --append /etc/dnsmasq.conf
  sudo wget https://raw.githubusercontent.com/ggpwnkthx/coach/master/ceph/dnsmasq.service -O /etc/systemd/system/dnsmasq.service
  sudo systemctl enable dnsmasq.service
fi
sudo systemctl restart dnsmasq.service
