#!/bin/bash
cd ~/ceph
ceph-deploy install $HOSTNAME
ceph-deploy admin $HOSTNAME
sudo chmod +r /etc/ceph
sudo chmod +r /etc/ceph/*
sudo chmod +r /var/lib/ceph
sudo chmod +r /var/lib/ceph/*
