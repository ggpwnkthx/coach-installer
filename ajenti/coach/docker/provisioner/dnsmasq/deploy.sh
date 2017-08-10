#!/bin/bash
DIR=$(pwd)
cd $( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

docker build -t "coach/dnsmasq" .
if [ ! -z "$(docker ps | grep provisioner_dnsmasq)" ]
then
  docker kill provisioner_dnsmasq
fi
if [ ! -z "$(docker ps -a | grep provisioner_dnsmasq)" ]
then
  docker rm provisioner_dnsmasq
fi

if [ ! -d /mnt/ceph/fs/containers/provisioner ]
then
  mkdir -p /mnt/ceph/fs/containers/provisioner
fi
chmod +rw /mnt/ceph/fs/containers/provisioner

if [ ! -f /mnt/ceph/fs/containers/provisioner/leases ]
then
  touch /mnt/ceph/fs/containers/provisioner/leases
fi
chmod +rw /mnt/ceph/fs/containers/provisioner/leases

if [ ! -f /mnt/ceph/fs/containers/provisioner/conf ]
then
#  echo "domain-needed" | tee /mnt/ceph/fs/containers/provisioner/conf
  echo "bogus-priv" | tee --append /mnt/ceph/fs/containers/provisioner/conf
  echo "no-resolv" | tee --append /mnt/ceph/fs/containers/provisioner/conf
  echo "no-poll" | tee --append /mnt/ceph/fs/containers/provisioner/conf
  echo "no-hosts" | tee --append /mnt/ceph/fs/containers/provisioner/conf
  echo "expand-hosts" | tee --append /mnt/ceph/fs/containers/provisioner/conf
  echo "option coach-data code 242 = ready;" | tee --append /mnt/ceph/fs/containers/provisioner/conf
fi
chmod +r /mnt/ceph/fs/containers/provisioner/conf

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

ceph_mon_ls=($(ceph mon dump | grep mon | awk '{print $2}' | awk '{split($0,a,"/"); print a[1]}'))
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

echo "#!/bin/bash" | tee /etc/ceph/provisioner-dnsmasq.sh
echo "case \$1 in" | tee --append /etc/ceph/provisioner-dnsmasq.sh
echo "  start)" | tee --append /etc/ceph/provisioner-dnsmasq.sh
echo "    if [ ! -z \"\$(docker ps -a | grep provisioner_dnsmasq)\" ]" | tee --append /etc/ceph/provisioner-dnsmasq.sh
echo "    then" | tee --append /etc/ceph/provisioner-dnsmasq.sh
echo "      docker rm -f provisioner_dnsmasq" | tee --append /etc/ceph/provisioner-dnsmasq.sh
echo "    fi" | tee --append /etc/ceph/provisioner-dnsmasq.sh
echo "    docker run -d \\" | tee --append /etc/ceph/provisioner-dnsmasq.sh
echo "      --name provisioner_dnsmasq --net=host \\" | tee --append /etc/ceph/provisioner-dnsmasq.sh
echo "      -v /mnt/ceph/fs/containers/provisioner/leases:/var/lib/misc/dnsmasq.leases \\" | tee --append /etc/ceph/provisioner-dnsmasq.sh
echo "      -v /mnt/ceph/fs/containers/provisioner/conf:/etc/dnsmasq.conf \\" | tee --append /etc/ceph/provisioner-dnsmasq.sh
echo "      coach/dnsmasq --dhcp-leasefile=/var/lib/misc/dnsmasq.leases \\" | tee --append /etc/ceph/provisioner-dnsmasq.sh
echo "      --host-record=$(hostname -f),$advertize \\" | tee --append /etc/ceph/provisioner-dnsmasq.sh
echo "      --dhcp-option=67,http://$(hostname -f)/ipxe.php \\" | tee --append /etc/ceph/provisioner-dnsmasq.sh
echo "      --domain=$domain_name \\" | tee --append /etc/ceph/provisioner-dnsmasq.sh
echo "      --local=/$domain_name/ \\" | tee --append /etc/ceph/provisioner-dnsmasq.sh
echo "      $use_iface \\" | tee --append /etc/ceph/provisioner-dnsmasq.sh
echo "      $use_range \\" | tee --append /etc/ceph/provisioner-dnsmasq.sh
echo "      $ceph_mons" | tee --append /etc/ceph/provisioner-dnsmasq.sh
echo "    ;;" | tee --append /etc/ceph/provisioner-dnsmasq.sh
echo "  stop)" | tee --append /etc/ceph/provisioner-dnsmasq.sh
echo "    docker stop provisioner_dnsmasq" | tee --append /etc/ceph/provisioner-dnsmasq.sh
echo "    docker rm -f provisioner_dnsmasq" | tee --append /etc/ceph/provisioner-dnsmasq.sh
echo "    ;;" | tee --append /etc/ceph/provisioner-dnsmasq.sh
echo "  status)" | tee --append /etc/ceph/provisioner-dnsmasq.sh
echo "    docker ps -a | grep provisioner_dnsmasq" | tee --append /etc/ceph/provisioner-dnsmasq.sh
echo "    ;;" | tee --append /etc/ceph/provisioner-dnsmasq.sh
echo "esac" | tee --append /etc/ceph/provisioner-dnsmasq.sh

chmod +x /etc/ceph/provisioner-dnsmasq.sh

cp provisioner-dnsmasq.service /etc/systemd/system/provisioner-dnsmasq.service
systemctl daemon-reload
systemctl enable provisioner-dnsmasq.service
systemctl restart provisioner-dnsmasq.service

cd $DIR