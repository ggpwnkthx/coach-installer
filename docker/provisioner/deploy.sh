#!/bin/bash
./download_and_run "docker/provisioner/dnsmasq/deploy.sh" $@
./download_and_run "docker/provisioner/lamp/deploy.sh"
./download_and_run "docker/provisioner/pxe/deploy.sh"

sudo chmod -R +r /mnt/ceph/fs/containers/provisioner
