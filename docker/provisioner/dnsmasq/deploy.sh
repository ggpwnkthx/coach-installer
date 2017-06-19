#!/bin/bash
wget https://raw.githubusercontent.com/ggpwnkthx/coach/master/docker/provisioner/dnsmasq/Dockerfile -O Dockerfile
sudo docker build -t "coach/dnsmasq" .
if [ ! -z "$(sudo docker ps | grep provisioner_dnsmasq)" ]
then
  sudo docker kill provisioner_dnsmasq
fi
if [ ! -z "$(sudo docker ps -a | grep provisioner_dnsmasq)" ]
then
  sudo docker rm provisioner_dnsmasq
fi

if [ ! -d /mnt/ceph/fs/containers/provisioner ]
then
  sudo mkdir -p /mnt/ceph/fs/containers/provisioner
fi
sudo chmod +rw /mnt/ceph/fs/containers/provisioner

if [ ! -f /mnt/ceph/fs/containers/provisioner/leases ]
then
  sudo touch /mnt/ceph/fs/containers/provisioner/leases
fi
sudo chmod +rw /mnt/ceph/fs/containers/provisioner/leases

if [ ! -f /mnt/ceph/fs/containers/provisioner/conf ]
then
#  echo "domain-needed" | sudo tee /mnt/ceph/fs/containers/provisioner/conf
  echo "bogus-priv" | sudo tee --append /mnt/ceph/fs/containers/provisioner/conf
  echo "no-resolv" | sudo tee --append /mnt/ceph/fs/containers/provisioner/conf
  echo "no-poll" | sudo tee --append /mnt/ceph/fs/containers/provisioner/conf
  echo "no-hosts" | sudo tee --append /mnt/ceph/fs/containers/provisioner/conf
  echo "expand-hosts" | sudo tee --append /mnt/ceph/fs/containers/provisioner/conf
fi
sudo chmod +r /mnt/ceph/fs/containers/provisioner/conf

use_iface=""

ceph_net=$(cat /etc/ceph/ceph.conf | grep "public_network" | awk '{print $3}')
if [ -z "$ceph_net" ]
then
  ceph_net=$(cat /etc/ceph/ceph.conf | grep "public network" | awk '{print $4}')
fi
ifaces=($(ifconfig | awk -v RS="\n\n" '{ for (i=1; i<=NF; i++) if ($i == "inet" && $(i+1) ~ /^addr:/) address = substr($(i+1), 6); if (address != "127.0.0.1") printf "%s\n", $1 }'))
for i in ${ifaces[@]}
do
  addr=$(ifconfig $i | grep Mask | awk '{print $2}' | awk '{split($0,a,":"); print a[2]}')
  mask=$(ifconfig $i | grep Mask | awk '{print $4}' | awk '{split($0,a,":"); print a[2]}')
  net=$(ipcalc -n $addr $mask | grep Network | awk '{print $2}')
  if [ "$ceph_net" == "$net" ]
  then
    use_iface="$use_iface --interface=$i"
    min=$(ipcalc -n $addr $mask | grep HostMin | awk '{print $2}')
    max=$(ipcalc -n $addr $mask | grep HostMax | awk '{print $2}')
    use_range="$use_range --dhcp-range=$min,$max,infinite"
    advertize=$addr
  fi
  addr=""
  mask=""
  net=""
done

ceph_mon_ls=($(sudo ceph mon dump | grep mon | awk '{print $2}' | awk '{split($0,a,"/"); print a[1]}'))
ceph_mons="--dhcp-option=242"
for i in ${ceph_mon_ls[@]}
do
  ceph_mons="$ceph_mons,$i"
done

if [ -z "$1" ]
then
  domain_name=$(domainname)
  if [ "$domain_name" == "(none)" ]
  then
    if [ -z "$(hostname -d)" ]
    then
      read -p "Domain Name: " domain_name
    else
      domain_name=$(hostname -d)
    fi
  fi
else
  domain_name=$1
