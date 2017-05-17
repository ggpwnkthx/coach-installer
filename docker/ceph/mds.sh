#!/bin/bash
if [ ! -f ceph_preflight.sh ]
then
  wget https://raw.githubusercontent.com/ggpwnkthx/coach/master/docker/ceph/preflight.sh -O ceph_preflight.sh
fi
chmod +x ceph_preflight.sh
./ceph_preflight.sh
sudo docker run -d --name ceph_mds --net=host -v /var/lib/ceph/:/var/lib/ceph/ -v /etc/ceph:/etc/ceph -e CEPHFS_CREATE=1 -e CEPHFS_DATA_POOL_PG=64 -e CEPHFS_METADATA_POOL_PG=64 ceph/daemon mds
#!/bin/bash
if [ ! -f ceph_fs.sh ]
then
  wget https://raw.githubusercontent.com/ggpwnkthx/coach/master/docker/ceph/fs.sh -O ceph_fs.sh
fi
chmod +x ceph_fs.sh
