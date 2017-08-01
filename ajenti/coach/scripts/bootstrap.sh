#!/bin/bash
CONFIG_PATH="/etc/ceph/"
CLUSTER="admin"
IP="172.16.2.108"
NETWORK="172.16.0.0/16"

if [ -z "$(command -v ceph-deploy)" ]
then
  apt-get -y install ceph-deploy
  echo "Session needs to be refreshed. Please rerun."
  exit
fi

if [ -z "$(command -v ceph)" ]
then
  env DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical apt-get --assume-yes -q --no-install-recommends install ca-certificates apt-transport-https
  apt-get update
  env DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical apt-get --assume-yes -q --no-install-recommends install ceph
fi
if [ -z "$(command -v ceph-mds)" ]
then
  env DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical apt-get --assume-yes -q --no-install-recommends install ceph-mds
fi
if [ -z "$(command -v radosgw)" ]
then
  env DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical apt-get --assume-yes -q --no-install-recommends install radosgw
fi

if [ ! -f $CLUSTER.conf ]
then
  echo "[global]" >> $CLUSTER.conf
  echo "fsid = $(uuidgen)" >> $CLUSTER.conf
  echo "mon initial members = $(hostname -s)" >> $CLUSTER.conf
  echo "mon host = $IP" >> $CLUSTER.conf
  echo "auth cluster required = cephx" >> $CLUSTER.conf
  echo "auth service required = cephx" >> $CLUSTER.conf
  echo "auth client required = cephx" >> $CLUSTER.conf
  echo "osd pool default size = 2" >> $CLUSTER.conf
  echo "public network = $NETWORK" >> $CLUSTER.conf
  echo "" >> $CLUSTER.conf
  echo "[mon.$(hostname -s)]" >> $CLUSTER.conf
  echo "host = $(hostname -s)" >> $CLUSTER.conf
  echo "mon addr = $IP" >> $CLUSTER.conf
fi

FSID=$(cat $CLUSTER.conf | grep fsid | awk '{print $3}')

if [ ! -f $CLUSTER.mon.keyring ]
then
  ceph-authtool --create-keyring $CLUSTER.mon.keyring --gen-key -n mon. --cap mon 'allow *'
  ceph-authtool --create-keyring $CLUSTER.client.admin.keyring --gen-key -n client.admin --set-uid=0 --cap mon 'allow *' --cap osd 'allow *' --cap mds 'allow'
  ceph-authtool $CLUSTER.mon.keyring --import-keyring $CLUSTER.client.admin.keyring
fi

if [ ! -f $CLUSTER.monmap ]
then
  monmaptool --create --add $(hostname -s) $IP --fsid $FSID $CLUSTER.monmap
fi

if [ ! -f /var/lib/ceph/mon/$CLUSTER-$(hostname -s)/done ]
then
  mkdir /var/lib/ceph/mon/$CLUSTER-$(hostname -s)
  ceph-mon --cluster $CLUSTER --mkfs -i $(hostname -s) --monmap $CLUSTER.monmap --keyring $CLUSTER.mon.keyring
  touch /var/lib/ceph/mon/$CLUSTER-$(hostname -s)/done
fi

if [ ! -d $CONFIG_PATH ]
then
  mkdir $CONFIG_PATH ]
fi

if [ ! -f $CONFIG_PATH/$CLUSTER.conf ]
then
  cp $CLUSTER.conf $CONFIG_PATH/$CLUSTER.conf
fi

if [ ! -f $CONFIG_PATH/$CLUSTER.client.admin.keyring ]
then
  cp $CLUSTER.client.admin.keyring $CONFIG_PATH/$CLUSTER.client.admin.keyring
fi

if [ ! -d /usr/lib/systemd/system ]
then
  mkdir /usr/lib/systemd/system
fi

systemctl stop ceph.target

chmod +x ceph-systemd-service-generator.sh
./ceph-systemd-service-generator.sh

systemctl enable $CLUSTER.target
systemctl enable $CLUSTER-mon.target
systemctl enable $CLUSTER-osd.target
systemctl start $CLUSTER.target
systemctl start $CLUSTER-mon.target
systemctl start $CLUSTER-osd.target

ceph --cluster $CLUSTER --admin-daemon /var/run/ceph/$CLUSTER-mon.$(hostname -s).asok mon_status

ceph --cluster $CLUSTER --conf /etc/ceph/$CLUSTER.conf -s