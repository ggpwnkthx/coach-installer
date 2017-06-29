#/bin/bash
rtb=$(pwd)

if [ -z "$(command -v ceph-deploy)" ]
then
  echo "ceph-deploy is not installed on this node"
  exit
fi

if [ -z $1 ]
then
  fs="cephfs"
  data="cephfs_data"
  meta="cephfs_meta"
else
  fs="$1"
  data="$1_data"
  meta="$1_meta"
fi

if [ ! -f /etc/ceph/ceph.conf ]
then
  wget https://raw.githubusercontent.com/ggpwnkthx/coach/master/services/ceph/admin.sh -O services_ceph_admin.sh
  chmod +x services_ceph_admin.sh
  ./services_ceph_admin.sh
fi

cd ~/ceph
chmod 777 /var/lib/ceph
chmod 777 /var/lib/ceph/*

ceph-deploy mds create $HOSTNAME

if [ -z "$(ceph fs ls | grep -w $fs)" ]
then
  if [ -z "$(ceph osd pool ls | grep $data)" ]
  then
    ceph osd pool create $data 128
  fi
  if [ -z "$(ceph osd pool ls | grep $meta)" ]
  then
    ceph osd pool create $meta 128
  fi
  ceph fs new $fs $meta $data
fi

cd $rtb
