#!/bin/bash
sudo docker ps -a | grep ceph | awk '{print $1}' | xargs sudo docker kill
sudo docker ps -a | grep ceph | awk '{print $1}' | xargs sudo docker rm
sudo rm -r /etc/ceph
sudo rm -r /var/lib/ceph
