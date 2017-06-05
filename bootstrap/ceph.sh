#!/bin/bash

./download_and_run "services/ceph/mon.sh"
./download_and_run "services/ceph/disks.sh"
./download_and_run "services/ceph/mds.sh"
./download_and_run "services/ceph/fs.sh"
