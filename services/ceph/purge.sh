#!/bin/bash
sudo ceph-deploy purge $HOSTNAME
sudo ceph-deploy purgedata $HOSTNAME
sudo ceph-deploy forgetkeys
