#!/bin/bash
ceph-deploy purge $HOSTNAME
ceph-deploy purgedata $HOSTNAME
ceph-deploy forgetkeys
rm -r ~/ceph