fi

echo "#!/bin/bash" | sudo tee /etc/ceph/provisioner-dnsmasq.sh
echo "case \$1 in" | sudo tee --append /etc/ceph/provisioner-dnsmasq.sh
echo "  start)" | sudo tee --append /etc/ceph/provisioner-dnsmasq.sh
echo "    if [ ! -z \"\$(docker ps -a | grep provisioner_dnsmasq)\" ]" | sudo tee --append /etc/ceph/provisioner-dnsmasq.sh
echo "    then" | sudo tee --append /etc/ceph/provisioner-dnsmasq.sh
echo "      docker rm -f provisioner_dnsmasq" | sudo tee --append /etc/ceph/provisioner-dnsmasq.sh
echo "    fi" | sudo tee --append /etc/ceph/provisioner-dnsmasq.sh
echo "    docker run -d \\" | sudo tee --append /etc/ceph/provisioner-dnsmasq.sh
echo "      --name provisioner_dnsmasq --net=host \\" | sudo tee --append /etc/ceph/provisioner-dnsmasq.sh
echo "      -v /mnt/ceph/fs/containers/provisioner/leases:/var/lib/misc/dnsmasq.leases \\" | sudo tee --append /etc/ceph/provisioner-dnsmasq.sh
echo "      -v /mnt/ceph/fs/containers/provisioner/conf:/etc/dnsmasq.conf \\" | sudo tee --append /etc/ceph/provisioner-dnsmasq.sh
echo "      coach/dnsmasq --dhcp-leasefile=/var/lib/misc/dnsmasq.leases \\" | sudo tee --append /etc/ceph/provisioner-dnsmasq.sh
echo "      --host-record=$(hostname -f),$advertize \\" | sudo tee --append /etc/ceph/provisioner-dnsmasq.sh
echo "      --dhcp-option=67,http://$(hostname -f)/ipxe.php \\" | sudo tee --append /etc/ceph/provisioner-dnsmasq.sh
echo "      --domain=$domain_name \\" | sudo tee --append /etc/ceph/provisioner-dnsmasq.sh
echo "      --local=/$domain_name/ \\" | sudo tee --append /etc/ceph/provisioner-dnsmasq.sh
echo "      $use_iface \\" | sudo tee --append /etc/ceph/provisioner-dnsmasq.sh
echo "      $use_range \\" | sudo tee --append /etc/ceph/provisioner-dnsmasq.sh
echo "      $ceph_mons" | sudo tee --append /etc/ceph/provisioner-dnsmasq.sh
echo "    ;;" | sudo tee --append /etc/ceph/provisioner-dnsmasq.sh
echo "  stop)" | sudo tee --append /etc/ceph/provisioner-dnsmasq.sh
echo "    docker stop provisioner_dnsmasq" | sudo tee --append /etc/ceph/provisioner-dnsmasq.sh
echo "    docker rm -f provisioner_dnsmasq" | sudo tee --append /etc/ceph/provisioner-dnsmasq.sh
echo "    ;;" | sudo tee --append /etc/ceph/provisioner-dnsmasq.sh
echo "  status)" | sudo tee --append /etc/ceph/provisioner-dnsmasq.sh
echo "    docker ps -a | grep provisioner_dnsmasq" | sudo tee --append /etc/ceph/provisioner-dnsmasq.sh
echo "    ;;" | sudo tee --append /etc/ceph/provisioner-dnsmasq.sh
echo "esac" | sudo tee --append /etc/ceph/provisioner-dnsmasq.sh

sudo chmod +x /etc/ceph/provisioner-dnsmasq.sh

sudo wget https://raw.githubusercontent.com/ggpwnkthx/coach/master/docker/provisioner/dnsmasq/provisioner-dnsmasq.service -O /etc/systemd/system/provisioner-dnsmasq.service
sudo systemctl daemon-reload
sudo systemctl enable provisioner-dnsmasq.service
sudo systemctl restart provisioner-dnsmasq.service
