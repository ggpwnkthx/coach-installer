#!/bin/bash
sudo docker run -d --net=host \
-v /etc/ceph:/etc/ceph \
-v /var/lib/ceph/:/var/lib/ceph/ \
-e MON_IP=192.168.0.1 \
-e CEPH_PUBLIC_NETWORK=192.168.0.0/24 \
ceph/daemon mon
