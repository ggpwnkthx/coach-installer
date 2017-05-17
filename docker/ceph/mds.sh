#!/bin/bash
sudo docker run -d --net=host -v /var/lib/ceph/:/var/lib/ceph/ -v /etc/ceph:/etc/ceph -e CEPHFS_CREATE=1 -e CEPHFS_DATA_POOL_PG=64 -e CEPHFS_METADATA_POOL_PG=64 ceph/daemon mds
