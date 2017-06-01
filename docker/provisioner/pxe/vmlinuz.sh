#!/bin/bash
clear
printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
echo "COACH - Cluster Of Arbitrary, Cheap, Hardware"
printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
echo "Downloading generic vmlinux"
printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
sudo wget https://cloud-images.ubuntu.com/xenial/current/unpacked/xenial-server-cloudimg-amd64-vmlinuz-generic -O /mnt/ceph/fs/containers/provisioner/www/boot/ubuntu/vmlinuz
