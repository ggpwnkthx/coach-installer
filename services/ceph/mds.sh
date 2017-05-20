#/bin/bash
if [ -z "$(command -v ceph-deploy)" ]
then
  echo "ceph-deploy is not installed on this node"
  exit
fi

if [ -z $1 ]
then
  fs=cephfs
  data=cephfs_data
  meta=cephfs_meta
else
  fs=$1
  data=$1_data
  meta=$1_meta
fi

cd ~/ceph
ceph-deploy install $HOSTNAME
ceph-deploy admin $HOSTNAME
ceph-deploy mds create $HOSTNAME

if [ -z "$(sudo ceph fs ls | grep -w $fs)" ]
then
  ceph_pool_create $data 128
  ceph_pool_create $meta 128
  sudo ceph fs new $fs $meta $data
fi
