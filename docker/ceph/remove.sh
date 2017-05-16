#!/bin/bash
sudo docker kill ceph_mon
sudo docker rm ceph_mon
sudo rm -r /etc/ceph
sudo rm -r /var/lib/ceph
